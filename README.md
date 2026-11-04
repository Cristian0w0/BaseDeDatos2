# Base de Datos 2 — Food Store

Repositorio del proyecto integrador **«Food Store»** desarrollado para la asignatura **Base de Datos II** (Tecnicatura Universitaria en Programación — UTN).

El repositorio documenta el avance progresivo de todas las unidades de la materia:
1. **TPI Primer Parcial (Unidades 1, 2 y 3):** Integridad relacional, transacciones ACID, concurrencia, optimización con índices y procedimientos almacenados.
2. **TP6 (Unidad 4):** Forma Normal de Boyce-Codd (FNBC) y Desnormalización Controlada mediante vistas materializadas.
3. **TP7 (Unidad 5):** Administración y Seguridad: roles bajo mínimo privilegio, auditoría nativa, incidentes y Ley 25.326.
4. **TP8 (Unidad 6):** Mantenimiento, Respaldo y Recuperación ante desastres (Disaster Recovery).
5. **TP9 (Unidad 7):** Persistencia NoSQL y modelado documental con MongoDB vs. PostgreSQL.
6. **TP10 / TP8 Cátedra (Unidad 8):** Bases de Datos para Dispositivos Móviles e Integración: arquitectura *Offline-First* con SQLite, sincronización y semáforo.

---

## Estado Actual del Proyecto: Unidad 8 (TP10)

El estado actual del repositorio implementa el **Trabajo Práctico N.º 8 (TP10) — Bases de Datos Móviles e Integración**, consolidando la capa de datos de Food Store en una feria gastronómica sin señal:

- **Rama activa de trabajo:** `tp10-moviles-integracion`
- **Regla de Oro:** *"El móvil propone, el servidor dispone"*. La tablet solo consulta y arma borradores; PostgreSQL es la única fuente de verdad sobre stock, precios y ventas.
- **Motores integrados:**
  - **PostgreSQL 16+ (Servidor Central):** Fuente de verdad transaccional ACID (`foodstore`).
  - **MongoDB 9+ (Capa Documental):** Vista agregada para consultas analíticas rápidas (`foodstore_nosql`).
  - **SQLite 3.50+ (Dispositivo Móvil):** Libreta desconectada en modo `STRICT` (`movil/foodstore_movil.db`).
- **Herramientas de IA y Gobernanza:** Kiro (especificación EARS) y OpenCode / Antigravity con bitácora crítica documentada.

---

## Estructura del Repositorio para la Entrega

```text
food-store/
├── README.md                                # Guía general del proyecto y orden de ejecución
├── movil/                                   # Capa de datos del dispositivo móvil (Unidad 8)
│   ├── schema_sqlite.sql                    # Consigna 1.b: Esquema SQLite STRICT y claves foráneas
│   ├── pruebas_sqlite.sql                   # Consigna 1.c: Transacciones, Caso C1 y Caso C7
│   ├── snapshot_servidor.sql                # Consigna 2.a: Tabla receptora y carga en SQLite
│   ├── postgresql_snapshot.sql              # Consigna 2.a: Vista oficial v_snapshot_movil en PostgreSQL
│   ├── servidor_snapshot.csv                # Consigna 2.a: Archivo CSV de intercambio de instantánea
│   ├── semaforo.sql                         # Consigna 2.b: Consulta SQL de resolución del semáforo
│   ├── simulador_casos.py                   # Consigna 2.c: Suite de simulación automatizada (C2 a C6)
│   ├── ejecutar_pruebas.py                  # Runner de validación de esquema y pruebas unitarias
│   └── foodstore_movil.db                   # Archivo físico binario de la base SQLite
│
├── docs/                                    # Documentación consolidada de la materia
│   ├── informe.pdf                          # Informe final del TP (3 páginas, Consignas 1.a, 2.c, 3.a-c)
│   ├── informe.html                         # Maquetado HTML de alta calidad para exportación
│   ├── bitacora_ia.md                       # Consigna 4.b: Bitácora de IA (3 interacciones con fundamento)
│   ├── DUIA.md                              # Consigna 4.b: Declaración de Uso de IA de la cátedra
│   ├── kiro/                                # Consigna 4.a: Especificación formal en Kiro
│   │   ├── requirements.md                  # Requisitos funcionales en notación formal EARS
│   │   ├── design.md                        # Diseño técnico y arquitectura de sincronización
│   │   └── tasks.md                         # Desglose de tareas de implementación
│   │
│   ├── tp10/                                # Archivos fuente y consignas oficiales de Unidad 8
│   │   ├── BDII_U8_TP8_Food_Store (1).md    # Enunciado oficial del TP8 de la cátedra
│   │   ├── BDII_U8_Material_Teorico...md    # Apunte conceptual de 11 paradas de la cátedra
│   │   ├── informe_tp10.md                  # Borrador completo del informe técnico
│   │   ├── informe_tp10.pdf                 # Copia espejo del informe oficial
│   │   └── kiro/                            # Copia espejo de especificaciones Kiro
│   │
│   ├── tp9/                                 # Histórico TP9: NoSQL (MongoDB vs. PostgreSQL)
│   ├── tp8/                                 # Histórico TP8: Mantenimiento y Recuperación
│   ├── tp7/                                 # Histórico TP7: Seguridad y Auditoría
│   └── tp6/                                 # Histórico TP6: FNBC y Desnormalización
│
├── db/                                      # Scripts SQL históricos de la base PostgreSQL
└── sql/                                     # Entregables canónicos de unidades previas
```

