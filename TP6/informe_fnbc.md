# TP 6 — Desnormalización y FNBC

**Food Store — Control de lotes por depósito**

- **Integrantes:** Franco Rios y Santino Barone
- **Materia:** Base de Datos II
- **Motor:** PostgreSQL 16+
- **Script entregable:** `tp_fnbc_control_lote.sql`

---

## Notación y datos de partida

Se trabaja con la relación:

```text
R = control_lote_almacen (LoteID, DepositoID, ResponsableControlID)
```

y la instancia de ejemplo:

| LoteID | DepositoID | ResponsableControlID |
|-------:|-----------:|---------------------:|
| 501 | 30 | 801 |
| 502 | 30 | 801 |
| 503 | 31 | 802 |

Reglas de negocio relevadas:

1. Para un lote y un depósito interviniente dados, el responsable de control queda unívocamente determinado.
2. Cada responsable de control pertenece a un único depósito.

---

## a) Dependencias funcionales en notación formal

A partir de las reglas de negocio:

```text
FD1: {LoteID, DepositoID} → ResponsableControlID
FD2: ResponsableControlID → DepositoID
```

- **FD1** expresa la regla 1: el par lote–depósito determina al responsable. Es una dependencia **total**: ni `LoteID` solo ni `DepositoID` solo determinan `ResponsableControlID`.
- **FD2** expresa la regla 2: el responsable determina su depósito de pertenencia.

También valen las dependencias triviales habituales (`X → X`, `XY → X`, etc.), que no se consideran para el análisis.

Conjunto de dependencias funcionales:

```text
F = { {LoteID, DepositoID} → ResponsableControlID,
      ResponsableControlID  → DepositoID }
```

Abreviaturas usadas en el resto del informe:

```text
L = LoteID
D = DepositoID
R = ResponsableControlID
F = { LD → R, R → D }
```

---

## b) Clausuras y claves candidatas

### Clausuras de los subconjuntos razonables

Se calcula `X⁺` aplicando reiteradamente `F`:

| Subconjunto `X` | Clausura `X⁺` | ¿Superclave? |
|---|---|---|
| `∅` | `∅` | No |
| `{L}` | `{L}` | No |
| `{D}` | `{D}` | No |
| `{R}` | `{R, D}` | No |
| `{L, D}` | `{L, D, R}` | **Sí** |
| `{L, R}` | `{L, R, D}` | **Sí** |
| `{D, R}` | `{D, R}` | No |
| `{L, D, R}` | `{L, D, R}` | Sí, pero no minimal |

Detalle de los casos relevantes:

- `{L, D}⁺ = {L, D, R}` por FD1.
- `{L, R}⁺ = {L, R}` y, como `R → D`, se agrega `D`: `{L, R, D}`.
- `{R}⁺ = {R, D}`; no alcanza `L`, por lo tanto no es superclave.

### Claves candidatas

Un subconjunto es clave candidata si es superclave y **minimal** (ningún atributo sobra).

- `{L, D}`: es superclave. `{L}⁺ = {L}` y `{D}⁺ = {D}`, así que es minimal. **Clave candidata.**
- `{L, R}`: es superclave. `{L}⁺ = {L}` y `{R}⁺ = {R, D}`, así que es minimal. **Clave candidata.**
- `{D, R}`: no es superclave (no determina `L`).
- `{L, D, R}`: es superclave, pero contiene a `{L, D}` y a `{L, R}`, por lo que no es minimal.

```text
Claves candidatas de R = { {LoteID, DepositoID}, {LoteID, ResponsableControlID} }
```

### Atributos primos y no primos

- **Primos:** `LoteID`, `DepositoID`, `ResponsableControlID` (los tres pertenecen a alguna clave candidata).
- **No primos:** ninguno.

Esto anticipa un caso clásico: la relación está en 3FN (todos los atributos son primos), pero **no** en FNBC.

---

## c) Verificación formal de FNBC

Definición formal de FNBC:

> Una relación `R` está en FNBC si y solo si, para **toda** dependencia funcional no trivial `X → Y` de `F⁺`, el determinante `X` es superclave de `R`.

Análisis de cada dependencia no trivial:

