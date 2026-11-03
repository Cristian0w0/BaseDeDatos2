# Base de Datos 2 — Food Store

Repositorio del proyecto integrador **«Food Store»** desarrollado para la asignatura **Base de Datos II** (Tecnicatura Universitaria en Programación — UTN).

El repositorio reúne y documenta el avance progresivo de los trabajos prácticos de la materia:
1. **Primera entrega parcial del Trabajo Práctico Integrador (TPI):** Consolidación de las Unidades 1, 2 y 3 (integridad, transacciones, optimización, índices, vistas y procedimientos).
2. **TP6 (Unidad 4):** Forma Normal de Boyce-Codd (FNBC) y Desnormalización Controlada mediante vistas materializadas.
3. **TP7 (Unidad 5):** Administración y Seguridad de Food Store: roles, auditoría, incidentes y protección de datos personales.
4. **TP8 (Unidad 6):** Mantenimiento, Respaldo y Recuperación ante desastres (Disaster Recovery) de Food Store.

---

## Estado del proyecto

El estado actual del repositorio incorpora el **TP8 — Unidad 6: Mantenimiento, Respaldo y Recuperación de Food Store**, integrando un procedimiento integral de respaldo automatizado en formato custom (`-Fc`), monitoreo preventivo de salud del cluster, mantenimiento seguro no bloqueante y simulacro cronometrado de recuperación ante desastres contra reloj (medición de RTO y RPO).

- **Rama activa de trabajo:** `tp8-mantenimiento`
- **Motor utilizado:** PostgreSQL 16+ (PostgreSQL 17.11)
- **Lenguaje de procedimientos y scripts:** PL/pgSQL, PowerShell (.ps1) y Bash (.sh)
- **Bases de datos involucradas:** `foodstore` (producción/origen) y `foodstore_restore_test` (descartable de prueba)

---

## Alcance del repositorio por entregas

### 1. TPI del primer parcial (Unidades 1, 2 y 3)
Consolida el diseño relacional, transacciones ACID, concurrencia, optimización de consultas con `EXPLAIN ANALYZE`, índices B-Tree/parciales, vistas y el borrado lógico mediante `sp_desactivar_producto`.
- Documentación e informe: `docs/tpi_parcial1/README.md` y `docs/tpi_parcial1/informe_tpi_parcial1.md`.
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
* **Parte 1 — Especificación y Plan (`SPEC_U6.md`):** Matriz de tareas automatizables (frecuencias, ventanas operativas, evidencias y condiciones de éxito) y reglas de seguridad (aislamiento de producción, no exposición de credenciales y uso obligatorio de formato custom).
* **Parte 2 — Respaldo Automatizable (`backup_foodstore.ps1` / `.sh`):** Exportación lógica en formato custom (`-Fc`), timestamping cronológico (`YYYYMMDD_HHMMSS`), compresión zlib integrada, registro en `logs/` y salida estricta con código de error.
* **Parte 3 — Monitoreo y Mantenimiento (`health_check.sql` y `maintenance.sql`):** 4 dimensiones de salud (espacio de BD y objetos, conexiones y ratio de rollback, tuplas muertas/autovacuum y consultas de larga duración) y mantenimiento justificado mediante `VACUUM (VERBOSE, ANALYZE)` no bloqueante, fundamentando la prohibición taxativa de `VACUUM FULL`.
* **Parte 4 — Simulacro de Desastre Contra Reloj (`restore_test.ps1` / `.sh`):** Recreación limpia de la base aislada `foodstore_restore_test`, ejecución de `pg_restore --no-owner --no-privileges`, validaciones de integridad referencial y de dominio (0 productos y detalles inválidos) y cronometraje de RTO y RPO.
* **Parte 5 — Informe Post-Incidente (`informe_u6.md` / `informe_u6.pdf`):** Reporte ejecutivo de 1 página con métricas observadas, análisis de SLA, resolución de problemas reales, propuesta de mejora (restauración paralela `-j`) y verificación humana del código asistido por OpenCode.

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
│   │   ├── SPEC_U6.md                       # Especificación del plan y reglas operativas
│   │   ├── backup_foodstore.ps1             # Script de respaldo automatizado (PowerShell)
│   │   ├── backup_foodstore.sh              # Script de respaldo automatizado (Bash)
│   │   ├── health_check.sql                 # Consultas de monitoreo de 4 dimensiones
│   │   ├── maintenance.sql                  # Mantenimiento justificado no bloqueante
│   │   ├── restore_test.ps1                 # Automatización del simulacro de recuperación
│   │   ├── restore_test.sh                  # Simulacro de recuperación (Bash)
│   │   ├── informe_u6.md                    # Informe post-incidente y RTO/RPO
│   │   ├── informe_u6.pdf                   # Informe ejecutivo en formato PDF (1 página)
│   │   ├── TPUnidad_6_Mantenimiento_...md   # Consigna del Trabajo Práctico Unidad 6
│   │   └── TPUnidad_6_Mantenimiento_...pdf  # Consigna original en PDF
│   └── tpi_parcial1/                        # Consolidación del primer parcial
│
├── BITACORA.md                              # Bitácora obligatoria de interacción y lectura crítica con IA
└── README.md                                # Documentación general del repositorio
```

---

## Bases de datos del proyecto

1. **`bd2_tpi_parcial1`:** Base consolidada del primer parcial (Unidades 1 a 3).
2. **`bd2_tp6`:** Base descartable utilizada para las pruebas de FNBC y desnormalización de la Unidad 4.
3. **`bd2_tp7`:** Base de desarrollo dedicada para la Unidad 5 (Administración y Seguridad).
4. **`foodstore`:** Base principal de producción para el ciclo de vida, respaldos y monitoreo del TP8.
5. **`foodstore_restore_test`:** Base descartable y aislada para los simulacros de recuperación y medición de RTO/RPO del TP8.

---

## Procedimiento Integral para Recrear la Base de Datos (`foodstore`)

Para garantizar que el entorno incorpore **la totalidad de las funcionalidades y esquemas acumulados desde la Unidad 1 hasta la Unidad 6 (TP8)**, la base de datos `foodstore` puede reconstruirse de forma íntegra e idéntica mediante dos alternativas:

### Alternativa A: Ejecución Automatizada (Recomendada)

Se dispone de scripts ejecutores que aplican automáticamente la secuencia completa de DDL, datos, optimizaciones, seguridad y mantenimiento:

```powershell
# En PowerShell (Windows)
.\recrear_base_foodstore.ps1 -Database foodstore

