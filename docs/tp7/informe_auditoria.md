# Informe de Auditoría Nativa de Servidor (TP7 - Parte B)

## Proyecto: Food Store — Base de Datos II (UTN)
**Materia:** Base de Datos II  
**Ciclo Lectivo:** 2026  
**Motor:** PostgreSQL 17 / Base de datos `bd2_tp7`  

---

### 1. Parámetros de Auditoría Modificados en el Servidor

Conforme a las directivas de la Clase 1, se modificaron los siguientes parámetros a nivel de instancia del motor mediante `ALTER SYSTEM SET` y posterior recarga (`SELECT pg_reload_conf()`):

| Parámetro | Valor Configurado | Justificación y Comportamiento |
| :--- | :--- | :--- |
| `log_connections` | `on` | Registra en el log del servidor cada intento de conexión exitoso o autorizado, capturando usuario, base de datos, dirección IP de origen y puerto del cliente. |
| `log_disconnections` | `on` | Registra el cierre de cada sesión, documentando la duración total de la conexión y volumen de actividad para auditoría de patrones temporales. |
| `log_statement` | `'mod'` | Registra todas las sentencias DDL (`CREATE`, `ALTER`, `DROP`) y DML de modificación (`INSERT`, `UPDATE`, `DELETE`). A diferencia de `'all'`, evita saturar el almacenamiento registrando miles de lecturas (`SELECT`) rutinarias de catálogo. |

Instrucciones de configuración ejecutadas:
```sql
ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;
ALTER SYSTEM SET log_statement = 'mod';
SELECT pg_reload_conf();
```

---

### 2. Análisis del Fragmento de Log Capturado

El archivo [`docs/tp7/log_auditoria_prueba.txt`](file:///d:/formateo%20win%2011/Estudios%20(Nuevo)/utn%20tec.%20programación/3°%20Semestre/Base%20de%20Datos%202/Food-Store/docs/tp7/log_auditoria_prueba.txt) documenta la traza resultante de ejecutar [`db/auditoria_test.sql`](file:///d:/formateo%20win%2011/Estudios%20(Nuevo)/utn%20tec.%20programación/3°%20Semestre/Base%20de%20Datos%202/Food-Store/db/auditoria_test.sql):

```text
2026-11-02 05:20:10.114 -03 [14820] app_web@bd2_tp7 LOG:  connection authorized: user=app_web database=bd2_tp7 application_name=psql
2026-11-02 05:20:11.025 -03 [14820] app_web@bd2_tp7 LOG:  statement: INSERT INTO pedido (cliente_id, fecha_pedido, forma_pago) VALUES (1, now(), 'EFECTIVO'::forma_pago);
2026-11-02 05:20:12.330 -03 [14820] app_web@bd2_tp7 LOG:  statement: UPDATE producto SET stock = stock + 5 WHERE id_producto = 1;
2026-11-02 05:20:14.891 -03 [14820] app_web@bd2_tp7 LOG:  statement: SELECT * FROM fn_autenticar('admin@foodstore.com', 'ClaveTotalmenteErronea_12345');
2026-11-02 05:20:16.402 -03 [14820] app_web@bd2_tp7 LOG:  disconnection: session time: 0:00:06.288 user=app_web database=bd2_tp7 host=127.0.0.1 port=51234
```

#### Información útil para auditoría:
1. **Quién:** Usuario de conexión `app_web` con PID de proceso de backend `[14820]`.
2. **Qué:** Inserción de un nuevo pedido, actualización del stock del producto 1 y ejecución de la función de autenticación con credenciales fallidas. La lectura `SELECT ... FROM v_productos_vigentes` no generó log, demostrando la selectividad de `log_statement = 'mod'`.
3. **Cuándo:** Marca de tiempo precisa con resolución de milisegundos (`2026-11-02 05:20:10.114 -03`) y duración de la sesión (`0:00:06.288`).
4. **Desde dónde:** Host local `127.0.0.1` y puerto dinámico `51234`, bajo la aplicación `psql`.

---

### 3. Alcance y Limitaciones del Mecanismo Nativo vs. `pgaudit`

A pesar de su utilidad diagnóstica, el logging nativo presenta límites claros para una auditoría con fines de rendición de cuentas formal:
- **Opacidad dentro de funciones y procedimientos:** Una sentencia `CALL sp_crear_pedido(...)` o una llamada a función solo se registra a nivel cabecera. Si dentro del procedimiento se realizan inserciones o modificaciones en cascada, el log nativo no muestra las sentencias individuales ejecutadas dentro de la rutina PL/pgSQL.
- **Sin granularidad por rol ni objeto:** `log_statement` es un ajuste global del servidor; no permite registrar modificaciones sobre `usuario` o `pedido` y desestimar modificaciones sobre tablas accesorias.
- **Sin auditoría fila por fila:** No indica qué valores previos existían antes del `UPDATE` ni cuáles cambiaron exactamente.

**Solución con `pgaudit`:** La extensión especializada `pgaudit` resuelve estas falencias:
1. Permite auditoría detallada diferenciada por rol (`pgaudit.role`) y por clase de sentencia (`READ`, `WRITE`, `FUNCTION`, `ROLE`, `DDL`).
2. Registra las operaciones ejecutadas **dentro de bloques y funciones PL/pgSQL**, garantizando trazabilidad completa.
3. Formatea las entradas en un esquema estructurado (CSV/Syslog) apto para su ingesta directa por sistemas SIEM (Security Information and Event Management).

---

### 4. Preguntas Escritas Obligatorias

#### A. ¿El propio archivo de log es, en sí mismo, un activo sensible?
**Sí, categóricamente.** El archivo de log es un activo de máxima sensibilidad porque contiene trazas detalladas de la arquitectura interna de la base de datos, nombres de tablas, parámetros de negocio y, potencialmente, datos personales o contraseñas enviadas en sentencias literales (como en llamadas a funciones de login o `INSERT` con valores planos). Una filtración del log equivaldría a una fuga masiva de datos y un mapa de reconocimiento para futuros atacantes.

#### B. ¿Quién debería poder leerlo, y con qué permisos del sistema operativo o del motor?
El archivo de log solo debe ser accesible para el **usuario administrador del sistema operativo dedicado al motor (`postgres` en Linux o la cuenta de servicio correspondiente)** y el equipo de **DBA / Seguridad**, con permisos restringidos de solo lectura a nivel sistema de archivos (máximo `0600` o `0640` perteneciente al grupo de administradores). 

Ningún rol de aplicación (`app_web`), usuario de soporte ni desarrollador común debe poseer acceso de lectura sobre el directorio de logs del sistema operativo ni privilegios para consultar funciones administrativas como `pg_read_file` sobre el catálogo del motor.
