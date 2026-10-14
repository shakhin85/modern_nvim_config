# /// script
# dependencies = ["openpyxl", "typer"]
# ///
"""CSV из dbee -> .xlsx: числа уходят числами, шапка жирная и закреплена.

uv run scripts/csv2xlsx.py <in.csv> <out.xlsx>
"""

import csv

import typer
from openpyxl import Workbook
from openpyxl.styles import Font


def cell(value: str):
    # Ведущий ноль (ИНН, код, артикул) — это строка, иначе Excel его съест.
    if value[:1] == "0" and value[1:2] not in ("", ".", ","):
        return value
    for kind in (int, float):
        try:
            return kind(value)
        except ValueError:
            pass
    return value


def main(src: str, dst: str) -> None:
    """Перегнать CSV src в .xlsx dst."""
    wb = Workbook()
    ws = wb.worksheets[0]
    with open(src, newline="", encoding="utf-8") as f:
        rows = csv.reader(f)
        ws.append(next(rows, []))
        for row in rows:
            ws.append([cell(v) for v in row])
    for c in ws[1]:
        c.font = Font(bold=True)
    ws.freeze_panes = "A2"
    wb.save(dst)


if __name__ == "__main__":
    typer.run(main)
