# /// script
# dependencies = ["openpyxl", "typer"]
# ///
"""CSV из dbee -> .xlsx: числа и даты уходят своими типами, шапка жирная и закреплена.

uv run scripts/csv2xlsx.py <in.csv> <out.xlsx>
"""

import csv
import re
from datetime import datetime, time

import typer
from openpyxl import Workbook
from openpyxl.styles import Font

# dbee (Go) пишет время как "2026-10-31 11:32:17 +0000 +0000", MSSQL — без зоны.
# Зону отбрасываем: у даты в Excel её нет, остаётся время, которое вернула БД.
DATETIME = re.compile(
    r"(\d{4}-\d{2}-\d{2})(?:[ T](\d{2}:\d{2}:\d{2})(\.\d+)?)?(?: [+-]\d{2}:?\d{2}(?: \S+)?)?"
)
DATETIME_FMT = "yyyy-mm-dd hh:mm:ss"
DATE_FMT = "yyyy-mm-dd"


def parse_datetime(value: str) -> datetime | None:
    m = DATETIME.fullmatch(value)
    if not m:
        return None
    day, hms, frac = m.groups()
    return datetime.fromisoformat(f"{day} {hms or '00:00:00'}{(frac or '')[:7]}")


def cell(value: str):
    dt = parse_datetime(value)
    if dt is not None:
        return dt
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
    for col in ws.iter_cols(min_row=2):
        dts = [(c, c.value) for c in col if isinstance(c.value, datetime)]
        # Колонка, где всё время 00:00:00, — это дата: время не показываем.
        fmt = DATE_FMT if all(v.time() == time() for _, v in dts) else DATETIME_FMT
        for c, _ in dts:
            c.number_format = fmt
    ws.freeze_panes = "A2"
    wb.save(dst)


if __name__ == "__main__":
    typer.run(main)
