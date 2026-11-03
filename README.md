# Base de Datos 2 — Food Store

Repositorio del proyecto integrador **«Food Store»** desarrollado para la asignatura **Base de Datos II** (Tecnicatura Universitaria en Programación — UTN).

El repositorio reúne y documenta el avance progresivo de los trabajos prácticos de la materia:
1. **Primera entrega parcial del Trabajo Práctico Integrador (TPI):** Consolidación de las Unidades 1, 2 y 3 (integridad, transacciones, optimización, índices, vistas y procedimientos).
2. **TP6 (Unidad 4):** Forma Normal de Boyce-Codd (FNBC) y Desnormalización Controlada mediante vistas materializadas.
3. **TP7 (Unidad 5):** Administración y Seguridad de Food Store: roles, auditoría, incidentes y protección de datos personales.
4. **TP8 (Unidad 6):** Mantenimiento, Respaldo y Recuperación ante desastres (Disaster Recovery) de Food Store.
5. **TP9 (Unidad 7):** NoSQL y nuevas formas de almacenamiento: modelado documental, migración y contrastación PostgreSQL vs. MongoDB.

---

## Estado del proyecto

El estado actual del repositorio incorpora el **TP9 — Unidad 7: NoSQL y nuevas formas de almacenamiento (MongoDB y Food Store)**, implementando la representación documental del subconjunto transaccional de pedidos y líneas de detalle, la contrastación verificable de consultas entre ambos motores, y la evaluación crítica de recomendaciones de arquitectura generadas por Inteligencia Artificial.

- **Rama activa de trabajo:** `tp9-nosql`
- **Motores utilizados:** PostgreSQL 17.11 (OLTP Relacional) y MongoDB 9.0.4 (Documental NoSQL)
- **Shells e interfaces de comando:** `mongosh` (2.x), `psql`, PowerShell (.ps1) y Bash (.sh)
- **Bases de datos involucradas:** `foodstore` (PostgreSQL relacional) y `foodstore_nosql` (MongoDB documental)

---

## Alcance del repositorio por entregas

### 1. TPI del primer parcial (Unidades 1, 2 y 3)
Consolida el diseño relacional, transacciones ACID, concurrencia, optimización de consultas con `EXPLAIN ANALYZE`, índices B-Tree/parciales, vistas y el borrado lógico mediante `sp_desactivar_producto`.
- Documentación e informe: `docs/tpi_parcial1/README.md` e `docs/tpi_parcial1/informe_tpi_parcial1.md`.
- Pruebas reproducibles: `db/tpi_parcial1_pruebas.sql`.

### 2. TP6 (Unidad 4: FNBC y Desnormalización Controlada)
Aborda la descomposición sin pérdida preservando dependencias de `control_lote_almacen` en `responsable_deposito` y `control_lote`, y la aceleración analítica del panel de ventas mediante la vista materializada `mv_ventas_categoria_dia` con auditoría de sincronización.
- Documentación e informe histórico: `docs/tp6/README.md` e `docs/tp6/informe_fnbc.md`.
- Scripts canónicos: `db/tp_fnbc_control_lote.sql` y `db/tp_desnormalizacion_top_categorias.sql`.

### 3. TP7 (Unidad 5: Administración y Seguridad)
Implementa la arquitectura de identidades bajo mínimo privilegio, auditoría nativa de servidor, laboratorio de simulación de incidentes, protección de datos personales y la bitácora de uso crítico de IA.
- Documentación e informes: `docs/tp7/` (especificación Kiro, `informe_auditoria.md`, `informe_incidente.md`, `verificacion_roles.md`).
- Scripts canónicos: `sql/roles.sql`, `sql/auditoria_test.sql`, `sql/simulacro_incidente.sql` y `sql/usuario_anon.sql`.

### 4. TP8 (Unidad 6: Mantenimiento, Respaldo y Recuperación)
Desarrolla el plan operativo de continuidad, resiliencia y diagnóstico de salud para Food Store:
- Respaldo automatizado custom (`-Fc`) con timestamping (`backup_foodstore.ps1` / `.sh`).
- Monitoreo en 4 dimensiones (`health_check.sql`) y mantenimiento seguro no bloqueante (`maintenance.sql`).
- Simulacro cronometrado de recuperación ante desastres en entorno aislado midiendo RTO y RPO (`restore_test.ps1` / `.sh`).
- Documentación e informe de 1 página: `docs/tp8/README.md`, `docs/tp8/informe_u6.md` y `docs/tp8/informe_u6.pdf`.