# O en Bash (Linux / macOS)
./recrear_base_foodstore.sh foodstore
```

---

### Alternativa B: Recreación Manual Paso a Paso

Si se prefiere ejecutar la reconstrucción instrucción por instrucción con la herramienta nativa `psql`:

#### Paso 1: Creación limpia del contenedor de base de datos
```powershell
# Desconectar sesiones abiertas y recrear la base de datos
psql -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'foodstore' AND pid <> pg_backend_pid();"
psql -U postgres -c "DROP DATABASE IF EXISTS foodstore;"
psql -U postgres -c "CREATE DATABASE foodstore;"
```

#### Paso 2: Esquema DDL base y dominios (Unidades 1 y 2)
Crea los tipos enumerados (`forma_pago`), tablas maestras (`categoria`, `cliente`, `producto`, `pedido`, `detalle_pedido`), claves primarias con identidad y restricciones de integridad:
```powershell
psql -v ON_ERROR_STOP=1 -U postgres -d foodstore -f db/schema.sql
```

#### Paso 3: Índices de optimización relacional (Unidad 3)
Aplica índices B-Tree estándar y parciales sobre claves foráneas y fechas de transacciones:
```powershell
psql -v ON_ERROR_STOP=1 -U postgres -d foodstore -f db/indices.sql
```

#### Paso 4: Poblado masivo de datos iniciales (Unidad 3)
Carga el volumen canónico de clientes, categorías, catálogo de productos y pedidos históricos:
```powershell
psql -v ON_ERROR_STOP=1 -U postgres -d foodstore -f db/generador_datos_tp3_carga.sql
```

#### Paso 5: Vistas del dominio de negocio (Unidad 3)
Despliega vistas estándar del catálogo y consultas agregadas de pedidos recientes:
```powershell
psql -v ON_ERROR_STOP=1 -U postgres -d foodstore -f db/views.sql
```

#### Paso 6: Descomposición en Forma Normal de Boyce-Codd - FNBC (Unidad 4 / TP6)
Aplica la partición sin pérdida preservando dependencias funcionales para `responsable_deposito` y `control_lote`:
```powershell
psql -v ON_ERROR_STOP=1 -U postgres -d foodstore -f db/tp_fnbc_control_lote.sql
```

#### Paso 7: Desnormalización controlada y vista materializada (Unidad 4 / TP6)
Crea la vista materializada analítica `mv_ventas_categoria_dia` y la tabla de auditoría de refrescos `log_actualizacion_mv`:
```powershell
psql -v ON_ERROR_STOP=1 -U postgres -d foodstore -f db/tp_desnormalizacion_top_categorias.sql
```

#### Paso 8: Prerrequisitos de seguridad y tabla de identidades (Unidad 5 / TP7)
Habilita la extensión criptográfica `pgcrypto`, define la tabla `usuario` con almacenamiento seguro de contraseñas mediante hashing Blowfish (`crypt` / `gen_salt('bf', 8)`), la vista `v_usuarios_publico` y el procedimiento `sp_crear_pedido`:
```powershell
psql -v ON_ERROR_STOP=1 -U postgres -d foodstore -f db/tp7_clase1_prerrequisitos.sql
```

#### Paso 9: Funciones seguras de autenticación y soporte (Unidad 5 / TP7)
Implementa `fn_autenticar` (protegida contra inyección SQL con `SECURITY INVOKER`) y `fn_resetear_password` (protegida contra secuestro de esquemas CVE-2018-1058 con `SECURITY DEFINER` y `SET search_path = public, pg_temp`):
```powershell
psql -v ON_ERROR_STOP=1 -U postgres -d foodstore -f db/tp7_clase2_seguridad.sql
```

#### Paso 10: Despliegue de roles, mínimo privilegio y RLS (Unidad 5 / TP7)
Define los roles `rol_app_lectura`, `rol_app_escritura`, `rol_soporte`, `rol_reportes`, `app_web` y `admin_datos` (`NOSUPERUSER`), permisos restringidos a nivel de columna y políticas Row-Level Security (`aislacion_clientes_pedido`):
```powershell
psql -v ON_ERROR_STOP=1 -U postgres -d foodstore -f sql/roles.sql
```

#### Paso 11: Dataset sintético determinista anonimizado (Unidad 5 / TP7)
Construye la entidad `usuario_anon` preservando cardinalidad exacta y distribuciones para consumo seguro por IA y analítica bajo la Ley 25.326:
```powershell
psql -v ON_ERROR_STOP=1 -U postgres -d foodstore -f sql/usuario_anon.sql
```

---

## Procedimiento de Reproducción y Verificación del TP8 (Unidad 6)

Una vez disponible la base `foodstore`, se ejecutan las cuatro tareas que componen el ciclo de mantenimiento y continuidad operativa:

### 1. Respaldo Lógico Custom Automatizado
Genera un archivo `.dump` binario comprimido con timestamping estricto y registro de actividad en bitácora de logs (sin contraseñas expuestas):
```powershell
# En PowerShell
.\docs\tp8\backup_foodstore.ps1 -Database foodstore

