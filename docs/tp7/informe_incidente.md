# Informe de Reconstrucción de Incidente y Lectura Crítica (TP7 - Parte C)

## Proyecto: Food Store — Base de Datos II (UTN)
**Incidente:** Acceso No Autorizado, Exfiltración de Datos e Intento de Escalamiento  
**Evidencia Base:** [`docs/tp7/log_simulacro_anonimizado.txt`](file:///d:/formateo%20win%2011/Estudios%20(Nuevo)/utn%20tec.%20programación/3°%20Semestre/Base%20de%20Datos%202/Food-Store/docs/tp7/log_simulacro_anonimizado.txt)  
**Herramienta Asistente:** OpenCode / Asistente IA  

---

### 1. Reconstrucción e Hipótesis Propuesta por la Inteligencia Artificial

A partir del log anonimizado entregado sin información de contexto previa, el asistente de IA formuló la siguiente reconstrucción:

> **Respuesta de la IA:**
> "A partir del análisis de las trazas del servidor entre las 05:30:01 y las 05:36:42:
> 1. **Fase de Acceso Inicial:** Se observa un ataque automatizado de fuerza bruta o diccionario proveniente de la IP externa `198.51.100.42` contra la función de autenticación `fn_autenticar`, registrando más de 340 intentos fallidos en un lapso de 6 minutos. A las 05:36:02 se produce un login exitoso comprometiendo la cuenta `user_tok_9912@anon.test` con rol `ADMIN`.
> 2. **Fase de Exfiltración:** A las 05:36:15, el atacante ejecutó `SELECT id, nombre, apellido, mail, celular, rol, eliminado, created_at FROM usuario;`, logrando una descarga masiva y exfiltración de la base de usuarios de la plataforma.
> 3. **Fase de Escalamiento:** El atacante intentó consolidar persistencia y escalamiento vertical ejecutando `GRANT admin_datos TO app_web;` y posteriormente `ALTER ROLE app_web SUPERUSER;`.
> 4. **Hipótesis de Contención Sugerida:** Se sugiere bloquear la IP a nivel firewall, ejecutar inmediatamente un reinicio del motor PostgreSQL, otorgar privilegios de administrador temporales para reparar el servicio y cambiar todas las contraseñas del cluster."

---

### 2. Lectura Crítica: Contraste entre la Reconstrucción de la IA y lo Realmente Ejecutado

Conforme a las directivas de la cátedra, se evaluó críticamente la respuesta de la IA frente a la secuencia real ejecutada por el equipo en [`db/simulacro_incidente.sql`](file:///d:/formateo%20win%2011/Estudios%20(Nuevo)/utn%20tec.%20programación/3°%20Semestre/Base%20de%20Datos%202/Food-Store/db/simulacro_incidente.sql):

| Aspecto | Qué acertó la IA | Qué omitió o interpretó erróneamente | Afirmaciones no sustentadas por el log |
| :--- | :--- | :--- | :--- |
| **Fuerza bruta y login** | Identificó correctamente la ráfaga de más de 340 intentos en pocos minutos y el posterior login exitoso con credencial de administrador. | Omitió señalar que el login comprometido operó a través de la identidad técnica del pool `app_web` y no una conexión directa del usuario. | Asume que la contraseña se obtuvo por fuerza bruta de diccionario, cuando en realidad pudo tratarse de *credential stuffing* o fuga previa. |
| **Exfiltración de datos** | Detectó la consulta sobre la tabla `usuario` y el impacto sobre datos personales. | Omitió destacar que el volumen fue de solo 3 filas en este entorno de prueba y no millones de registros. | Afirma taxativamente que hubo "descarga y exfiltración fuera del sistema", lo cual el log de base de datos no puede asegurar por sí solo (solo registra que la query se ejecutó). |
| **Escalamiento de privilegios** | Reconoció las sentencias `GRANT admin_datos` y `ALTER ROLE app_web SUPERUSER`. | **Omisión crítica de seguridad:** La IA no resaltó explícitamente que **ambos intentos de escalamiento FALLARON** (`permission denied` y `must be superuser`). El esquema de permisos de la Parte A **contuvo el ataque**. | Ninguna. |
| **Propuesta de contención** | Sugirió acertadamente el bloqueo perimetral de la IP atacante. | Omitió la utilización de las herramientas internas del motor ya diseñadas, como la función `fn_resetear_password`. | **Sugerencia peligrosa/insegura:** Sugerir reiniciar el motor o "otorgar permisos temporales" para reparar es desmedido y destructivo para la disponibilidad del negocio. |

---

### 3. Decisión Final de Contención del Equipo (Criterio Propio)

La decisión de remediación y contención es adoptada de forma autónoma y fundada por el equipo técnico, rechazando las sugerencias apresuradas de la IA:

1. **Bloqueo Perimetral Inmediato:** Se aplica bloqueo estricto en el firewall de borde / WAF a la dirección IP de origen `198.51.100.42` para cortar el canal activo.
2. **Terminación de Sesiones Anómalas:** Identificación del PID en `pg_stat_activity` y terminación forzada mediante `SELECT pg_terminate_backend(pid);`.
3. **Invalidación y Reseteo Forzado de Contraseña:** Dado que la cuenta de correo `admin@foodstore.com` (comprometida) pertenece a un administrador legítimo, el DBA o el rol de soporte ejecuta la función segura:
   ```sql
   SELECT fn_resetear_password(1, 'PwdEmergenciaContencion2026!#');
   ```
   Esto inhabilita de inmediato el acceso con la credencial filtrada sin requerir reinicios del servidor.
4. **Validación del Esquema de Mínimo Privilegio:** Se documenta formalmente que el esquema de la **Parte A resistió el ataque**: el usuario atacante no pudo escalar a `admin_datos` ni obtener `SUPERUSER`, confirmando la efectividad del aislamiento de roles.
5. **Notificación de Fuga de Información:** Dado que `SELECT * FROM usuario` tuvo éxito, se activa el protocolo de la Ley 25.326 para notificar a los usuarios afectados y auditar si se expusieron teléfonos o datos de contacto.