### 5. TP9 (Unidad 7: NoSQL y Nuevas Formas de Almacenamiento)
Implementa el paradigma orientado a documentos sobre la base de pedidos de Food Store:
* **Parte 1 — Modelo Documental y Migración:** Análisis de tablas y claves de PostgreSQL (`pedido`, `detalle_pedido`, `cliente`, `producto`), diseño desnormalizado BSON (*Aggregate Root*) en la colección `pedidos` (base `foodstore_nosql`), migración con `insertMany()` y fundamentación de las reglas de integridad y ventajas de embeber líneas y clientes.
* **Parte 2 — Consultas y Verificación Cruzada:** Ejecución de 4 consultas en MongoDB Shell (`mongosh`) con filtros directos y sobre arreglos internos, formulación de sentencias análogas en PostgreSQL (`consultas_postgresql.sql`) y tabla comparativa demostrando 100% de coincidencia en cantidad e identificadores (`[1, 3, 4]`).
* **Parte 3 — Evaluación de IA y Conclusión Técnica:** Contraste crítico de afirmaciones de asistentes de IA sobre atomicidad a nivel de documento único y costo de uniones relacionales vs. denormalización, junto a una conclusión técnica de 177 palabras que fundamenta la conveniencia de una arquitectura híbrida/políglota.
* **Entregables:** `docs/tp9/informe_tp9.md`, `docs/tp9/informe_tp9.pdf` (5 páginas exactas), `docs/tp9/consultas_mongodb.js` y `docs/tp9/consultas_postgresql.sql`.

---

## Estructura del repositorio

```text
Food-Store/
├── db/                                      # Scripts SQL históricos y de desarrollo
│   ├── schema.sql                           # Esquema DDL fuente de verdad
│   ├── indices.sql                          # Índices del modelo base
│   ├── views.sql                            # Vistas del dominio base
│   ├── generador_datos_tp3_carga.sql        # Poblado masivo de datos
│   ├── tp_fnbc_control_lote.sql             # TP6: Descomposición FNBC
│   ├── tp_desnormalizacion_top_categorias.sql # TP6: Vista materializada y auditoría
│   ├── roles.sql                            # TP7: Implementación de roles y permisos
│   └── backups/                             # Respaldos .dump (excluidos en .gitignore)
│
├── sql/                                     # Entregables canónicos SQL
│   ├── roles.sql                            # TP7: Jerarquías, RLS y mínimo privilegio
│   ├── auditoria_test.sql                   # TP7: Secuencia de prueba de auditoría
│   ├── simulacro_incidente.sql              # TP7: Reproducción de ataque de acceso indebido
│   ├── usuario_anon.sql                     # TP7: Dataset anonimizado
│   ├── health_check.sql                     # TP8: Monitoreo preventivo del cluster
│   └── maintenance.sql                      # TP8: Revisión de autovacuum y VACUUM ANALYZE
│
├── docs/                                    # Informes, especificaciones y evidencias
│   ├── tp1/ a tp6/                          # Documentación histórica
│   ├── tp7/                                 # TP7: Entregables formales de Unidad 5
│   ├── tp8/                                 # TP8: Entregables formales de Unidad 6
│   │   ├── README.md                        # Documentación consolidada de TP8
│   │   ├── SPEC_U6.md                       # Especificación del plan y reglas operativas
│   │   ├── backup_foodstore.ps1 / .sh       # Script de respaldo automatizado
│   │   ├── health_check.sql                 # Monitoreo preventivo de 4 dimensiones
│   │   ├── maintenance.sql                  # Mantenimiento justificado no bloqueante
│   │   ├── restore_test.ps1 / .sh           # Simulacro de recuperación y RTO/RPO
│   │   └── informe_u6.md / .pdf             # Informe post-incidente
│   │
│   ├── tp9/                                 # TP9: Entregables formales de Unidad 7 (NoSQL)
│   │   ├── BDII_Unidad7_TP_FoodStore_NoSQL.md # Consigna del TP Unidad 7
│   │   ├── BDII_Unidad7_TP_FoodStore_NoSQL.pdf # Consigna original en PDF
│   │   ├── consultas_mongodb.js             # Script ejecutable de inicialización y consultas
│   │   ├── consultas_postgresql.sql         # Consultas SQL equivalentes de comparación
│   │   ├── informe_tp9.md                   # Informe exhaustivo en formato Markdown
│   │   ├── informe_tp9.html                 # Maquetado HTML optimizado para exportación
│   │   └── informe_tp9.pdf                  # Informe oficial de entrega (5 páginas exactas)
│   │
│   └── tpi_parcial1/                        # Consolidación del primer parcial
│
├── BITACORA.md                              # Bitácora de interacción y lectura crítica con IA
└── README.md                                # Documentación general del repositorio (Estado TP9)
```