# O en Bash
./docs/tp8/backup_foodstore.sh foodstore
```
*Evidencia:* Se genera `db/backups/foodstore_YYYYMMDD_HHMMSS.dump` y su bitácora en `docs/tp8/logs/backup_foodstore_YYYYMMDD_HHMMSS.log`.

### 2. Monitoreo Preventivo de Salud del Cluster
Ejecuta los cuatro controles de diagnóstico (espacio de almacenamiento, actividad y ratio de rollback, estado de tuplas muertas y consultas bloqueadas):
```powershell
psql -U postgres -d foodstore -f docs/tp8/health_check.sql
```

### 3. Mantenimiento Preventivo Seguro (No Bloqueante)
Verifica la proximidad al umbral de autovacuum y aplica `VACUUM (VERBOSE, ANALYZE)` sobre tablas transaccionales:
```powershell
psql -U postgres -d foodstore -f docs/tp8/maintenance.sql
```

### 4. Simulacro de Desastre Contra Reloj (Medición de RTO y RPO)
Ejecuta la restauración automatizada sobre un entorno estrictamente aislado (`foodstore_restore_test`), valida las restricciones lógicas y mide los indicadores de continuidad:
```powershell
# En PowerShell
.\docs\tp8\restore_test.ps1 -RestoreDatabase foodstore_restore_test -SourceDatabase foodstore

