# Trabajo Práctico — Unidad 7: NoSQL y nuevas formas de almacenamiento
## Food Store: PostgreSQL vs. MongoDB

**Asignatura:** Base de Datos II — Tecnicatura Universitaria en Programación (UTN)  
**Estudiante:** Cristian Rodriguez (`Cloverfield`)  
**Rama:** `tp9-nosql`  

---

### Resumen del Trabajo Práctico
* **Parte 1 — Modelo Documental y Migración:** Análisis del subconjunto transaccional relacional (`pedido`, `detalle_pedido`, `cliente`, `producto`), diseño desnormalizado BSON (*Aggregate Root*) en la colección `pedidos` (base `foodstore_nosql`), y migración mediante `insertMany()`.
* **Parte 2 — Consultas y Verificación Cruzada:** Ejecución de 4 consultas en MongoDB Shell (`mongosh`) con filtros sobre campos raíz y arreglos embebidos, y formulación de consultas relacionales equivalentes en PostgreSQL (`consultas_postgresql.sql`), comprobando coincidencia biunívoca total en pedidos `[1, 3, 4]`.
* **Parte 3 — Evaluación de IA y Conclusión Técnica:** Contraste crítico de afirmaciones de asistentes de IA sobre atomicidad a nivel de documento único y persistencia políglota (CQRS).

### Entregables
* `docs/tp9/consultas_mongodb.js`: Script ejecutable de inicialización y consultas en MongoDB.
* `docs/tp9/consultas_postgresql.sql`: Consultas SQL de comprobación cruzada en PostgreSQL.
* `docs/tp9/informe_tp9.md` / `informe_tp9.html` / `informe_tp9.pdf`: Informe oficial consolidado.
