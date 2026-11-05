# Bitácora Consolidada de Interacción con Asistentes de Inteligencia Artificial
## Trabajo Práctico Integrador — Segunda Entrega Parcial (Unidades 4 a 8)
### Asignatura: Base de Datos II · Tecnicatura Universitaria en Programación (UTN)

**Estudiante / Integrante:** Cristian Rodriguez (`Cloverfield`)  
**Carrera:** Tecnicatura Universitaria en Programación  
**Materia:** Base de Datos II · Ciclo Lectivo 2026  
**Entorno de Trabajo:** PostgreSQL 17.11 · MongoDB 9.0.4 · SQLite 3.50.4  

---

## 1. Principios Rectores y Protocolo de Uso de IA
En estricto cumplimiento del **Protocolo Obligatorio de Uso de IA sobre Datos** definido por la cátedra para el proyecto «Food Store»:
1. **Lectura y comprensión previa:** Ningún script DDL, bloque PL/pgSQL, consulta MongoDB o sentencia SQLite generada por IA fue ejecutada en los motores sin antes haber sido leída línea por línea, comprendida en su integridad semántica y evaluada frente al catálogo de PostgreSQL y el estándar SQL.
2. **Entornos estériles y transacciones reversibles:** Todo ensayo destructivo o migratorio se realizó sobre bases descartables de laboratorio (`bd2_tp6`, `foodstore_restore_test`) o dentro de transacciones reversibles (`BEGIN ... ROLLBACK`). La base de producción `foodstore` se mantuvo protegida en todo momento.
3. **Privacidad de datos personales (Ley 25.326):** Nunca se remitieron a modelos de lenguaje datos personales de clientes o usuarios (nombres reales, correos electrónicos personales, números telefónicos o contraseñas hasheadas). Todo intercambio analítico se canalizó a través de datasets sintéticos deterministas (`usuario_anon`) o trazas de auditoría despojadas de identificadores reales.
4. **Criterio de soberanía humana:** Las propuestas de la IA fueron tratadas exclusivamente como borradores hipotéticos. Las decisiones técnicas finales fueron tomadas por el estudiante a partir de evidencia experimental comprobada en el motor.

---

## 2. Registro Cronológico de Prompts, Respuestas y Decisiones Humanas (Unidades 4 a 8)

### Unidad 4 · Normalización Avanzada (FNBC) y Desnormalización Controlada

#### Registro 4.1 · Descomposición FNBC y Preservación de Dependencias
* **Herramienta / Agente:** Kiro / Antigravity
* **Prompt enviado a la IA:**  
  *"Analizá la relación `control_lote_almacen(lote_id, deposito_id, responsable_control_id)` bajo las dependencias $\{lote\_id, deposito\_id\} \rightarrow responsable\_control\_id$ y $responsable\_control\_id \rightarrow deposito\_id$. Proponé la descomposición en FNBC y evaluá si se preservan todas las dependencias funcionales."*
* **Respuesta relevante de la IA:**  
  La IA propuso descomponer en $R_1(responsable\_control\_id, deposito\_id)$ y $R_2(lote\_id, responsable\_control\_id)$, demostrando la pérdida cero mediante el Criterio de Heath. Sin embargo, afirmó que *'todas las dependencias funcionales originales quedan automáticamente preservadas por las claves foráneas de las nuevas tablas'*.
* **Comprobación en el motor / Análisis crítico:**  
  El equipo construyó un contraejemplo en PostgreSQL: si se inserta en $R_1$ a dos responsables para un mismo depósito `(r1, d1)` y `(r2, d1)`, y en $R_2$ se asigna al mismo lote a ambos responsables `(l1, r1)` y `(l1, r2)`, ambas tablas cumplen sus claves primarias y foráneas. No obstante, al reconstruir la relación en la vista `v_control_lote_almacen`, el mismo par `(l1, d1)` aparece asociado a dos responsables distintos, violando abiertamente la DF $\{lote\_id, deposito\_id\} \rightarrow responsable\_control\_id$.
* **Decisión técnica humana:**  
  **CORRECCIÓN Y SALVAGUARDA.** Se aceptó la descomposición en $R_1$ y $R_2$ para eliminar las anomalías destructivas de inserción y borrado, pero se refutó formalmente la afirmación de la IA en el informe técnico: se explicitó que $\{lote\_id, deposito\_id\} \rightarrow responsable\_control\_id$ **no se preserva por restricciones de clave**, incorporando una consulta de diagnóstico específica para monitorear y detectar posibles inconsistencias.