# O en Bash
./docs/tp8/restore_test.sh foodstore_restore_test foodstore
```
*Evidencia:* Salida con cronómetro de alta precisión (RTO medido en segundos) y antigüedad del respaldo (RPO observado), validando que las tablas conservan cardinalidad exacta y que no existen productos ni detalles inválidos (`0`).

---

## Decisiones Técnicas y de Seguridad Consolidadas

### Arquitectura de Seguridad (TP7 — Unidad 5)
* **Principio de Mínimo Privilegio (NIST SP 800-53):** Ningún rol de aplicación posee facultades administrativas ni permisos destructivos (`REVOKE DELETE, TRUNCATE`).
* **Separación de Tareas del DBA:** `admin_datos` posee `CREATEDB` y `CREATEROLE` pero es estrictamente `NOSUPERUSER`.
* **Proyección Restringida por Columna:** `rol_soporte` sólo accede a `(id, nombre, apellido, mail, rol)`, resguardando celular y contraseñas.
* **Row-Level Security (RLS):** Filtrado transparente a nivel de fila por cliente mediante `aislacion_clientes_pedido`.
* **Mitigación CVE-2018-1058:** Funciones `SECURITY DEFINER` con fijación explícita de `SET search_path = public, pg_temp`.
* **Protección de Datos Personales (Ley 25.326):** Anonimización determinista sintética en `usuario_anon` para procesamiento por IA.

### Continuidad Operativa y Resiliencia (TP8 — Unidad 6)
* **Aislamiento de Entornos:** La base productiva `foodstore` es intocable durante los simulacros; la recuperación se realiza exclusivamente sobre `foodstore_restore_test`.
* **Uso Exclusivo de Formato Custom (`-Fc`):** Permite compresión zlib, verificación de cabeceras, reordenamiento de objetos y restauración multi-hilo (`-j`).
* **Veto Absoluto a `VACUUM FULL`:** Se prohibe en mantenimientos rutinarios debido al bloqueo exclusivo (`AccessExclusiveLock`) y caída del servicio que genera, adoptando en su lugar `VACUUM (VERBOSE, ANALYZE)` no bloqueante (`ShareUpdateExclusiveLock`).
* **Gestión Segura de Secretos:** Los scripts no exponen contraseñas; operan mediante variables del entorno seguro (`PGPASSWORD` efímero) o `.pgpass` (`0600`).

---

## Uso de Inteligencia Artificial y Bitácora Obligatoria

En cumplimiento con los requerimientos pedagógicos de la materia, todas las interacciones, propuestas y correcciones críticas aplicadas con herramientas de IA (OpenCode / Asistente) se encuentran documentadas en:

```text
BITACORA.md
```

El documento incluye el registro de prompts y validaciones humanas tanto para la **Unidad 5 (10 registros)** como para la **Unidad 6 (4 registros)**, destacando el análisis crítico ante desvíos como la sugerencia de contraseñas hardcodeadas o el intento de ejecutar `VACUUM FULL`.

---

## Historial de Ramas y Archivo de Documentación

* **`main`:** Rama troncal de integración de entregas evaluadas.
* **`tpi-parcial1`:** Primera entrega integradora (Unidades 1 a 3).
* **`tp6-fnbc-desnormalizacion`:** Unidad 4 (FNBC y desnormalización). Su README histórico se preserva en [`docs/tp6/README.md`](file:///d:/formateo%20win%2011/Estudios%20(Nuevo)/utn%20tec.%20programación/3°%20Semestre/Base%20de%20Datos%202/Food-Store/docs/tp6/README.md).
* **`tp7-administracion-seguridad`:** Unidad 5 (Administración y Seguridad). Su README histórico se preserva en [`docs/tp7/README.md`](file:///d:/formateo%20win%2011/Estudios%20(Nuevo)/utn%20tec.%20programación/3°%20Semestre/Base%20de%20Datos%202/Food-Store/docs/tp7/README.md).
* **`tp8-mantenimiento`:** Unidad 6 (Mantenimiento, Respaldo y Recuperación — Estado Actual).
