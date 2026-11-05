# Declaración de Uso de Inteligencia Artificial (DUIA)
## Trabajo Práctico Integrador — Segunda Entrega Parcial (Unidades 4 a 8)
### Asignatura: Base de Datos II · Tecnicatura Universitaria en Programación (UTN)

**Estudiante / Integrante:** Cristian Rodriguez (`Cloverfield`)  
**Carrera:** Tecnicatura Universitaria en Programación  
**Ciclo Lectivo:** 2026  
**Proyecto:** Food Store — Capa de Datos Integral  

---

### 1. Compromiso Ético y Responsabilidad Académica
En cumplimiento de las pautas institucionales de la Universidad Tecnológica Nacional (UTN) y del **Protocolo Obligatorio de Uso de IA sobre Datos** de la cátedra de Base de Datos II, declaro que:

1. **Autoría y Soberanía Intelectual:**  
   La totalidad de los modelos de datos (relacional, documental y móvil), el código SQL / PL/pgSQL, los scripts de mantenimiento en PowerShell y Bash, las colecciones documentales en MongoDB, los esquemas y algoritmos en SQLite, y las justificaciones teóricas contenidas en esta entrega fueron analizados, comprendidos, redactados y verificados experimentalmente por el autor. Me encuentro plenamente facultado para explicar y defender de forma individual cada decisión técnica en la instancia oral de evaluación.
2. **Rol y Límite de las Herramientas de IA:**  
   Los modelos de lenguaje basados en Inteligencia Artificial Generativa actuaron exclusivamente como asistentes complementarios de pair programming, facilitadores en la estructuración de especificaciones en notación EARS y agentes de revisión de código (*code review*).
3. **Validación Empírica Obligatoria:**  
   Ninguna propuesta emitida por una IA fue incorporada al proyecto de forma desatendida. Cada sugerencia fue sometida a pruebas en los motores de base de datos de referencia (PostgreSQL 17.11, MongoDB 9.0.4 y SQLite 3.50.4), habiéndose detectado, rechazado y corregido con fundamento técnico más del 80% de las propuestas automatizadas debido a riesgos de seguridad, indisponibilidad o inconsistencia transaccional.
4. **Protección de Datos Personales (Ley 25.326):**  
   Ningún dato personal sensible de clientes o usuarios de Food Store fue transferido o compartido con plataformas de IA. Las pruebas e interacciones se realizaron exclusivamente sobre el dataset sintético determinista `usuario_anon` o sobre trazas debidamente tokenizadas.

---

### 2. Herramientas de IA Empleadas y Ámbito de Aplicación
* **Google Antigravity / OpenCode (Gemini 3.8 Flash High):** Utilizado para asistencia en la formulación de consultas complejas, generación de borradores iniciales de scripts de respaldo/restauración y revisión estática de vulnerabilidades.
* **Kiro (Metodología EARS):** Utilizado para estructurar formalmente especificaciones funcionales y de diseño en las Unidades 4, 5 y 8 (`requirements.md`, `design.md`, `rollback_plan.md`).

---

### 3. Registro y Evidencia de Interacciones
El detalle exhaustivo de los prompts formulados, respuestas recibidas, comprobaciones en motor y fundamentos técnicos de aceptación o descarte se encuentra asentado en el documento complementario:
- [`docs/tpi_parcial2/bitacora_ia_consolidada.md`](file:///d:/formateo%20win%2011/Estudios%20(Nuevo)/utn%20tec.%20programación/3°%20Semestre/Base%20de%20Datos%202/Food-Store/docs/tpi_parcial2/bitacora_ia_consolidada.md)

---

**Firma del Estudiante:** Cristian Rodriguez  
**Fecha de Presentación:** Noviembre de 2026