#### Registro 4.2 · Mecanismo de Desnormalización para el Ranking de Ventas
* **Herramienta / Agente:** OpenCode / Antigravity
* **Prompt enviado a la IA:**  
  *"El cálculo de las 5 categorías más vendidas por día tarda demasiado. Sugerí un patrón de desnormalización eficiente en PostgreSQL."*
* **Respuesta relevante de la IA:**  
  La IA sugirió crear una columna `subtotal` en `detalle_pedido` y disparadores (`TRIGGERS`) que actualicen una tabla de acumulados en cada `INSERT` o `UPDATE` de pedidos.
* **Comprobación en el motor / Análisis crítico:**  
  Implementar triggers sincrónicos en tablas transaccionales de altísimo volumen (`detalle_pedido` recibe miles de inserciones concurrentes) degrada sensiblemente el rendimiento de escritura (OLTP) y genera contención por bloqueos de fila al actualizar acumuladores comunes. Además, no elimina la necesidad de unir `producto` y `categoria`.
* **Decisión técnica humana:**  
  **DESCARTADO CON FUNDAMENTO.** Se rechazó la solución de triggers en favor de una **vista materializada** (`mv_ventas_categoria_dia`) con índice único sobre `(fecha, categoria_id)`. Esto desacopla el cálculo analítico del flujo de ventas y permite refrescos no bloqueantes mediante `REFRESH MATERIALIZED VIEW CONCURRENTLY`.

---

### Unidad 5 · Administración, Seguridad y Protección de Datos

#### Registro 5.1 · Asignación de Privilegios al Rol de la Aplicación Web
* **Herramienta / Agente:** OpenCode / Asistente IA
* **Prompt enviado a la IA:**  
  *"Generar el script de permisos para el rol `app_web` de Food Store para que el backend de Node.js/Python opere sin fallas de acceso sobre las tablas del sistema."*
* **Respuesta relevante de la IA:**  
  La IA propuso: `GRANT ALL ON ALL TABLES IN SCHEMA public TO app_web;` y `ALTER ROLE app_web CREATEROLE;`, argumentando que de esta forma el backend no tendría problemas de permisos ante futuras tablas o migraciones.
* **Comprobación en el motor / Análisis crítico:**  
  Otorgar `ALL` confiere facultades destructivas (`DELETE`, `TRUNCATE`) y permisos de alteración de esquemas (DDL) al usuario de conexión web. Ante cualquier vulnerabilidad de inyección SQL o compromiso del backend, un atacante podría borrar tablas completas o crear usuarios de puerta trasera (`CREATEROLE`).
* **Decisión técnica humana:**  
  **VETO ENÉRGICO POR VIOLACIÓN DE MÍNIMO PRIVILEGIO.** Se rechazó la propuesta en su totalidad. Se aplicó el principio de mínimo privilegio (NIST SP 800-53):
  1. Se revocaron expresamente los privilegios `DELETE` y `TRUNCATE` sobre `pedido` y `detalle_pedido`.
  2. La lectura del catálogo de productos y categorías se restringió a vistas sanitizadas (`rol_app_lectura`).
  3. Se limitó el pool a un máximo de 50 conexiones con vencimiento temporal (`VALID UNTIL`).

#### Registro 5.2 · Auditoría y Privilegios del Rol de Soporte
* **Herramienta / Agente:** OpenCode / Asistente IA
* **Prompt enviado a la IA:**  
  *"¿Qué permisos otorgar al rol `rol_soporte` para consultar la tabla de usuarios sin comprometer datos confidenciales?"*
* **Respuesta relevante de la IA:**  
  La IA propuso conceder `GRANT SELECT ON TABLE usuario TO rol_soporte;` y delegar en el frontend o backend la responsabilidad de no mostrar los campos `contrasena` y `celular`.
* **Comprobación en el motor / Análisis crítico:**  
  La seguridad delegada en el software consumidor viola la defensa en profundidad. Al inspeccionar la tabla `usuario`, se constató que almacena hashes de contraseñas (`crypt`) y números celulares protegidos por la Ley 25.326. Si un operario de soporte se conecta mediante `psql` o DBeaver, puede ejecutar `SELECT * FROM usuario` y filtrar todas las credenciales de administradores.
* **Decisión técnica humana:**  
  **DESCARTADO POR INSEGURO.** La seguridad debe forzarse en el motor. Se crearon dos barreras: la vista restringida `v_usuarios_publico` y el otorgamiento granular a nivel de columna:
  ```sql
  GRANT SELECT (id, nombre, apellido, mail, rol) ON usuario TO rol_soporte;
  ```

