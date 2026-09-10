# Protocolo de seguridad para cambios en la base de datos

Este protocolo establece las medidas de seguridad utilizadas durante el desarrollo del Trabajo Práctico de Base de Datos 2.

## 1. Copia de trabajo

Los cambios y pruebas se realizan sobre la base de datos `tp_bd2_trabajo`, creada como copia de la base `practica_bd2`.

La base `practica_bd2` se conserva como referencia y no se utiliza para realizar modificaciones durante las pruebas.

De esta manera, los cambios realizados durante el desarrollo no afectan a la base original.

## 2. Uso de transacciones

Antes de realizar modificaciones sobre la estructura o los datos, las operaciones se prueban dentro de una transacción.

El procedimiento utilizado es:

```sql
BEGIN;

-- operaciones a probar

ROLLBACK;
```

Durante la etapa de prueba se utiliza `ROLLBACK` para deshacer los cambios y verificar que las operaciones sean correctas antes de confirmarlas definitivamente.

Cuando una modificación haya sido revisada y validada, podrá utilizarse `COMMIT` para confirmarla.

## 3. Respaldo previo

Antes de realizar cambios estructurales importantes, como `ALTER TABLE`, `DROP` o migraciones, se realiza un respaldo de la base de trabajo mediante `pg_dump`.

Los archivos de respaldo se almacenan en:

`db/backups/`

Estos archivos están excluidos del repositorio mediante `.gitignore` y no se versionan en Git.

Ejemplo de respaldo:

```powershell
pg_dump -h localhost -p 5432 -U postgres -F c -f db\backups\respaldo.dump tp_bd2_trabajo
```

## Objetivo

El objetivo de este protocolo es evitar la pérdida accidental de datos, permitir la recuperación ante errores y garantizar que los cambios realizados durante el desarrollo puedan ser probados de manera controlada.