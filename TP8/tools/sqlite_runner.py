#!/usr/bin/env python3
"""Runner minimo de SQLite para generar evidencia del TP8.

No reemplaza a sqlite3 ni a DB Browser: solo permite ejecutar los mismos
archivos .sql desde la linea de comandos de este equipo, que no tiene el
binario sqlite3 instalado. Usa la libreria estandar sqlite3 de Python.

Uso:
  python sqlite_runner.py --db ruta.db --sql archivo.sql
  python sqlite_runner.py --db ruta.db --import-csv ruta.csv --sql importar.sql
  python sqlite_runner.py --db ruta.db --query "SELECT ..."
"""
from __future__ import annotations

import argparse
import csv
import sqlite3
import sys
from pathlib import Path


def print_rows(cur: sqlite3.Cursor) -> None:
    if cur.description is None:
        return
    headers = [d[0] for d in cur.description]
    rows = cur.fetchall()
    print(" | ".join(headers))
    print("-+-".join("-" * len(h) for h in headers))
    for row in rows:
        print(" | ".join("" if v is None else str(v) for v in row))
    print(f"({len(rows)} fila{'s' if len(rows) != 1 else ''})")


def iter_statements(text: str):
    buf = ""
    for line in text.splitlines(keepends=True):
        if not buf and (not line.strip() or line.lstrip().startswith("--")):
            continue
        buf += line
        if sqlite3.complete_statement(buf):
            yield buf
            buf = ""
    if buf.strip():
        yield buf


def run_sql(conn: sqlite3.Connection, path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    print(f"\n===== {path.name} =====")
    for stmt in iter_statements(text):
        try:
            cur = conn.execute(stmt)
            print_rows(cur)
        except sqlite3.Error as exc:
            print(f"ERROR ESPERADO O REAL: {exc}")
    conn.commit()


def import_csv(conn: sqlite3.Connection, path: Path) -> None:
    with path.open("r", encoding="utf-8-sig", newline="") as fh:
        reader = csv.DictReader(fh)
        rows = [
            (
                row.get("id"), row.get("nombre"), row.get("categoria"),
                row.get("precio_centavos"), row.get("stock"),
                row.get("disponible"), row.get("eliminado"),
                row.get("fecha_copia"),
            )
            for row in reader
        ]
    conn.execute("DELETE FROM snapshot_raw")
    conn.executemany(
        "INSERT INTO snapshot_raw (id, nombre, categoria, precio_centavos, stock, disponible, eliminado, fecha_copia) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        rows,
    )
    conn.commit()
    print(f"CSV importado en snapshot_raw: {len(rows)} filas")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", required=True)
    ap.add_argument("--sql", action="append", default=[])
    ap.add_argument("--import-csv")
    ap.add_argument("--query")
    args = ap.parse_args()

    db = Path(args.db)
    conn = sqlite3.connect(db)
    conn.execute("PRAGMA foreign_keys = ON")
    try:
        if args.import_csv:
            import_csv(conn, Path(args.import_csv))
        for sql in args.sql:
            run_sql(conn, Path(sql))
        if args.query:
            print_rows(conn.execute(args.query))
    finally:
        conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())