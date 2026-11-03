# Base de Datos 2 — Food Store

Repositorio del proyecto integrador **«Food Store»** desarrollado para la asignatura **Base de Datos II** (Tecnicatura Universitaria en Programación — UTN).

El repositorio reúne y documenta el avance progresivo de los trabajos prácticos de la materia:
1. **Primera entrega parcial del Trabajo Práctico Integrador (TPI):** Consolidación de las Unidades 1, 2 y 3 (integridad, transacciones, optimización, índices, vistas y procedimientos).
2. **TP6 (Unidad 4):** Forma Normal de Boyce-Codd (FNBC) y Desnormalización Controlada mediante vistas materializadas.
3. **TP7 (Unidad 5):** Administración y Seguridad de Food Store: roles, auditoría, incidentes y protección de datos personales.

---

## Estado del proyecto

El estado actual del repositorio incorpora el **TP7 — Administración y Seguridad de Food Store**, integrando los contenidos teórico-prácticos de la **Clase 1** (identidades, mínimo privilegio, auditoría) y de la **Clase 2** (amenazas relacionales, inyección SQL, escalamiento, fuga de datos y protección de datos personales bajo la Ley 25.326).

- **Rama activa de trabajo:** `tp7-administracion-seguridad`
- **Motor utilizado:** PostgreSQL 17 (17.11)
- **Lenguaje de procedimientos:** PL/pgSQL
- **Base de datos de desarrollo del TP7:** `bd2_tp7`

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

Se organiza en cinco partes técnicas:
* **Parte A — Roles y Permisos de Mínimo Privilegio:** Especificación previa Kiro (`requirements.md` y `design.md`), script `roles.sql`, permisos por columna sobre `usuario`, políticas de Row-Level Security (RLS) sobre `pedido`, permisos por defecto (`ALTER DEFAULT PRIVILEGES`) y verificación formal en el catálogo del motor (`\du`, `pg_roles`, `role_table_grants`).
* **Parte B — Activación y Prueba de la Auditoría:** Activación de parámetros nativos en el servidor (`log_connections = on`, `log_disconnections = on`, `log_statement = 'mod'`), ejecución de secuencia de prueba de 4 operaciones, captura de log y análisis comparativo de alcance frente a `pgaudit`.
* **Parte C — Laboratorio: Simulacro de Incidente de Acceso Indebido:** Reproducción controlada de ataque de fuerza bruta contra `fn_autenticar`, exfiltración masiva de usuarios e intentos de escalamiento vertical a `admin_datos` y `SUPERUSER`. Verificación de contención por el motor, log anonimizado, contraste de la reconstrucción de la IA con lectura crítica humana y definición del plan de contención.
* **Parte D — Protección de Datos Personales (Ley 25.326) y Equivalencia:** Creación del dataset sintético determinista `usuario_anon` para consumo por IA, ejecución de consultas analíticas agregadas cruzadas demostrando equivalencia exacta de cardinalidad y fundamentación de la frontera de privacidad.
* **Parte E — Cierre y Consolidación de Bitácora:** Registro en `BITACORA.md` de prompts, respuestas de IA y validaciones/correcciones humanas aplicadas, destacando el caso de error más significativo de la IA.

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
│   ├── tp7_clase1_prerrequisitos.sql        # TP7: Extensión pgcrypto, usuario, vistas y sp_crear_pedido
│   ├── tp7_clase1_auditoria_servidor.sql    # TP7: Comandos de auditoría de servidor
│   ├── tp7_clase2_seguridad.sql             # TP7: Funciones fn_autenticar, fn_resetear_password y tests
│   ├── roles.sql                            # TP7: Implementación de roles y permisos
│   ├── auditoria_test.sql                   # TP7: Secuencia de prueba de auditoría
│   ├── simulacro_incidente.sql              # TP7: Script de simulación de incidente
│   ├── usuario_anon.sql                     # TP7: Dataset anonimizado y consultas
│   └── backups/                             # Respaldos .dump (excluidos en .gitignore)
│
├── sql/                                     # Entregables canónicos exigidos por consigna TP7
│   ├── roles.sql                            # Parte A: Roles, jerarquías, RLS y mínimo privilegio
│   ├── auditoria_test.sql                   # Parte B: Prueba de auditoría de 4 operaciones
│   ├── simulacro_incidente.sql              # Parte C: Reproducción de incidente de acceso indebido
│   └── usuario_anon.sql                     # Parte D: Creación de usuario_anon y agregaciones
│
├── docs/                                    # Informes, especificaciones y evidencias
│   ├── tp1/ a tp4/                          # Informes y modelos ER de entregas iniciales
│   ├── tp5/                                 # TP5: Informe de mediciones, DUIA y specs históricas
│   ├── tp6/                                 # TP6: README histórico, informe FNBC y evidencias EXPLAIN
│   │   ├── README.md                        # README histórico del estado del proyecto al cierre de TP6
│   │   ├── informe_fnbc.md                  # Informe técnico de FNBC y desnormalización
│   │   ├── informe_fnbc.pdf                 # Informe en PDF
│   │   └── evidencias/                      # Capturas de planes de ejecución
│   ├── tp7/                                 # TP7: Entregables formales de Unidad 5
│   │   ├── kiro_roles_spec/
│   │   │   ├── requirements.md              # Requerimientos y justificación de roles (Kiro)
│   │   │   └── design.md                    # Diseño técnico, diagrama Mermaid y matriz granular
│   │   ├── verificacion_roles.md            # Salidas de catálogo (\du, grants, columnas)
│   │   ├── log_auditoria_prueba.txt         # Captura de log ante auditoria_test.sql
│   │   ├── informe_auditoria.md             # Informe técnico de auditoría nativa vs pgaudit
│   │   ├── log_simulacro_anonimizado.txt    # Log anonimizado de la simulación de ataque
│   │   ├── informe_incidente.md             # Reconstrucción IA, lectura crítica y plan de contención
│   │   ├── verificacion_equivalencia.md     # Resultados lado a lado usuario vs usuario_anon
│   │   ├── BD2_U5_Clase1_...md              # Apunte teórico Clase 1
│   │   ├── BD2_U5_Clase2_...md              # Apunte teórico Clase 2
│   │   ├── BD2_U5_Clase2_...complemento.md  # Apunte complementario con diagrama de tokenización
│   │   └── Trabajo Practico Unidad 5.md     # Consigna completa del TP7
│   └── tpi_parcial1/                        # Consolidación del primer parcial
│
├── BITACORA.md                              # Bitácora obligatoria de interacción y lectura crítica con IA
└── README.md                                # Documentación general del repositorio
```

---

## Bases de datos del proyecto

1. **`bd2_tpi_parcial1`:** Base consolidada del primer parcial (Unidades 1 a 3).
2. **`bd2_tp6`:** Base descartable utilizada para las pruebas de FNBC y desnormalización de la Unidad 4.
3. **`bd2_tp7`:** Base de desarrollo dedicada para la Unidad 5 (Administración y Seguridad). Se crea a partir de una copia limpia de Food Store con datos poblados para ejecutar los permisos, funciones de seguridad y simulacros sin alterar las bases históricas.

---

## Procedimiento de Reproducción y Verificación del TP7

Para reproducir de forma controlada y reproducible los artefactos del TP7 sobre la base `bd2_tp7`:

### Paso 1: Creación y Preparación de la Base de Trabajo
```powershell
# Crear la base de desarrollo
psql -U postgres -c "CREATE DATABASE bd2_tp7;"