1. **`{L, D} → R`**
   - `{L, D}⁺ = {L, D, R}`, es decir, determina todos los atributos.
   - Por lo tanto `{L, D}` **es superclave**.
   - Esta dependencia **cumple** FNBC.

2. **`R → D`**
   - `R⁺ = {R, D}`.
   - Como `R⁺ ≠ {L, D, R}`, `R` **no es superclave**.
   - Esta dependencia **viola FNBC**.

### Conclusión

`control_lote_almacen` **no está en FNBC**. La dependencia violatoria es:

```text
ResponsableControlID → DepositoID
```

Su determinante, `ResponsableControlID`, no es superclave porque solo determina a `{ResponsableControlID, DepositoID}` y no determina `LoteID`.

**Aclaración:** la relación sí está en 3FN, porque todos sus atributos son primos. Pero la consigna pide decidir con la definición de FNBC, y bajo esa definición la relación falla. Este es el ejemplo típico de relación en 3FN pero no en FNBC.

---

## d) Anomalías que habilita la violación de FNBC

La redundancia generada por `ResponsableControlID → DepositoID` produce las tres anomalías clásicas sobre la instancia dada.

### Anomalía de inserción

Supongamos que se incorpora el responsable `803`, que pertenece al depósito `30`, pero todavía no tiene asignado ningún lote. No es posible registrar ese dato maestro en `control_lote_almacen`: la clave primaria `(LoteID, DepositoID)` y las columnas `NOT NULL` obligan a inventar un `LoteID` para poder insertar la fila. Si se lo asigna a un lote, además hay que repetir el dato `DepositoID = 30`, que ya estaba almacenado en las filas de los lotes `501` y `502`. En otras palabras, no se puede representar de forma independiente el hecho “el responsable 803 pertenece al depósito 30”.

### Anomalía de borrado

Si se elimina el control del lote `503` (fila `(503, 31, 802)`), desaparece la única fila que registra que el responsable `802` pertenece al depósito `31`. Se pierde un dato maestro de la dotación de personal (`802 → 31`) como efecto colateral de borrar un hecho operativo (el control de un lote), aunque el responsable `802` siga existiendo y perteneciendo al depósito `31`.

### Anomalía de actualización

Si el responsable `801` es reasignado del depósito `30` al depósito `32`, hay que actualizar **dos** filas: `(501, 30, 801)` y `(502, 30, 801)`. Si se actualiza solo una, la base queda en un estado inconsistente: el mismo responsable aparecería perteneciendo simultáneamente a los depósitos `30` y `32`, violando la regla de negocio 2. Cuantas más filas tenga asignadas un responsable, mayor es el riesgo de una actualización parcial.

---

## e) Descomposición sin pérdida y script SQL

### Algoritmo aplicado

Partimos de:

```text
R = (L, D, R)
F = { LD → R, R → D }
```

Se detecta la dependencia violatoria `R → D`. Se aplica el algoritmo de descomposición binaria:

```text
R1 = X ∪ Y = {R, D}          → responsable_control (ResponsableControlID, DepositoID)
R2 = R − Y  = {L, D, R} − {D} = {L, R}
                              → control_lote (LoteID, ResponsableControlID)
```

Verificación de que ambas resultantes están en FNBC:

- **`R1(R, D)`**: la única dependencia no trivial es `R → D`; `R` es su clave primaria, por lo tanto es superclave. **Cumple FNBC.**
- **`R2(L, R)`**: la proyección de `F` no deja dependencias no triviales (`R → D` no puede expresarse porque `D` no está en `R2`; `LD → R` tampoco, porque `D` no está). La clave `{L, R}` determina todos los atributos de `R2`. **Cumple FNBC.**

### Tablas resultantes

```sql
CREATE TABLE responsable_control (
    responsable_control_id BIGINT PRIMARY KEY REFERENCES usuario(id),
    deposito_id            BIGINT NOT NULL REFERENCES deposito(id)
);

CREATE TABLE control_lote (
    lote_id                BIGINT NOT NULL REFERENCES lote(id),
    responsable_control_id BIGINT NOT NULL REFERENCES responsable_control(responsable_control_id),
    PRIMARY KEY (lote_id, responsable_control_id)
);
```

