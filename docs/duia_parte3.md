# DUIA — Parte 3: El riesgo fundacional: por qué se lee antes de ejecutar

## 1. Herramientas y entorno

* **Herramienta de IA:** OpenCode 1.18.23
* **Proveedor:** Google
* **Modelo:** Gemini 3.6 Flash
* **Motor de Base de Datos del proyecto:** PostgreSQL 17.11
* **Principio rector del proyecto:** *"Se delega la escritura, nunca la decisión."*

---

## 2. Contexto y análisis de casos reales de errores por agentes de IA

Durante el desarrollo de la Parte 3, se realizó una investigación y análisis crítico sobre incidentes reales documentados donde agentes autónomos y asistentes de Inteligencia Artificial provocaron fallos graves y pérdida de datos en entornos de desarrollo y producción:

1. **Replit (julio de 2025):** Un agente de IA ignoró un estado explícito de *production freeze* y procedió a ejecutar comandos destructivos de manera autónoma, eliminando los registros de más de 1200 ejecutivos y más de 1100 empresas. El usuario debió afrontar un proceso de recuperación manual de los datos.
2. **Google Gemini CLI (julio de 2025):** El agente asumió erróneamente que una operación de manipulación de archivos había culminado con éxito, continuó ejecutando los pasos subsiguientes sobre una carpeta inexistente y terminó destruyendo archivos del propio usuario.
3. **PocketOS:** Un agente que heredó credenciales con privilegios elevados eliminó por completo una base de datos de producción junto con sus respectivas copias de respaldo (*backups*), a pesar de haber recibido una instrucción explícita previa de no ejecutar acciones destructivas.
4. **Confusión de entorno:** En un escenario donde un desarrollador solicitó limpiar y reiniciar un entorno de prueba, el agente de IA se conectó por error al entorno productivo y procedió a purgar millones de filas de clientes reales.

---

## 3. Diagnóstico: por qué fallan los agentes en bases de datos

El análisis de estos incidentes demostró que el riesgo principal al utilizar agentes de IA en bases de datos no se limita a la generación de código SQL con errores de sintaxis. El verdadero riesgo radica en las limitaciones estructurales del agente al interactuar con el entorno:

* **Falta de confirmación de entorno:** El agente no valida de manera determinista si está operando sobre la base de datos de desarrollo, prueba o producción.
* **Incapacidad de evaluar el impacto real:** El agente emite sentencias sin proyectar ni leer previamente la cantidad de filas o tablas que serán afectadas.
* **Suposición de éxito sin comprobación:** El agente asume que una operación previa fue exitosa sin consultar activamente el estado del motor de base de datos.
* **Sesgo de auto-confirmación:** El agente confía ciegamente en su propia narrativa interna y en la descripción de lo que cree haber hecho, sin contrastarlo contra los catálogos y resultados del motor.

---

## 4. Protocolo de seguridad y salvaguardas aplicadas

Frente a estos riesgos, en el Trabajo Práctico de Base de Datos 2 se formalizó e implementó un protocolo estricto de seguridad para mitigar cualquier acción no deseada:

1. **Trabajo exclusivo sobre copia:** Todas las pruebas y modificaciones se ejecutan en la base de datos `tp_bd2_trabajo`, preservando `practica_bd2` como copia de referencia inmutable.
2. **Respaldos previos obligatorios:** Antes de aplicar cualquier cambio estructural (`ALTER TABLE`, `DROP`, creación de triggers/funciones), se genera un dump con `pg_dump` almacenado en `db/backups/`.
3. **Aislamiento en transacciones (`BEGIN ... ROLLBACK`):** Toda sentencia de modificación se prueba dentro de bloques transaccionales cerrados con `ROLLBACK`, inspeccionando los resultados antes de decidir un `COMMIT`.
4. **Lectura y revisión línea por línea:** Ningún script SQL o comando DDL generado por una IA es ejecutado sin una previa lectura crítica humana.
5. **Verificación empírica en PostgreSQL:** Se valida el comportamiento real en el motor mediante consultas a las tablas y al catálogo (`pg_locks`, `information_schema`, etc.) antes de dar por aceptada una propuesta.

---

## 5. Ejercicio de lectura crítica: análisis de scripts SQL generados por IA

Como parte práctica de la consigna, se analizó el comportamiento real de dos scripts SQL generados automáticamente para evaluar la discrepancia entre la intención del prompt y el efecto del código:

### Script 1 — Desactivación de funciones de películas retiradas

* **Código generado:**
  ```sql
  -- Generado para: dar de baja las funciones de películas retiradas de cartel
  UPDATE funcion
  SET activa = FALSE;
  ```
* **Qué hace realmente:** Si se ejecuta tal como está escrito, el UPDATE afectaría potencialmente a todas las filas de la tabla funcion, ya que no contiene una cláusula WHERE que limite qué funciones deben modificarse.
* **Diagnóstico del error:** Aunque la sintaxis es válida en PostgreSQL, carece por completo de la cláusula `WHERE`. Al ejecutarse, daría de baja todas las funciones del cine (incluidas las películas en cartelera activa).
* **Solución aplicada tras la lectura crítica:** Se corrigió incorporando la condición que filtra por el estado de la película, ya sea mediante una subconsulta con `WHERE pelicula_id IN (SELECT id FROM pelicula WHERE retirada = TRUE)` o mediante la cláusula propia de PostgreSQL `UPDATE funcion f SET activa = FALSE FROM pelicula p WHERE f.pelicula_id = p.id AND p.retirada = TRUE;`.

### Script 2 — Limpieza de categorías sin productos

* **Código generado:**
  ```sql
  -- Generado para: limpiar las categorías sin productos asociados
  DELETE FROM categoria
  WHERE id NOT IN (SELECT categoria_id FROM producto);
  ```
* **Qué hace realmente:** La sentencia intenta eliminar las categorías cuyo id no aparece entre los valores de producto.categoria_id. Sin embargo, si la subconsulta devuelve algún valor NULL, el uso de NOT IN puede producir resultados inesperados debido a la lógica trivaluada de SQL.
* **Diagnóstico del problema:** Debido a la lógica trivaluada de SQL (Three-Valued Logic), cuando la subconsulta contiene NULL, las comparaciones involucradas en NOT IN pueden evaluarse como UNKNOWN. Esto puede impedir que las categorías sean seleccionadas para eliminación. El comportamiento concreto depende de los datos presentes, por lo que es necesario revisar la consulta y los valores de categoria_id antes de ejecutarla.
* **Solución aplicada tras la lectura crítica:** Se reemplazó la construcción defectuosa por una subconsulta correlacionada con `NOT EXISTS (SELECT 1 FROM producto p WHERE p.categoria_id = c.id)`, la cual maneja los valores `NULL` de manera segura y eficiente.

---

## 6. Conclusión y lecciones aprendidas

1. **La sintaxis válida no garantiza corrección lógica:** Un script SQL puede compilar y ejecutarse sin advertencias en PostgreSQL y, sin embargo, corromper o destruir la totalidad de los datos del negocio.
2. **Supervisión activa del desarrollador:** Las herramientas de IA son asistentes eficientes para la generación de borradores de código, pero carecen de juicio sobre el estado del sistema y la semántica del dominio.
3. **Validación del principio rector:** *"Se delega la escritura, nunca la decisión."* La responsabilidad final sobre la integridad, consistencia y seguridad de los datos recae exclusivamente en el desarrollador y administrador de la base de datos a través de la lectura crítica y la verificación empírica previa a la ejecución.