#### Registro 5.3 · Reconstrucción del Incidente de Acceso Indebido
* **Herramienta / Agente:** OpenCode / Asistente IA
* **Prompt enviado a la IA:**  
  *"Analizá este extracto de log anonimizado del servidor PostgreSQL y determiná qué ocurrió y qué medidas de contención aplicar: [se adjuntan trazas con ráfaga de logins, SELECT masivo e intentos de escalamiento fallidos]."*
* **Respuesta relevante de la IA:**  
  La IA identificó la fuerza bruta inicial, pero concluyó que *'el atacante obtuvo control administrativo total del cluster (compromiso catastrófico)'*, recomendando reiniciar de inmediato el servidor físico, conceder privilegios temporales de superusuario a la cuenta de soporte y cambiar todas las claves maestras.
* **Comprobación en el motor / Análisis crítico:**  
  El equipo contrastó las afirmaciones de la IA línea por línea contra el log real. La IA omitió que las sentencias `GRANT admin_datos TO app_web;` y `ALTER ROLE app_web SUPERUSER;` arrojaron `ERROR: permission denied` y `must be superuser`. Al consultar `pg_roles` tras el ensayo, se constató que `app_web` continuaba sin permisos administrativos. La jerarquía de roles había **contenido el ataque con éxito**. Además, reiniciar el servidor destruiría la disponibilidad del negocio.
* **Decisión técnica humana:**  
  **RECHAZO DE LAS SUGERENCIAS DESTRUCTIVAS.** Se contuvo el incidente en caliente sin reiniciar el cluster:
  1. Bloqueo perimetral de la IP atacante en el firewall.
  2. Terminación forzada del PID anómalo mediante `pg_terminate_backend(pid)`.
  3. Reseteo inmediato y seguro de la credencial filtrada mediante la función PL/pgSQL `fn_resetear_password`.

#### Registro 5.4 · Dataset Anonimizado para IA (Ley 25.326)
* **Herramienta / Agente:** OpenCode / Asistente IA
* **Prompt enviado a la IA:**  
  *"Diseñá un script para generar una tabla `usuario_anon` que permita realizar consultas estadísticas con IA sin violar la Ley de Protección de Datos Personales."*
* **Respuesta relevante de la IA:**  
  La IA propuso reemplazar todos los nombres por `'Anonimo'` y todos los correos por `'anonimo@ejemplo.com'`.
* **Comprobación en el motor / Análisis crítico:**  
  Reemplazar valores por una constante idéntica destruye las propiedades de distribución estadística y cardinalidad (`COUNT(DISTINCT mail)` pasa de ser igual al número de usuarios a valer exactamente 1), haciendo imposible verificar la equivalencia analítica requerida en la Unidad 5.
* **Decisión técnica humana:**  
  **CORREGIDO.** Se aplicó un patrón sintético determinista: `'Usuario ' || id` y `'usuario' || id || '@ejemplo.test'`, preservando la cardinalidad exacta, anulando teléfonos (`NULL`) y neutralizando hashes (`'hash_no_valido'`).

---

### Unidad 6 · Mantenimiento, Respaldo y Recuperación ante Desastres

#### Registro 6.1 · Gestión Segura de Credenciales en Scripts de Backup
* **Herramienta / Agente:** OpenCode / Asistente IA
* **Prompt enviado a la IA:**  
  *"Escribí un script en PowerShell `backup_foodstore.ps1` para automatizar el respaldo diario de Food Store con `pg_dump`."*
* **Respuesta relevante de la IA:**  
  La IA incluyó al inicio del script: `$env:PGPASSWORD = "admin"` y utilizó el parámetro `--password`.
* **Comprobación en el motor / Análisis crítico:**  
  Escribir secretos en texto plano dentro de scripts versionados en Git constituye una vulnerabilidad crítica (CWE-259 / OWASP Top 10) y viola las políticas de seguridad del proyecto.
* **Decisión técnica humana:**  
  **VETO DE CREDENCIALES.** Se eliminó toda contraseña en texto plano, delegando la autenticación en variables de entorno efímeras del sistema operativo o en el archivo de credenciales protegidas `~/.pgpass` (`%APPDATA%\postgresql\pgpass.conf`) con permisos restrictivos `0600`.

#### Registro 6.2 · Mantenimiento Preventivo Dominical (VACUUM FULL vs. VACUUM ANALYZE)
* **Herramienta / Agente:** OpenCode / Asistente IA
* **Prompt enviado a la IA:**  
  *"¿Qué tarea periódica programar los domingos para compactar tablas y optimizar consultas en Food Store?"*