### Vista de compatibilidad

Reconstruye la relación original mediante reunión natural por el atributo común `ResponsableControlID`:

```sql
CREATE VIEW control_lote_almacen_compat AS
SELECT c.lote_id,
       r.deposito_id,
       c.responsable_control_id
  FROM control_lote AS c
  NATURAL JOIN responsable_control AS r;
```

El script completo, con el esquema original, la instancia, las tablas descompuestas, la migración, la vista y las verificaciones automáticas, está en:

```text
TP6/tp_fnbc_control_lote.sql
```

---

## f) Justificación de la reunión sin pérdida y migración

### Justificación formal

Teorema de reunión sin pérdida para una descomposición binaria:

> La descomposición de `R` en `R1` y `R2` es sin pérdida si y solo si el atributo común `R1 ∩ R2` es superclave de `R1` o de `R2`.

En este caso:

```text
R1 = (ResponsableControlID, DepositoID)
R2 = (LoteID, ResponsableControlID)
R1 ∩ R2 = {ResponsableControlID}
```

`ResponsableControlID` es **clave primaria de `R1`**, y por definición toda clave primaria es superclave. Entonces:

```text
ResponsableControlID → {ResponsableControlID, DepositoID}
```

es decir, el atributo común determina toda la tabla `R1`. Por lo tanto, la reunión natural de `R1` y `R2` **no genera tuplas espurias** y recupera exactamente la relación original: es una descomposición **sin pérdida**.

### Migración de la instancia de ejemplo

**R1 — `responsable_control`** (se elimina la redundancia de `801` con `DISTINCT`):

| ResponsableControlID | DepositoID |
|---:|---:|
| 801 | 30 |
| 802 | 31 |

**R2 — `control_lote`:**

| LoteID | ResponsableControlID |
|---:|---:|
| 501 | 801 |
| 502 | 801 |
| 503 | 802 |

**Reunión natural por `ResponsableControlID`:**

| LoteID | DepositoID | ResponsableControlID |
|---:|---:|---:|
| 501 | 30 | 801 |
| 502 | 30 | 801 |
| 503 | 31 | 802 |

El resultado coincide fila por fila con la instancia original.

### Verificación implementada

El script realiza tres controles:

1. **Verificación previa de FD2:** aborta la migración si un responsable aparece asociado a más de un depósito en el origen.
2. **Diferencia simétrica con `EXCEPT` en ambos sentidos:** ambas consultas deben devolver `0` filas.
3. **Aserción en bloque `DO`:** si la vista no reconstruye exactamente la relación original, lanza una excepción y revierte la transacción; si coincide, emite un `NOTICE` de confirmación.

### Observación de diseño

La descomposición es **sin pérdida**, pero no preserva como restricción local la unicidad original de `(LoteID, DepositoID)`: la dependencia `{L, D} → R` no queda expresada dentro de `R2`. Por eso, dos responsables distintos que pertenezcan al mismo depósito podrían controlar el mismo lote y, al reunir, aparecerían dos filas con igual `(LoteID, DepositoID)`.

Si se quisiera garantizar también esa restricción, habría que agregar una validación adicional (por ejemplo, un trigger que consulte `responsable_control` antes de insertar en `control_lote`, o una aserción a nivel de aplicación). Se documenta como limitación teórica conocida de la descomposición en FNBC: **FNBC garantiza la eliminación de redundancias por dependencias funcionales, pero no necesariamente la preservación de todas las dependencias ni de todas las restricciones de clave originales**.

---

## Archivos del TP

```text
TP6/
├── tp_fnbc_control_lote.sql   # Entregable SQL completo
├── informe_fnbc.md            # Este informe (partes a–f)
└── cambios/
    └── DUIA_TP6_Desnormalizacion_FNBC.md
```

## Cómo ejecutar

```bash
psql -d copia_trabajo -f TP6/tp_fnbc_control_lote.sql
```

El script crea el esquema aislado `tp6_fnbc` para no interferir con el resto de la base Food Store. Si se desea inspeccionar sin persistir, reemplazar `COMMIT;` por `ROLLBACK;` al final del bloque.
