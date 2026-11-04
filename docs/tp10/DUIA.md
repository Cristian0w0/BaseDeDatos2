# Declaración de Uso de Inteligencia Artificial (DUIA)
## Asignatura: Base de Datos II · Tecnicatura Universitaria en Programación (UTN)
### Unidad 8: Bases de Datos Móviles e Integración · TP N.º 8 (TP10)

**Estudiante / Integrante:** Cristian Rodriguez (`Cloverfield`)  
**Carrera:** Tecnicatura Universitaria en Programación  
**Ciclo Lectivo:** 2026  

---

### 1. Compromiso Ético y Alcance del Uso de IA
En cumplimiento de las directivas académicas de la cátedra de Base de Datos II sobre el uso responsable y ético de modelos de lenguaje basados en Inteligencia Artificial (IA Generativa), declaro que:

1. **Autoría y Responsabilidad Intelectual:**  
   Todo el código DDL, consultas SQL, scripts de prueba, especificaciones y justificaciones conceptuales volcadas en este proyecto fueron analizados, comprendidos, probados y verificados exhaustivamente en los motores de base de datos correspondientes (PostgreSQL 16+ y SQLite 3.37+). Como autor, asumo la responsabilidad plena de cada decisión técnica implementada y estoy en condiciones de defenderla de forma individual sin asistencia externa.
2. **Rol de la IA:**  
   La herramienta de IA actuó estrictamente como un asistente de paridad de programación (*pair programming*), asistencia en la redacción de especificaciones en formato formal EARS y revisión crítica de código (*code review*).
3. **Validación Experimental vs. Propuestas Automatizadas:**  
   Ninguna propuesta emitida por la IA fue incorporada a ciegas. Cada sugerencia fue sometida a comprobación empírica en el motor. Aquellas recomendaciones que comprometían la seguridad (como `GRANT ALL`), la integridad transaccional o el ciclo de vida del negocio (como restricciones `UNIQUE` indebidas en la cola móvil) fueron identificadas y descartadas con fundamento técnico riguroso.

---

### 2. Herramientas Utilizadas
* **Modelo / Plataforma:** Google Antigravity / OpenCode (Gemini 3.8 Flash High / Agentic Pipeline).
* **Entornos de Ejecución y Validación:**
  * SQLite 3.50.4 (Módulo nativo Python y motor embebido en Windows).
  * PostgreSQL 17.11 (psql, extensión `pgcrypto`).
  * Visual Studio Code / Terminal PowerShell.

---

### 3. Registro de Interacciones Significativas
Las interacciones principales, el análisis de sus respuestas y las decisiones de aceptación o rechazo fundado se encuentran minuciosamente detalladas en el documento complementario [`docs/bitacora_ia.md`](file:///d:/formateo%20win%2011/Estudios%20(Nuevo)/utn%20tec.%20programaci%C3%B3n/3%C2%B0%20Semestre/Base%20de%20Datos%202/Food-Store/docs/bitacora_ia.md).

---
**Firma del Estudiante:** Cristian Rodriguez  
**Fecha:** Noviembre de 2026