* **Respuesta relevante de la IA:**  
  La IA recomendó ejecutar semanalmente `VACUUM FULL ANALYZE` sobre todas las tablas de `foodstore`, argumentando que *'elimina completamente el espacio no utilizado y reduce al mínimo el tamaño en disco'*.
* **Comprobación en el motor / Análisis crítico:**  
  `VACUUM FULL` adquiere un bloqueo exclusivo total (`AccessExclusiveLock`). Mientras se ejecuta, bloquea de forma absoluta todas las lecturas (`SELECT`) y escrituras (`INSERT`, `UPDATE`), lo que provocaría la caída total de Food Store durante la ventana dominical. Además, requiere un 100% de espacio libre en disco adicional para reescribir la tabla física.
* **Decisión técnica humana:**  
  **VETO TÉCNICO ENÉRGICO.** Se prohibió taxativamente `VACUUM FULL` para rutinas operativas. En su lugar se implementó `VACUUM (VERBOSE, ANALYZE)` no bloqueante (`ShareUpdateExclusiveLock`), el cual recupera tuplas muertas en el *Free Space Map* (FSM) y actualiza histogramas estadísticos sin interrumpir la atención de clientes.

#### Registro 6.3 · Confusión Conceptual de Métricas de Recuperación (RTO vs. RPO)
* **Herramienta / Agente:** OpenCode / Asistente IA
* **Prompt enviado a la IA:**  
  *"En un simulacro de recuperación contra reloj, el proceso demoró 2.84 segundos restaurando un backup generado hace 15 minutos. Determiná el RTO y RPO observados."*
* **Respuesta relevante de la IA:**  
  La IA indicó que *'el RPO observado fue de 2.84 segundos porque fue el tiempo transcurrido para recuperar los puntos de la base'*.
* **Comprobación en el motor / Análisis crítico:**  
  La IA invirtió los conceptos fundamentales de Continuidad de Negocio (BCP):
  - El **RTO** (*Recovery Time Objective*) mide la duración de la interrupción técnica (tiempo cronometrado hasta restablecer el servicio: 2,842 segundos).
  - El **RPO** (*Recovery Point Objective*) mide la cantidad de datos que se tolera perder ante un siniestro (antigüedad de las transacciones no respaldadas: ~15 minutos).
* **Decisión técnica humana:**  
  **CORRECCIÓN CONCEPTUAL.** Se corrigió la interpretación y se documentó formalmente en el informe post-incidente `docs/tp8/informe_u6.md`.

---

### Unidad 7 · NoSQL y Nuevas Formas de Almacenamiento

#### Registro 7.1 · Evaluación Técnica de MongoDB vs. PostgreSQL
* **Herramienta / Agente:** Asistente IA Arquitecto
* **Prompt enviado a la IA:**  
  *"En Food Store tenemos normalizados los pedidos en PostgreSQL (`pedido`, `detalle_pedido`, `cliente`, `producto`). El patrón de acceso principal es la lectura frecuente de pedidos completos para despacho y facturación. ¿Conviene migrar todo a MongoDB o quedarse en PostgreSQL? Compará rendimiento e integridad."*
* **Respuesta relevante de la IA:**  
  La IA emitió dos afirmaciones categóricas:
  1. *'MongoDB es categóricamente superior en velocidad a PostgreSQL porque elimina los JOINs.'*
  2. *'En MongoDB no existen garantías transaccionales ni atomicidad, por lo que corrés el riesgo de perder precios históricos.'*
* **Comprobación en el motor / Análisis crítico:**  
  1. *Falsedad de la afirmación 2:* La documentación oficial de MongoDB establece formalmente la **atomicidad a nivel de documento único** (*Single-Document Atomicity*). Al modelar un pedido con sus líneas embebidas, la inserción es 100% atómica. Además, el precio unitario histórico no se pierde: queda congelado como valor escalar inmutable dentro del subdocumento de la línea.
  2. *Matiz de la afirmación 1:* En PostgreSQL, los `JOIN` entre tablas indexadas por clave primaria se resuelven en memoria caché (`shared_buffers`) en décimas de milisegundo. En MongoDB, los documentos desnormalizados son más voluminosos, lo que aumenta el consumo de ancho de banda y memoria RAM.
