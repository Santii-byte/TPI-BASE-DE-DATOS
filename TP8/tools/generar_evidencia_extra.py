#!/usr/bin/env python3
"""Genera evidencia auxiliar del TP8 (esquema, snapshot, pruebas, semaforo)."""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FS = ROOT / "food-store"
EV = FS / "docs" / "evidencias"
TOOL = ROOT / "tools" / "sqlite_runner.py"
PSQL = Path(r"C:\Program Files\PostgreSQL\17\bin\psql.exe")
env = os.environ.copy()
env["PGCLIENTENCODING"] = "UTF8"


def run(args: list[str]) -> str:
    p = subprocess.run(args, cwd=FS, env=env, capture_output=True)
    return (p.stdout + p.stderr).decode("utf-8", errors="replace").rstrip() + "\n"


def psql(*args: str) -> str:
    return run([str(PSQL), "-h", "localhost", "-p", "55438", "-U", "postgres",
                "-d", "foodstore_u8", *args])


def sqlite(db: Path, *args: str) -> str:
    return run([sys.executable, str(TOOL), "--db", str(db), *args])


def write(name: str, text: str) -> None:
    (EV / name).write_text(text, encoding="utf-8")
    print(f"  {name}: {len(text)} caracteres")


def main() -> int:
    EV.mkdir(parents=True, exist_ok=True)

    write("01_esquema_y_datos.txt", "\n".join([
        "=== TABLAS Y VISTA ===",
        psql("-c", "\\dt"),
        "=== VISTA v_snapshot_movil (primeras filas) ===",
        psql("-c", "SELECT * FROM v_snapshot_movil ORDER BY id LIMIT 5;"),
        "=== CONTEO POR TABLA ===",
        psql("-c", "SELECT 'producto' AS tabla, count(*) FROM producto UNION ALL SELECT 'pedido', count(*) FROM pedido UNION ALL SELECT 'detalle_pedido', count(*) FROM detalle_pedido UNION ALL SELECT 'tienda', count(*) FROM tienda;"),
        "=== CONTROL DE INSTALACION ===",
        psql("-c", "SELECT * FROM control_instalacion;"),
    ]))

    write("02_export_snapshot.txt", "\n".join([
        "=== EXPORTACION psql (\\copy) ===",
        psql("-v", "ON_ERROR_STOP=1", "-f", "postgres/exportar_snapshot.sql"),
        "=== PRIMERAS LINEAS DEL CSV ===",
        "\n".join((FS / "movil" / "servidor_snapshot.csv").read_text(encoding="utf-8").splitlines()[:5]) + "\n",
    ]))

    # Base limpia para pruebas y semaforo.
    pruebas_db = EV / "pruebas.db"
    if pruebas_db.exists():
        pruebas_db.unlink()
    schema = sqlite(pruebas_db, "--sql", "movil/schema_sqlite.sql")
    carga = sqlite(pruebas_db, "--import-csv", "movil/servidor_snapshot.csv",
                   "--sql", "movil/importar_snapshot.sql",
                   "--sql", "movil/datos_prueba.sql",
                   "--sql", "movil/semaforo.sql")
    write("03_carga_y_semaforo_inicial.txt", "\n".join([
        "=== CREACION DEL ESQUEMA SQLITE ===", schema,
        "=== IMPORTACION + DATOS + SEMAFORO INICIAL ===", carga,
    ]))

    sem = EV / "semaforo.db"
    if sem.exists():
        sem.unlink()
    sqlite(sem, "--sql", "movil/schema_sqlite.sql")
    sqlite(sem, "--import-csv", "movil/servidor_snapshot.csv",
           "--sql", "movil/importar_snapshot.sql",
           "--sql", "movil/datos_prueba.sql")

    tests = EV / "pruebas.db"
    if tests.exists():
        tests.unlink()
    sqlite(tests, "--sql", "movil/schema_sqlite.sql")
    sqlite(tests, "--import-csv", "movil/servidor_snapshot.csv",
           "--sql", "movil/importar_snapshot.sql",
           "--sql", "movil/datos_prueba.sql",
           "--sql", "movil/semaforo.sql")
    write("04_pruebas_sqlite.txt", sqlite(
        tests, "--sql", "movil/pruebas_sqlite.sql", "--sql", "movil/semaforo.sql"))

    write("05_verificacion_postgres.txt", psql("-v", "ON_ERROR_STOP=1", "-f", "postgres/05_verificacion.sql"))
    return 0


if __name__ == "__main__":
    sys.exit(main())