---

## Procedimiento de Ejecución Paso a Paso desde Cero (Consigna 4.c)

Para verificar y reproducir la capa móvil y la sincronización de forma 100% automatizada:

### 1. Inicialización y Pruebas Unitarias de SQLite (Consigna 1)
Crea la base de datos `movil/foodstore_movil.db` desde cero, aplica `schema_sqlite.sql`, verifica claves foráneas activas, transacciones atómicas (`COMMIT` / `ROLLBACK`), consulta offline (Caso C1) y rechazo de datos inválidos (Caso C7):
```powershell
python movil/ejecutar_pruebas.py
```
*Salida esperada:*
```text
[*] PRAGMA foreign_keys = 1 (Activado)
[OK] C7.a Rechazado correctamente por restricción CHECK: cantidad > 0
[OK] C7.b Rechazado correctamente por restricción FOREIGN KEY
[+] Todas las pruebas de la Consigna 1 fueron completadas con éxito.
```

### 2. Generación e Importación de la Instantánea (Consigna 2.a)
En el servidor PostgreSQL, se publica la vista oficial con centavos y lápidas:
```powershell
psql -U postgres -d foodstore -f movil/postgresql_snapshot.sql
```
La vista se exporta a `movil/servidor_snapshot.csv` y se importa en SQLite mediante `movil/snapshot_servidor.sql`.

### 3. Simulación Automatizada del Semáforo y Casos C2 a C6 (Consigna 2.b y 2.c)
Ejecuta la suite integral de simulación que verifica la resolución de conflictos tarifarios, quiebres de stock, bajas lógicas e idempotencia:
```powershell
python movil/simulador_casos.py
```
*Salida esperada:*
```text
CASO C5 -> Estado: SIMULADO_APROBADO
CASO C2 (Envío 1) -> Estado: CONFLICTO (precio subió en servidor)
CASO C2 (Envío 2) -> Estado: SIMULADO_APROBADO (cliente acepta nuevo precio)
CASO C3 -> Estado: RECHAZADO (stock insuficiente en servidor)
CASO C4 -> Estado: RECHAZADO (lápida activa; oculto en catálogo local)
CASO C6 -> [OK] Reintento rechazado en SQLite por Clave Primaria (Idempotencia)
[+] TODOS LOS CASOS C2 A C6 VERIFICADOS SATISFACTORIAMENTE (0 ERRORES)
```

---

## Guía para el Ensayo de Defensa (10 Minutos)

Para la defensa individual ante la cátedra en la Semana 13:

1. **El Mapa de la Capa de Datos (3 minutos):**  
   Explicar la arquitectura de 3 motores:
   * **PostgreSQL:** Única fuente de verdad. Decide stock, precios y ventas formales (`sp_crear_pedido`).
   * **MongoDB:** Motor documental desnormalizado para consultas analíticas rápidas de pedidos sin bloquear el OLTP.
   * **SQLite:** Libreta embebida para la tablet del food truck. Solo prepara borradores y no tiene autoridad decisoria.
2. **Demostración en Vivo (4 minutos):**  
   * Ejecutar `python movil/simulador_casos.py`.
   * Mostrar en vivo la resolución del **Caso C2** (el paso de `CONFLICTO` a `SIMULADO_APROBADO` tras aceptar el cliente) o el **Caso C4** (demostrando cómo la lápida oculta el ítem de `v_catalogo_disponible` pero conserva la fila en `producto_cache` para no quebrar claves foráneas).
3. **Decisión de Diseño y Hallazgo de IA Descartado (3 minutos):**  
   * Defender el **Hallazgo H1** de la bitácora: Justificar por qué se descartó la propuesta de la IA de hacer `UNIQUE (id_local)` en `cola_sync`. Explicar que un borrador necesita reintentarse tras resolver un conflicto tarifario, y que la solución técnica correcta es el índice condicional único `ux_cola_una_pendiente` (`WHERE estado = 'PENDIENTE'`).
   * Explicar por qué la protección real contra duplicaciones en producción debe residir en PostgreSQL mediante la tabla central `solicitud_movil` con `ON CONFLICT DO NOTHING`.
