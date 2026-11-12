#!/usr/bin/env python3
"""Genera la evidencia de los casos C2-C6 en UTF-8.

Requiere:
  * PostgreSQL escuchando en localhost:55438 (cluster de laboratorio).
  * Base foodstore_u8 con el estado base (precio de leche 95000, producto 6 vigente).
  * food-store/movil/foodstore_movil.db ya generado.

Se ejecuta desde la raiz TP8:
  python tools/generar_evidencia.py
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FS = ROOT / "food-store"
TOOL = ROOT / "tools" / "sqlite_runner.py"
PSQL = Path(r"C:\Program Files\PostgreSQL\17\bin\psql.exe")
DB = FS / "docs" / "evidencias" / "casos_evidencia.db"
OUT = FS / "docs" / "evidencias" / "casos_c2_c6.txt"

env = os.environ.copy()
env["PGCLIENTENCODING"] = "UTF8"


def run(args: list[str]) -> str:
    proc = subprocess.run(args, cwd=FS, env=env, capture_output=True)
    text = proc.stdout.decode("utf-8", errors="replace")
    err = proc.stderr.decode("utf-8", errors="replace")
    if err:
        text += err
    return text.rstrip() + "\n"


def psql(script: str) -> str:
    return run([str(PSQL), "-h", "localhost", "-p", "55438", "-U", "postgres",
                "-d", "foodstore_u8", "-v", "ON_ERROR_STOP=1", "-f", script])


def sqlite(*args: str) -> str:
    return run([sys.executable, str(TOOL), "--db", str(DB), *args])


def main() -> int:
    shutil.copyfile(FS / "movil" / "foodstore_movil.db", DB)
    parts: list[str] = []
    add = parts.append

    def block(title: str, text: str) -> None:
        add("=" * 78)
        add(title)
        add("=" * 78)
        add(text)

    block("C2 - EL SERVIDOR SUBE EL PRECIO DE LA LECHE", psql("postgres/casos/c2_subir_precio.sql"))
    block("C2 - EXPORTAR NUEVA INSTANTANEA", psql("postgres/exportar_snapshot.sql"))
    block("C2 - IMPORTAR Y EVALUAR SOLICITUD CON PRECIO VIEJO", sqlite(
        "--import-csv", "movil/servidor_snapshot.csv",
        "--sql", "movil/importar_snapshot.sql",
        "--sql", "movil/casos/c2_solicitud_conflicto.sql",
        "--sql", "movil/semaforo.sql"))
    block("C2 - EL CLIENTE ACEPTA: ACTUALIZAR PRECIO Y NUEVA SOLICITUD", sqlite(
        "--sql", "movil/casos/c2_aceptar_precio.sql",
        "--sql", "movil/semaforo.sql"))

    block("RESTAURAR PRECIO DEL SERVIDOR", psql("postgres/casos/c2_restaurar_precio.sql"))
    block("EXPORTAR INSTANTANEA PARA C3", psql("postgres/exportar_snapshot.sql"))
    block("C3 - 5 MANZANAS CON STOCK 4: RECHAZADO", sqlite(
        "--import-csv", "movil/servidor_snapshot.csv",
        "--sql", "movil/importar_snapshot.sql",
        "--sql", "movil/casos/c3_solicitud_stock.sql",
        "--sql", "movil/semaforo.sql"))

    block("C4 - BAJA LOGICA DEL PRODUCTO 6", psql("postgres/casos/c4_baja_producto.sql"))
    block("C4 - EXPORTAR INSTANTANEA CON LA BAJA", psql("postgres/exportar_snapshot.sql"))
    block("C4 - IMPORTAR, CONSERVAR ITEM Y EVALUAR", sqlite(
        "--import-csv", "movil/servidor_snapshot.csv",
        "--sql", "movil/importar_snapshot.sql",
        "--sql", "movil/casos/c4_solicitud_baja.sql",
        "--sql", "movil/semaforo.sql"))

    block("C4 - RESTAURAR PRODUCTO 6 EN EL SERVIDOR", psql("postgres/casos/c4_restaurar_producto.sql"))
    block("C5 - EXPORTAR INSTANTANEA SIN CAMBIOS", psql("postgres/exportar_snapshot.sql"))
    block("C5 - BORRADOR SIN CAMBIOS: SIMULADO_APROBADO", sqlite(
        "--import-csv", "movil/servidor_snapshot.csv",
        "--sql", "movil/importar_snapshot.sql",
        "--sql", "movil/casos/c5_solicitud_sin_cambios.sql",
        "--sql", "movil/semaforo.sql"))
    block("C6 - REENVIAR LA MISMA SOLICITUD (MISMO UUID)", sqlite(
        "--sql", "movil/casos/c6_reenvio.sql",
        "--sql", "movil/semaforo.sql"))

    block("VERIFICACION FINAL EN POSTGRESQL: PEDIDOS Y STOCK SIN CAMBIOS",
          psql("postgres/05_verificacion.sql"))

    OUT.write_text("\n".join(parts), encoding="utf-8")
    print(f"Evidencia generada: {OUT} ({OUT.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())