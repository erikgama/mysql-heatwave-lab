#!/usr/bin/env python3
"""Extrai os blocos SQL do guia Word, preservando a ordem do laboratório."""

from pathlib import Path
from textwrap import wrap
from xml.etree import ElementTree
from zipfile import ZipFile


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs" / "Laboratorio_MySQL_HeatWave.docx"
TARGET = ROOT / "sql" / "laboratorio.sql"
W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"


def paragraphs():
    with ZipFile(SOURCE) as archive:
        root = ElementTree.fromstring(archive.read("word/document.xml"))
    for paragraph in root.iter(W + "p"):
        style_element = paragraph.find(W + "pPr/" + W + "pStyle")
        style = style_element.get(W + "val") if style_element is not None else "Normal"
        pieces = []
        for element in paragraph.iter():
            if element.tag == W + "t":
                pieces.append(element.text or "")
            elif element.tag == W + "br":
                pieces.append("\n")
            elif element.tag == W + "tab":
                pieces.append("\t")
        value = "".join(pieces).strip()
        if value:
            yield style, value


def short_explanation(value):
    value = " ".join(value.removeprefix("O que faz:").split())
    first = value.split(". ", 1)[0].rstrip(".")
    return first + "." if first else ""


def main():
    entries = list(paragraphs())
    lines = [
        "-- LABORATÓRIO MYSQL HEATWAVE | roteiro extraído do guia Word",
        "-- Execute os blocos na ordem, aguardando o término das cargas e do treino.",
        "-- Os comandos OCI CLI e os arquivos do Object Storage estão no README.",
        "-- Mantenha a mesma conexão para variáveis @ e relatórios da sessão.",
        "",
    ]
    section = ""
    for index, (style, value) in enumerate(entries):
        if style in {"Heading1", "Heading2"}:
            section = value
        if style != "LabCaption":
            continue
        code = []
        explanation = ""
        for next_style, next_value in entries[index + 1 :]:
            if next_style in {"LabCaption", "Heading1", "Heading2"}:
                break
            if next_style == "SQLCode" and set(next_value) != {"-"}:
                code.append(next_value)
            elif next_style == "LabGuide" and next_value.startswith("O que faz:"):
                explanation = short_explanation(next_value)
        if not code or value.lower().startswith("terminal"):
            continue
        if code[0].startswith(("oci ", "cd ")):
            continue
        if section:
            lines.extend(["-- " + "=" * 72, "-- " + section, "-- " + "=" * 72, ""])
            section = ""
        lines.append("-- " + value)
        if explanation:
            lines.extend("-- " + part for part in wrap(explanation, 85))
        reference_only = "não execute" in value.lower() or "somente referência" in value.lower()
        previous = ""
        for paragraph in code:
            if previous:
                lines.append("") if previous.rstrip().endswith(";") else None
            lines.append("\n".join("-- " + line for line in paragraph.splitlines()) if reference_only else paragraph)
            previous = paragraph
        lines.append("")
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
    print(f"Criado {TARGET} com {len(lines)} linhas de blocos")


if __name__ == "__main__":
    main()
