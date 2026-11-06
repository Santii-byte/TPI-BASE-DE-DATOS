# DUIA — TP6 Desnormalización / FNBC

## Herramienta

DeepSeek V4.1 Flash Free (OpenCode)

## Prompt utilizado

"del directorio C:\Users\tidus\OneDrive\Escritorio\BD\TPI-BASE-DE-DATOS
tengo que empezar el TP numero 6, que vendria siendo de desnormalizacion. Estas son las consignas: [Food store.txt: reglas de negocio de control_lote_almacen, esquema inicial, instancia de ejemplo y puntos a) a f)]"

## Qué generó

Listo. Dejé el TP6 armado en `TP6/` con la resolución completa de las consignas a–f y el script SQL entregable.

**Resultados clave**

- **Dependencias funcionales:** `{LoteID, DepositoID} → ResponsableControlID` y `ResponsableControlID → DepositoID`.
- **Claves candidatas:** `{LoteID, DepositoID}` y `{LoteID, ResponsableControlID}`. Los tres atributos son primos; no hay atributos no primos.
- **FNBC:** no cumple. La dependencia violatoria es `ResponsableControlID → DepositoID`, porque `ResponsableControlID⁺ = {ResponsableControlID, DepositoID}` y no es superclave. La relación sí está en 3FN, pero la consigna exige decidir con la definición de FNBC.
- **Descomposición sin pérdida:**
  - `responsable_control (ResponsableControlID, DepositoID)` — PK `ResponsableControlID`.
  - `control_lote (LoteID, ResponsableControlID)` — PK `(LoteID, ResponsableControlID)`.
- **Justificación lossless:** `R1 ∩ R2 = {ResponsableControlID}` y ese atributo es superclave (clave primaria) de `R1`, por lo que la reunión natural no genera tuplas espurias.
- **Migración:** `responsable_control` queda con `(801,30)` y `(802,31)`; `control_lote` con `(501,801)`, `(502,801)` y `(503,802)`. La vista reconstruye exactamente las 3 filas originales.

**Archivos creados**

- `TP6/tp_fnbc_control_lote.sql` — esquema original, instancia de ejemplo, tablas descompuestas, vista de compatibilidad, migración y verificaciones automáticas.
- `TP6/informe_fnbc.md` — desarrollo escrito de las partes a) a f).
- `TP6/README.md` — resumen y guía de ejecución.
- `TP6/cambios/DUIA_TP6_Desnormalizacion_FNBC.md` — esta DUIA.

**Cómo ejecutar**

```bash
psql -d copia_trabajo -f TP6/tp_fnbc_control_lote.sql
```

El script trabaja en el esquema aislado `tp6_fnbc`, es reejecutable y no toca las tablas existentes de Food Store. Para inspeccionar sin persistir, cambiá `COMMIT;` por `ROLLBACK;`.

**Verificación**

```sql
SELECT * FROM tp6_fnbc.control_lote_almacen_compat
ORDER BY lote_id, deposito_id;
```

Debe devolver:

| lote_id | deposito_id | responsable_control_id |
|---:|---:|---:|
| 501 | 30 | 801 |
| 502 | 30 | 801 |
| 503 | 31 | 802 |

El script además compara original y vista con `EXCEPT` en ambos sentidos y lanza una excepción si hay diferencias.

**Nota:** validé el script en un clúster PostgreSQL 17 temporal y aislado (`initdb` + puerto 55432): ejecutó dos veces seguidas sin errores y la diferencia simétrica entre original y vista dio `0/0`. No lo ejecuté contra tu base real porque no tengo credenciales locales. No realicé commits.

## Qué se aceptó

Se generó el paquete completo del TP6: script SQL, informe a–f, README y esta DUIA.

## Qué se modificó o descartó y por qué

-

## Verificación realizada

-
