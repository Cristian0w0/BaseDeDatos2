# Especificación de Requerimientos de Seguridad y Control de Acceso (Kiro Spec)

## Proyecto: Food Store — Base de Datos II (UTN)
**Módulo:** Gestión de Identidades, Permisos Granulares y Roles (TP7 - Parte A)  
**Motor:** PostgreSQL 16+  
**Autor:** Equipo de Desarrollo y DBA  

---

### 1. Visión General del Sistema y Contexto Operativo
La plataforma Food Store opera en un entorno relacional multiusuario donde convergen diversos actores técnicos y humanos:
1. Clientes que navegan el catálogo y realizan pedidos desde la aplicación web backend.
2. Operadores de soporte y atención al cliente que consultan estados y resuelven reclamos.
3. Analistas de negocio y gerencia que monitorean métricas de ventas agregadas.
4. Repartidores / personal logístico que actualizan el ciclo de entrega.
5. Administradores de base de datos (DBA) que mantienen la infraestructura y el esquema.

Históricamente, el sistema operaba bajo una identidad monousuario con privilegios plenos (`postgres` / dueño de base), lo que expone a la organización al riesgo de daño catastrófico ante inyección de SQL o filtración de credenciales. Se requiere aplicar el **Principio de Mínimo Privilegio (NIST SP 800-53 / Saltzer & Schroeder)** para limitar las facultades de cada conexión estrictamente a su cometido operativo.

---

### 2. Requerimientos de Identidades y Roles

#### 2.1. Roles Funcionales / de Grupo (NOLOGIN)
Los roles de grupo no pueden iniciar sesión directamente; agrupan privilegios según funciones del negocio:

- **REQ-ROL-01 (`rol_app_lectura`):** Habilita la lectura exclusiva del catálogo público vigente de productos y categorías para permitir la navegación de los clientes sin exponer registros inactivos ni permitir escrituras.
- **REQ-ROL-02 (`rol_app_escritura`):** Habilita la consulta, inserción y modificación de pedidos y sus líneas de detalle, así como la ejecución del procedimiento transaccional `sp_crear_pedido`, revocando explícitamente `DELETE` y `TRUNCATE` para asegurar el borrado lógico y la preservación de la auditoría.
- **REQ-ROL-03 (`rol_soporte`):** Habilita la consulta de la identidad básica de usuarios y resúmenes de pedidos para la resolución de incidentes operativos, prohibiendo estrictamente el acceso a contraseñas y teléfonos de los usuarios.
- **REQ-ROL-04 (`rol_reportes`):** Habilita la consulta de sólo lectura sobre vistas materializadas y reportes analíticos periódicos para la toma de decisiones gerenciales, aislando las tablas transaccionales en vivo.
- **REQ-ROL-05 (`rol_repartidor` - Rol Ampliado):** Habilita la actualización puntual del estado logístico del pedido sin permitir modificaciones sobre precios, productos ni datos personales del cliente.

#### 2.2. Roles de Conexión / Login (LOGIN)
Identidades autenticadas mediante contraseñas robustas cifradas (SCRAM-SHA-256):

- **REQ-USR-01 (`app_web`):** Rol técnico de backend consumido por la API de la aplicación. Debe pertenecer jerárquicamente a `rol_app_lectura` y `rol_app_escritura`, con límite de conexiones concurrentes (`CONNECTION LIMIT 50`) y expiración de credencial para forzar rotación.
- **REQ-USR-02 (`admin_datos`):** Identidad para el DBA responsable del mantenimiento y despliegue del esquema. Debe poseer `CREATEDB` y `CREATEROLE`, pero **bajo ninguna circunstancia poseer `SUPERUSER`**, asegurando que sus acciones queden sujetas a auditoría y políticas de motor.
- **REQ-USR-03 (`analista_soporte`):** Cuenta individual asignada al operador de mesa de ayuda, miembro de `rol_soporte`, con auditoría individualizada de conexiones.

---

### 3. Requerimientos de Seguridad Granular

- **REQ-SEC-01 (Acceso al Esquema):** Todo rol debe contar con el privilegio explícito `USAGE ON SCHEMA public` antes de acceder a cualquier objeto relacional.
- **REQ-SEC-02 (Proyección Restringida por Columna):** Cuando una tabla contenga datos sensibles (`usuario`), el rol `rol_soporte` solo podrá proyectar las columnas `(id, nombre, apellido, mail, rol)`, bloqueando accesos a `contrasena` y `celular`.
- **REQ-SEC-03 (Seguridad a Nivel de Fila - RLS):** La tabla transaccional `pedido` debe contar con Row-Level Security habilitado para que los roles transaccionales solo visualicen u operen pedidos asociados al cliente fijado en la variable de sesión `app.usuario_actual`.
- **REQ-SEC-04 (Herencia Automática de Privilegios Futuros):** Debe definirse `ALTER DEFAULT PRIVILEGES` para que cualquier vista o tabla analítica futura creada por `admin_datos` otorgue automáticamente lectura a `rol_reportes` sin requerir intervención manual urgente.
- **REQ-SEC-05 (Defensa en Profundidad):** Las funciones que requieran facultades elevadas (`fn_resetear_password`) deben implementarse con `SECURITY DEFINER`, esquema seguro fijado (`search_path = public, pg_temp`) y ejecución restringida únicamente al rol autorizado.