# Aplicar esquema base, datos y vistas de Food Store
psql -v ON_ERROR_STOP=1 -U postgres -d bd2_tp7 -f db/schema.sql
psql -v ON_ERROR_STOP=1 -U postgres -d bd2_tp7 -f db/generador_datos_tp3_carga.sql
psql -v ON_ERROR_STOP=1 -U postgres -d bd2_tp7 -f db/views.sql

# Aplicar prerrequisitos de la Unidad 5 (extensión pgcrypto, tabla usuario, vistas y sp_crear_pedido)
psql -v ON_ERROR_STOP=1 -U postgres -d bd2_tp7 -f db/tp7_clase1_prerrequisitos.sql
```

### Paso 2: Despliegue de Roles y Permisos (Parte A)
```powershell
# Aplicar el esquema de roles, jerarquías y RLS
psql -v ON_ERROR_STOP=1 -U postgres -d bd2_tp7 -f sql/roles.sql
```
*Verificación:* Ejecutar las consultas de catálogo documentadas en `docs/tp7/verificacion_roles.md` para comprobar los atributos de `app_web`, `admin_datos` (`NOSUPERUSER`), las membresías y los permisos restringidos de columna sobre `usuario`.

### Paso 3: Activación y Prueba de Auditoría Nativa (Parte B)
```powershell
# Activar parámetros de auditoría en el servidor (requiere privilegios de superusuario)
psql -v ON_ERROR_STOP=1 -U postgres -d bd2_tp7 -f db/tp7_clase1_auditoria_servidor.sql

# Ejecutar la secuencia de 4 operaciones de prueba
psql -v ON_ERROR_STOP=1 -U postgres -d bd2_tp7 -f sql/auditoria_test.sql
```
*Verificación:* Comparar el log del servidor generado en el directorio de logs de PostgreSQL contra la captura de referencia en `docs/tp7/log_auditoria_prueba.txt`.

### Paso 4: Despliegue de Funciones de Seguridad y Simulacro de Incidente (Parte C)
```powershell
# Crear funciones fn_autenticar y fn_resetear_password
psql -v ON_ERROR_STOP=1 -U postgres -d bd2_tp7 -f db/tp7_clase2_seguridad.sql

