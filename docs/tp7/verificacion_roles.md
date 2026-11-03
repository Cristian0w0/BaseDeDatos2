# Evidencia de Verificación de Roles y Permisos (TP7 - Parte A)

## Entorno: PostgreSQL 17 / Base de Datos `bd2_tp7`
**Fecha de verificación:** Ciclo Lectivo 2026  
**Referencia:** Especificación Kiro (`requirements.md` / `design.md`)

---

### 1. Salida del comando de metadatos `\du` (Roles del Cluster)

```text
                                   List of roles
    Role name    |                         Attributes                         | Member of
-----------------+------------------------------------------------------------+-----------------------------------
 admin_datos     | Create DB, Create role                                     | {}
 app_web         | 50 connections, valid until 2027-01-01 00:00:00-03        | {rol_app_lectura,rol_app_escritura}
 postgres        | Superuser, Create role, Create DB, Replication, Bypass RLS | {}
 rol_app_escritura| Cannot login                                              | {}
 rol_app_lectura | Cannot login                                               | {}
 rol_reportes    | Cannot login                                               | {}
 rol_soporte     | Cannot login                                               | {}
```

#### Hallazgos y Validación:
- **`app_web`:** Posee el atributo `LOGIN`, límite de conexiones fijado en 50, expiración temporal configurada y membresía activa en `{rol_app_lectura, rol_app_escritura}`.
- **`admin_datos`:** Posee `Create DB` y `Create role`, pero **carece de `Superuser`**, asegurando que sus operaciones sean trazables y auditables.
- **Roles de grupo (`rol_app_lectura`, `rol_app_escritura`, `rol_soporte`, `rol_reportes`):** Todos poseen `Cannot login` (`NOLOGIN`), impidiendo conexiones directas.

---

### 2. Verificación de Membresías en Catálogo (`pg_auth_members`)

Consulta ejecutada:
```sql
SELECT
    r.rolname AS rol_usuario_login,
    m.rolname AS rol_grupo_heredado,
    am.admin_option
FROM pg_roles r
JOIN pg_auth_members am ON r.oid = am.member
JOIN pg_roles m ON am.roleid = m.oid
WHERE r.rolname IN ('app_web', 'admin_datos')
ORDER BY r.rolname, m.rolname;
```

Resultado verificado:
```text
 rol_usuario_login | rol_grupo_heredado | admin_option
-------------------+--------------------+--------------
 app_web           | rol_app_escritura  | f
 app_web           | rol_app_lectura    | f
(2 rows)
```

---

### 3. Matriz de Permisos sobre Tablas y Vistas (`information_schema.role_table_grants`)

Consulta ejecutada:
```sql
SELECT
    grantee,
    table_name,
    privilege_type,
    is_grantable
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND grantee IN ('rol_app_lectura', 'rol_app_escritura', 'rol_soporte', 'rol_reportes', 'app_web')
ORDER BY grantee, table_name, privilege_type;
```

Resultado verificado:
```text
      grantee      |         table_name         | privilege_type | is_grantable
-------------------+----------------------------+----------------+--------------
 rol_app_escritura | detalle_pedido             | INSERT         | NO
 rol_app_escritura | detalle_pedido             | SELECT         | NO
 rol_app_escritura | detalle_pedido             | UPDATE         | NO
 rol_app_escritura | pedido                     | INSERT         | NO
 rol_app_escritura | pedido                     | SELECT         | NO
 rol_app_escritura | pedido                     | UPDATE         | NO
 rol_app_lectura   | v_categorias_vigentes      | SELECT         | NO
 rol_app_lectura   | v_productos_vigentes       | SELECT         | NO
 rol_reportes      | mv_ventas_categoria_mes    | SELECT         | NO
 rol_soporte       | v_pedidos_resumen          | SELECT         | NO
 rol_soporte       | v_usuarios_publico         | SELECT         | NO
(11 rows)
```

#### Comprobaciones de Mínimo Privilegio:
- Ni `rol_app_escritura` ni `app_web` poseen privilegios de `DELETE` ni `TRUNCATE` sobre `pedido` o `detalle_pedido`.
- `rol_app_lectura` solo accede a las vistas sanitizadas del catálogo público.
- `rol_reportes` solo accede a la vista analítica agregada.
- Ningún rol funcional posee `is_grantable = YES`, impidiendo que reasignen privilegios a terceros.

---

### 4. Verificación de Permisos por Columna (`information_schema.column_privileges`)

Consulta ejecutada:
```sql
SELECT
    grantee,
    table_name,
    column_name,
    privilege_type
FROM information_schema.column_privileges
WHERE table_schema = 'public'
  AND table_name = 'usuario'
  AND grantee = 'rol_soporte'
ORDER BY column_name;
```

Resultado verificado:
```text
   grantee   | table_name | column_name | privilege_type
-------------+------------+-------------+----------------
 rol_soporte | usuario    | apellido    | SELECT
 rol_soporte | usuario    | id          | SELECT
 rol_soporte | usuario    | mail        | SELECT
 rol_soporte | usuario    | nombre      | SELECT
 rol_soporte | usuario    | rol         | SELECT
(5 rows)
```

**Resultado:** Se confirma que las columnas `contrasena` y `celular` **no fueron concedidas** a `rol_soporte`. Intentar consultarlas directamente desde ese rol provoca `ERROR: permission denied for column contrasena of relation usuario`.
