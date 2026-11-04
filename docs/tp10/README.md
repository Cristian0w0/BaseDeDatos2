# Trabajo Práctico N.º 8 (TP10) — Bases de Datos Móviles e Integración
## Food Store en la Feria: La Base de la Tablet y el Cierre de la Capa de Datos

**Asignatura:** Base de Datos II — Tecnicatura Universitaria en Programación (UTN)  
**Estudiante:** Cristian Rodriguez (`Cloverfield`)  
**Rama:** `tp10-moviles-integracion`  
**Ciclo Lectivo:** 2026 · Cátedra de Base de Datos II  

---

### Descripción del Trabajo Práctico
Implementación integral de la capa de datos para el Food Truck de Food Store operando en una feria gastronómica sin conectividad garantizada (*Offline-First*).
Se aplica la **Regla de Oro:** *"El móvil propone, el servidor dispone"*. La tablet gestiona un catálogo local y genera borradores en una base de datos embebida (SQLite 3.50+), mientras que PostgreSQL 16+ se preserva como la única fuente de verdad (*Single Source of Truth*) para precios, inventario y confirmación legal de ventas.

---

### Estructura de Entregables de la Unidad 8

```text
food-store/
├── README.md                                # Documentación general y orden de ejecución
├── movil/
│   ├── schema_sqlite.sql                    # Consigna 1.b: Esquema SQLite STRICT y claves foráneas
│   ├── pruebas_sqlite.sql                   # Consigna 1.c: Transacciones (COMMIT/ROLLBACK), C1 y C7
│   ├── snapshot_servidor.sql                # Consigna 2.a: Tabla receptora y carga en SQLite
│   ├── postgresql_snapshot.sql              # Consigna 2.a: Vista oficial v_snapshot_movil en PostgreSQL
│   ├── servidor_snapshot.csv                # Consigna 2.a: CSV de intercambio de instantánea
│   ├── semaforo.sql                         # Consigna 2.b: Lógica del semáforo en SQL puro (SQLite)
│   ├── simulador_casos.py                   # Consigna 2.c: Suite de simulación automatizada (C2 a C6)
│   ├── ejecutar_pruebas.py                  # Runner de validación del esquema y pruebas unitarias
│   └── foodstore_movil.db                   # Base de datos SQLite física generada
│
└── docs/
    ├── informe.pdf                          # Informe final oficial del TP (3 páginas A4)
    ├── informe.html                         # Maquetado HTML para exportación
    ├── bitacora_ia.md                       # Consigna 4.b: Bitácora de IA (3 interacciones con fundamento)
    ├── DUIA.md                              # Consigna 4.b: Declaración de Uso de IA de la cátedra
    ├── kiro/                                # Consigna 4.a: Especificación Kiro en notación EARS
    │   ├── requirements.md                  # Requisitos funcionales (REQ-01 a REQ-05)
    │   ├── design.md                        # Diseño técnico y arquitectura de sincronización
    │   └── tasks.md                         # Plan de tareas de implementación
    └── tp10/                                # Archivos fuente de la consigna y copias espejo
```

---

### Resumen de Consignas Realizadas (100 / 100 Puntos)

1. **Consigna 1 · La base de la tablet (30 puntos):**
   * **1.a Qué datos viajan:** Tabla comparativa y fundamentación basada en la Ley 25.326 y principio de mínimo privilegio.
   * **1.b Las tablas:** DDL `movil/schema_sqlite.sql` con modo `STRICT`, precios enteros en centavos, claves foráneas activas (`PRAGMA foreign_keys = ON;`), índice parcial condicional `ux_cola_una_pendiente` y vista `v_catalogo_disponible`.
   * **1.c Probarla:** Script `movil/pruebas_sqlite.sql` verificando atomicidad transaccional (`COMMIT` y `ROLLBACK`), consulta offline (Caso C1) y rechazo controlado de datos inválidos (Caso C7: cantidad 0 y FK inexistente).

2. **Consigna 2 · Sincronizar y resolver (35 puntos):**
   * **2.a La instantánea:** Vista `v_snapshot_movil` en PostgreSQL con cálculo de centavos y lápidas lógicas, exportación a `servidor_snapshot.csv` e importación en SQLite en `snapshot_servidor`.
   * **2.b El semáforo:** Consulta CTE en `movil/semaforo.sql` que actualiza `cola_sync` a `RECHAZADO` (Rojo), `CONFLICTO` (Amarillo) o `SIMULADO_APROBADO` (Verde), priorizando el rojo y respetando idempotencia.
   * **2.c Los casos (C2 a C6):** Simulación automatizada mediante `movil/simulador_casos.py` con 100% de verificaciones exitosas. Demostración de invariabilidad del stock y pedidos en PostgreSQL.

3. **Consigna 3 · Integrar y revisar (20 puntos):**
   * **3.a Mapa de la capa de datos:** Arquitectura y matriz técnica de los tres motores (PostgreSQL, MongoDB y SQLite) definiendo qué guarda cada uno y quién manda sobre cada dato.
   * **3.b Plan de mantenimiento:** Adición al plan de contingencia de la Unidad 6 (procedimiento de respaldo, impacto de restauración de backup viejo en las tablets y protocolo de revisión de solicitudes conflictivas).
   * **3.c Code review con IA:** Auditoría técnica de scripts de cursadas anteriores documentando 3 hallazgos profundos de 3 unidades distintas, con 2 descartados con fundamento y 1 aceptado.

4. **Consigna 4 · Kiro, bitácora y defensa (15 puntos):**
   * **4.a Spec en Kiro:** `requirements.md` (requisitos en notación EARS vinculados a casos de prueba), `design.md` y `tasks.md`.
   * **4.b Bitácora y DUIA:** 3 entradas de bitácora con análisis crítico de IA y Declaración de Uso de IA.
   * **4.c README y Ensayo de Defensa:** Guía de ejecución desde cero y pautas para la defensa oral de 10 minutos.

---

### Instrucciones de Ejecución

```powershell
# 1. Crear y verificar la base SQLite y pruebas unitarias (Consigna 1)
python movil/ejecutar_pruebas.py

# 2. Ejecutar la simulación completa del semáforo y casos C2 a C6 (Consigna 2)
python movil/simulador_casos.py
```
