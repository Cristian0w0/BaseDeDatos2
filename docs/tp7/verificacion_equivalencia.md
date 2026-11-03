# Verificación de Equivalencia y Protección de Datos Personales (TP7 - Parte D)

## Proyecto: Food Store — Base de Datos II (UTN)
**Materia:** Base de Datos II  
**Ciclo Lectivo:** 2026  
**Marco Legal:** Ley 25.326 de Protección de los Datos Personales (Argentina) / RGPD  

---

### 1. Consultas de Agregación Equivalentes

Para verificar que el proceso de anonimización determinista no distorsiona las conclusiones estadísticas que la base de datos ofrece en conjunto, se formularon dos consultas analíticas equivalentes sobre [`db/usuario_anon.sql`](file:///d:/formateo%20win%2011/Estudios%20(Nuevo)/utn%20tec.%20programación/3°%20Semestre/Base%20de%20Datos%202/Food-Store/db/usuario_anon.sql):

#### Consulta sobre `usuario` (Datos de Producción)
```sql
SELECT
    'usuario_real' AS origen_datos,
    rol,
    to_char(created_at AT TIME ZONE 'America/Argentina/Buenos_Aires', 'YYYY-MM') AS mes_alta,
    COUNT(*) AS total_usuarios,
    COUNT(DISTINCT mail) AS total_emails_unicos
FROM usuario
GROUP BY
    rol,
    to_char(created_at AT TIME ZONE 'America/Argentina/Buenos_Aires', 'YYYY-MM')
ORDER BY rol, mes_alta;
```

#### Consulta sobre `usuario_anon` (Dataset Anonimizado para IA)
```sql
SELECT
    'usuario_anon' AS origen_datos,
    rol,
    to_char(created_at AT TIME ZONE 'America/Argentina/Buenos_Aires', 'YYYY-MM') AS mes_alta,
    COUNT(*) AS total_usuarios,
    COUNT(DISTINCT mail) AS total_emails_unicos
FROM usuario_anon
GROUP BY
    rol,
    to_char(created_at AT TIME ZONE 'America/Argentina/Buenos_Aires', 'YYYY-MM')
ORDER BY rol, mes_alta;
```

---

### 2. Evidencia de Resultados Agregados (Comparación Lado a Lado)

A continuación se presentan los resultados comparados de ambas consultas:

```text
==================================================================================================
RESULTADO: usuario (Tabla Real)
 origen_datos |   rol   | mes_alta | total_usuarios | total_emails_unicos
--------------+---------+----------+----------------+---------------------
 usuario_real | ADMIN   | 2026-11  |              1 |                   1
 usuario_real | USUARIO | 2026-11  |              2 |                   2
(2 rows)

==================================================================================================
RESULTADO: usuario_anon (Tabla Anonimizada)
 origen_datos |   rol   | mes_alta | total_usuarios | total_emails_unicos
--------------+---------+----------+----------------+---------------------
 usuario_anon | ADMIN   | 2026-11  |              1 |                   1
 usuario_anon | USUARIO | 2026-11  |              2 |                   2
(2 rows)
```

#### Análisis de la Equivalencia:
- **Conteos por categoría idénticos:** La cantidad total de registros agrupados por rol (`ADMIN: 1`, `USUARIO: 2`) es exactamente la misma en ambas tablas.
- **Cardinalidad preservada:** La expresión sintética determinista `'usuario' || id || '@ejemplo.test'` aseguró que la cantidad de correos únicos (`COUNT(DISTINCT mail)`) coincida con los de producción.
- **Alineación temporal perfecta:** Las marcas temporales `created_at` no fueron modificadas, manteniendo la distribución mensual requerida para análisis de cohortes o crecimiento.

---

### 3. Pregunta Escrita Obligatoria

> **Consigna:** Redactar, en dos o tres oraciones, qué información concreta de Food Store no debería salir nunca hacia un asistente de IA sin pasar antes por este proceso de anonimización.

Bajo ninguna circunstancia deben enviarse hacia un asistente de IA las filas reales de la tabla `usuario` conteniendo datos directamente identificatorios como **nombres, apellidos, direcciones de correo electrónico personales y números de teléfono celular**, ya que constituyen datos personales protegidos por la Ley 25.326. Asimismo, queda estrictamente prohibida la exportación de **contraseñas (incluso bajo su representación hasheada)**, datos de medios de pago o extractos de logs de auditoría en texto crudo que vinculen identidades humanas con IPs o actividades transaccionales. El uso de inteligencia artificial debe realizarse de forma exclusiva sobre datasets sintéticos como `usuario_anon` o sobre trazas debidamente tokenizadas.