* **Decisión técnica humana:**  
  **REFUTACIÓN Y ADOPCIÓN DE PERSISTENCIA POLÍGLOTA.** Se rechazaron las afirmaciones maniqueas de la IA. Se concluyó fundadamente que la solución óptima es la convivencia de ambos motores: PostgreSQL como núcleo transaccional ACID de ventas e inventario, y MongoDB como réplica de lectura documental desnormalizada para visualización masiva.

---

### Unidad 8 · Bases de Datos Móviles e Integración

#### Registro 8.1 · Restricción de Unicidad en la Cola Móvil de Sincronización
* **Herramienta / Agente:** Antigravity / OpenCode
* **Prompt enviado a la IA:**  
  *"Diseñá el esquema SQLite para la tablet en modo STRICT. Asegurá que no se puedan duplicar solicitudes de sincronización para un mismo pedido borrador."*
* **Respuesta relevante de la IA:**  
  La IA propuso aplicar una restricción `UNIQUE (id_local)` sobre la tabla `cola_sync`.
* **Comprobación en el motor / Análisis crítico:**  
  Al ejecutar el Caso C2 de la simulación (conflicto de precio resuelto con el cliente), el primer envío falló con `CONFLICTO`. Tras aceptar el cliente la nueva tarifa, la tablet debió generar una segunda solicitud (`solicitud-uuid-c2-envio2`) referenciando al mismo borrador local `id_local`. Con la propuesta de la IA, SQLite abortó inmediatamente la operación arrojando `sqlite3.IntegrityError: UNIQUE constraint failed: cola_sync.id_local`.
* **Decisión técnica humana:**  
  **DESCARTADO CON FUNDAMENTO.** Un mismo pedido borrador puede atravesar múltiples intentos de sincronización en su ciclo de vida. Se sustituyó por el índice parcial condicional:
  ```sql
  CREATE UNIQUE INDEX ux_cola_una_pendiente ON cola_sync (id_local) WHERE estado = 'PENDIENTE';
  ```
  impidiendo dos envíos pendientes en paralelo, pero habilitando reintentos sucesivos.

#### Registro 8.2 · Concurrencia de Stock en el Servidor Central
* **Herramienta / Agente:** Antigravity / OpenCode
* **Prompt enviado a la IA:**  
  *"Revisá el procedimiento `sp_crear_pedido` en PostgreSQL para asegurar que las ventas validadas desde tablets no generen carreras críticas sobre el último ítem de inventario."*
* **Respuesta relevante de la IA:**  
  La IA sugirió incorporar una cláusula de bloqueo pesimista `SELECT ... FOR UPDATE` al comprobar existencias de stock antes de ejecutar el `UPDATE`.
* **Comprobación en el motor / Análisis crítico:**  
  Se simuló en PostgreSQL la ejecución paralela de dos transacciones sobre un ítem con `stock = 1`. Sin el `FOR UPDATE`, ambas leyeron `1` de forma concurrente e intentaron descontar, derivando en aborto por restricción `CHECK (stock >= 0)`.
* **Decisión técnica humana:**  
  **ACEPTADO Y VERIFICADO.** Se incorporó `SELECT stock INTO v_stock FROM producto WHERE id_producto = ... FOR UPDATE;` garantizando la serialización segura del inventario ante múltiples terminales concurrentes.

---

## 3. Síntesis Evaluativa del Uso de IA en la Capa de Datos

| Métrica / Dimensión | Valor Observado | Justificación y Evidencia en Repositorio |
| :--- | :---: | :--- |
| **Total de Interacciones Críticas Registradas** | **12 casos** | Distribuidos en Unidades 4 a 8 (FNBC, seguridad, mantenimiento, NoSQL y móviles). |
| **Tasa de Descarte / Corrección Humana** | **83,3% (10 de 12)** | Evidencia que el equipo humano mantuvo el control técnico absoluto sobre las decisiones de diseño. |
| **Vulnerabilidades Críticas Evitadas** | **5 riesgos mayores** | Inclusión de secretos en scripts, exposición de datos sensibles con `GRANT ALL`, bloqueo destructivo `VACUUM FULL`, reinicio innecesario del motor en incidentes y aborto de sincronización móvil por índices únicos erróneos. |
| **Herramientas Utilizadas** | Kiro, OpenCode, Antigravity | Notación formal EARS para requerimientos y modelos agenticos para pair programming. |

La bitácora confirma que los asistentes inteligentes representan herramientas sumamente productivas para la exploración de alternativas y la redacción de especificaciones, pero requieren una supervisión humana rigurosa sustentada en conocimientos técnicos sólidos y verificación empírica en el motor.