---

## Bases de datos del proyecto

1. **`bd2_tpi_parcial1`:** Base consolidada del primer parcial (Unidades 1 a 3).
2. **`bd2_tp6`:** Base descartable utilizada para las pruebas de FNBC y desnormalización de la Unidad 4.
3. **`bd2_tp7`:** Base de desarrollo dedicada para la Unidad 5 (Administración y Seguridad).
4. **`foodstore`:** Base principal de producción PostgreSQL para el ciclo de vida, respaldos, monitoreo y comparación SQL.
5. **`foodstore_restore_test`:** Base descartable para los simulacros de recuperación y medición de RTO/RPO del TP8.
6. **`foodstore_nosql`:** Base documental en MongoDB para el modelado de pedidos embebidos y consultas del TP9.

---

## Procedimiento de Reproducción y Verificación del TP9 (Unidad 7)

Para reproducir y validar el laboratorio NoSQL de forma automatizada:

### 1. Inicialización y Consultas en MongoDB (`mongosh`)
Ejecuta la limpieza idempotente, inserción masiva (`insertMany`) de los 5 pedidos de muestra y las 4 consultas operativas:
```powershell
mongosh --quiet --file docs/tp9/consultas_mongodb.js
```
*Salida esperada:* Conteo de 5 documentos insertados y salida JSON formateada para cada una de las 4 consultas (proyección total, filtro de estado `ENTREGADO`, búsqueda de producto `Hamburguesa Clásica` en arreglo interno y filtro por total > $10.000).

### 2. Consultas Equivalentes en PostgreSQL (`psql`)
Ejecuta las consultas relacionales equivalentes sobre la base `foodstore`:
```powershell
psql -U postgres -d foodstore -f docs/tp9/consultas_postgresql.sql
```
*Salida esperada:* Recuperación de los registros coincidentes confirmando que los pedidos devueltos en PostgreSQL son exactamente `[1, 3, 4]`, verificando la correspondencia biunívoca con MongoDB.

---

## Decisiones Técnicas y de Diseño NoSQL Consolidadas

* **Patrón Aggregate Root y Desnormalización:** Se modela el pedido como documento único que contiene la cabecera, el snapshot de contacto del cliente y el arreglo de líneas de venta, eliminando operaciones de `$lookup` y permitiendo lecturas atómicas de una sola operación de disco/red (*single-document atomicity*).
* **Inmutabilidad de Precios Históricos:** Al desnormalizar los productos dentro del arreglo `lineas`, se congelan el `precio_unitario` y el `subtotal` calculados al instante de la venta, garantizando que futuras modificaciones en el catálogo relacional no distorsionen los importes de ventas pasadas.
* **Navegación de Arreglos vs. Uniones Relacionales:** En MongoDB, filtrar por productos embebidos (`lineas.producto_id`) preserva la cardinalidad de documentos sin duplicaciones; en PostgreSQL, la consulta exige un `JOIN` entre `pedido` y `detalle_pedido` junto a `DISTINCT` o `WHERE EXISTS` para neutralizar la multiplicación cartesiana de filas.
* **Persistencia Políglota (CQRS):** Se fundamenta la conveniencia de no descartar PostgreSQL, sino combinarlo con MongoDB: mantener PostgreSQL como núcleo transaccional ACID de alta integridad para la compra y control de inventario concurrente, y proyectar asincrónicamente pedidos finalizados a MongoDB para visualización e historial de alta concurrencia.

---

## Historial de Ramas y Archivo de Documentación

* **`main`:** Rama troncal de integración de entregas evaluadas.
* **`tpi-parcial1`:** Primera entrega integradora (Unidades 1 a 3).
* **`tp6-fnbc-desnormalizacion`:** Unidad 4 (FNBC y desnormalización). Preservado en [`docs/tp6/README.md`](docs/tp6/README.md).
* **`tp7-administracion-seguridad`:** Unidad 5 (Administración y Seguridad). Preservado en [`docs/tp7/README.md`](docs/tp7/README.md).
* **`tp8-mantenimiento`:** Unidad 6 (Mantenimiento, Respaldo y Recuperación). Preservado en [`docs/tp8/README.md`](docs/tp8/README.md).
* **`tp9-nosql`:** Unidad 7 (NoSQL y nuevas formas de almacenamiento — Rama Activa de Trabajo).
