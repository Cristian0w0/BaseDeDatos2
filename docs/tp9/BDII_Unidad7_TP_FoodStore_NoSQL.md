TECNICATURA UNIVERSITARIA EN PROGRAMACIÓN 

# **TRABAJO PRÁCTICO · UNIDAD 7** 

## **NoSQL y nuevas formas de almacenamiento | Food Store** 

La actividad propone representar en MongoDB una parte ya implementada del proyecto Food Store, ejecutar consultas y compararlas con los resultados de PostgreSQL. El análisis documentará la elección tecnológica y contrastará las sugerencias obtenidas mediante herramientas de IA. 

# **Objetivos, alcance y condiciones de realización** 

**Objetivo general.** Modelar y consultar un subconjunto real de Food Store en MongoDB, contrastando estructura y resultados con PostgreSQL, y fundamentar la decisión de diseño. 

- Se utilizará la base relacional Food Store desarrollada en la asignatura y una colección documental en MongoDB. 

- Se conservarán los identificadores de origen y se respetarán los importes, cantidades y estados existentes. 

- La consigna no requiere migrar toda la base, instalar Redis o Neo4j ni configurar un clúster. 

- Se podrán utilizar herramientas de IA para explorar el diseño o generar consultas, pero se deberán contrastar sus propuestas con ejecución real y documentación técnica. 

**Alcance sugerido.** Se recomienda tomar al menos cinco pedidos existentes y sus detalles. Si la base de desarrollo no contiene suficientes registros, se podrán incorporar pedidos de prueba coherentes con las reglas del dominio, dejando indicada su procedencia. 

# **Parte 1 · Modelo documental y migración** 

**Consigna 1.** Seleccionar el subconjunto «pedidos y detalle de pedidos» de Food Store. Identificar las tablas y claves que intervienen en PostgreSQL. Elaborar un esquema breve de la colección documental propuesta, indicando campos principales, objetos embebidos, arreglos e identificadores conservados. 

**Consigna 2.** Crear la base y la colección en MongoDB. Migrar un mínimo de **cinco pedidos** con sus líneas y datos esenciales del cliente. La migración puede realizarse mediante instrucciones insertMany() o una importación equivalente. Los documentos deben incluir fecha, estado, cliente, productos, cantidades y precios históricos. 

**Consigna 3.** Indicar dos reglas de integridad que deben conservarse durante la migración y justificar brevemente qué datos se incluyeron dentro del documento en lugar de almacenarse en colecciones separadas. 

Tecnicatura Universitaria en Programación  |  Material académico 

1 

Trabajo práctico 

**BASES DE DATOS II  /  UNIDAD 7** 

# **Parte 2 · Consultas y verificación** 

**Consigna 4.** Ejecutar en MongoDB las siguientes **cuatro consultas** , adaptadas a los nombres de campos del modelo implementado: 

- a) Mostrar todos los pedidos, incluyendo su identificador y estado. 

- b) Filtrar pedidos por un estado que exista en los datos migrados. 

- c) Buscar pedidos que contengan un producto determinado dentro del arreglo de líneas. 

- d) Buscar pedidos cuyo total sea superior a un importe elegido y justificar el umbral. 

**Consigna 5.** Resolver en PostgreSQL las consultas equivalentes a los apartados **b)** y **c)** . Comparar en una tabla la cantidad y los identificadores de pedidos recuperados en ambos motores. Explicar cualquier diferencia detectada y corregir el modelo o la consulta cuando corresponda. 

|**Consulta**|**Cantidad en**|**Cantidad en**|**Coinciden los IDs**|
|---|---|---|---|
||**PostgreSQL**|**MongoDB**||
|Estado seleccionado|________|________|Sí / No|
|Producto seleccionado|________|________|Sí / No|



# **Parte 3 · Evaluación de la tecnología e IA** 

**Consigna 6.** Utilizar una herramienta de IA para comparar PostgreSQL y MongoDB respecto del almacenamiento y la consulta de pedidos de Food Store. La consulta realizada deberá mencionar el modelo actual, el acceso frecuente a pedidos completos y la necesidad de conservar la coherencia de cantidades y precios. 

**Consigna 7.** Contrastar **dos afirmaciones concretas** de la respuesta de IA con documentación oficial o con resultados del laboratorio. Elaborar una conclusión de hasta **200 palabras** que indique si conviene mantener PostgreSQL, utilizar MongoDB para ese subconjunto o combinar tecnologías. La conclusión debe fundamentarse en al menos dos criterios técnicos. 

# **Entrega** 

Se presentará **un único PDF de hasta cinco páginas** (sin contar el código adjunto), con una descripción sintética del modelo, evidencias de la colección y de las consultas, tabla de verificación, contraste de afirmaciones de IA y conclusión. Se adjuntarán los archivos **consultas_mongodb.js** y **consultas_postgresql.sql** , o nombres equivalentes, con las instrucciones ejecutadas. 

Las evidencias podrán consistir en capturas legibles o salidas de ejecución. No se incorporarán imágenes decorativas, transcripciones extensas de conversaciones ni datos personales reales. Se identificará a los integrantes del equipo y el repositorio de trabajo, cuando corresponda a la modalidad de cursada. 

Tecnicatura Universitaria en Programación  |  Material académico 

2 

Trabajo práctico 

**BASES DE DATOS II  /  UNIDAD 7** 

# **Criterios de evaluación** 

|**Criterio**|**Puntaje**|
|---|---|
|Modelo documental y correspondencia con Food Store; migración de datos|35 puntos|
|Consultas ejecutadas y comparación verificable con PostgreSQL|40 puntos|
|Contraste de recomendaciones de IA y fundamentación técnica|20 puntos|
|Presentación, claridad y evidencias completas|5 puntos|
|**Total**|**100 puntos**|



**Material de consulta.** Apunte «Unidad 7: NoSQL y nuevas formas de almacenamiento»; documentación oficial de MongoDB: https://www.mongodb.com/docs/manual/data-modeling/embedding/ y https://www.mongodb.com/es/docs/manual/reference/method/db.collection.find/. 

**Aclaración de implementación.** Los nombres de tablas y atributos incluidos en el material teórico son ilustrativos. Las entregas deberán corresponder a la versión real de Food Store desarrollada por cada equipo. 

Tecnicatura Universitaria en Programación  |  Material académico 

3 