# Ejecutar el simulacro de incidente
psql -v ON_ERROR_STOP=1 -U postgres -d bd2_tp7 -f sql/simulacro_incidente.sql
```
*Verificación:* Comprobar que los intentos de escalamiento vertical son bloqueados por el motor con `insufficient_privilege` y `must be superuser`, corroborando la contención analizada en `docs/tp7/informe_incidente.md`.

### Paso 5: Generación de Dataset Anonimizado y Verificación de Equivalencia (Parte D)
```powershell
# Crear usuario_anon y ejecutar las consultas de agregación analítica
psql -v ON_ERROR_STOP=1 -U postgres -d bd2_tp7 -f sql/usuario_anon.sql
```
*Verificación:* Constatar que las tablas de resultados devueltas por ambas consultas coinciden exactamente en conteos totales y cardinalidad (`COUNT(DISTINCT mail)`), tal como se evidencia en `docs/tp7/verificacion_equivalencia.md`.

---

## Decisiones Técnicas y de Seguridad del TP7

* **Principio de Mínimo Privilegio (NIST SP 800-53 / Saltzer & Schroeder):** Ningún rol de aplicación posee facultades administrativas. `rol_app_escritura` y `app_web` tienen explícitamente revocado `DELETE` y `TRUNCATE` para asegurar el borrado lógico.
* **Separación de Tareas:** `admin_datos` posee `CREATEDB` y `CREATEROLE` pero es explícitamente `NOSUPERUSER`, garantizando que sus acciones queden sujetas a las comprobaciones del motor y auditoría.
* **Proyección Restringida por Columna y Vistas:** Para proteger la confidencialidad de datos personales (Ley 25.326), `rol_soporte` solo tiene concedidas las columnas `(id, nombre, apellido, mail, rol)` de `usuario`, impidiendo que consultas a la tabla base expongan `contrasena` o `celular`.
* **Row-Level Security (RLS):** Se configuró la directiva `aislacion_clientes_pedido` sobre la tabla `pedido`, forzando al motor a aislar las compras por cliente (`app.usuario_actual`) de forma nativa e independiente del código de backend.
* **Mitigación de Inyección de SQL:** La función `fn_autenticar` opera con parámetros tipados en PL/pgSQL y `SECURITY INVOKER`, neutralizando ataques de concatenación dinámica como `' OR '1'='1' --`.
* **Mitigación de Secuestro de Esquemas (CVE-2018-1058):** La función `fn_resetear_password` opera con `SECURITY DEFINER` y fija de forma estricta `SET search_path = public, pg_temp`, revocando la ejecución a `PUBLIC` y concediéndosela únicamente a `rol_soporte`.
* **Anonimización Determinista:** La tabla `usuario_anon` destruye irreversiblemente el vínculo con personas reales mediante patrones sintéticos (`'Usuario ' || id`, `'usuario' || id || '@ejemplo.test'`), neutraliza el hash de contraseñas y fija celulares en `NULL`, preservando las cardinalidades y distribuciones para consultas de IA y métricas analíticas.

---

## Uso de Inteligencia Artificial y Bitácora Obligatoria

En cumplimiento con los requerimientos pedagógicos de la cátedra, todas las interacciones relevantes con asistentes de IA durante la Unidad 5 se encuentran documentadas en el archivo:

```text
BITACORA.md
```

El documento implementa una tabla de tres columnas (*Prompt enviado*, *Respuesta recibida*, *Validación o corrección humana aplicada*) con **10 registros trazables** que cubren desde el punto de partida (Clases 1 y 2) hasta las Partes A, B, C y D. 

Se destaca especialmente el **análisis crítico humano** en casos donde la IA propuso atajos inseguros o deducciones erróneas:
1. **Propuesta de `GRANT ALL ON ALL TABLES`:** Rechazada por vulnerar el principio de mínimo privilegio.
2. **Propuesta de concatenación en SQL dinámico:** Corregida por habilitar inyección de SQL.
3. **Omisión de `search_path` en `SECURITY DEFINER`:** Corregida para prevenir escalamiento por secuestro de esquemas (CVE-2018-1058).
4. **Falsa inferencia de compromiso total del cluster en el simulacro:** Detectada al contrastar el log del servidor y verificar que los intentos de escalamiento fueron bloqueados por PostgreSQL.

---

## Historial de Ramas en Git

* **`tpi-parcial1`:** Entrega integrada del primer parcial (Unidades 1, 2 y 3).
* **`tp6-fnbc-desnormalizacion`:** Desarrollo de la Unidad 4 (FNBC y desnormalización con vistas materializadas).
* **`tp7-administracion-seguridad`:** Desarrollo integral de la Unidad 5 (Administración y Seguridad).
