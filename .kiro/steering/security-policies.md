---
inclusion: always
---

# Políticas de seguridad

Estas reglas deben respetarse en todo momento al trabajar sobre este proyecto de Base de Datos 2.

## 1. Protección de credenciales y secretos

* No incluir contraseñas, tokens, claves API u otros secretos directamente en el código o en archivos versionados.
* Utilizar variables de entorno para información sensible.
* No modificar ni eliminar `.gitignore` para permitir el versionado de archivos que contengan secretos.

## 2. Consultas a la base de datos

* Utilizar consultas parametrizadas cuando se trabaje desde código o aplicaciones.
* No construir consultas SQL mediante concatenación directa de valores proporcionados por usuarios.
* Validar los datos de entrada antes de utilizarlos en operaciones sobre la base de datos.

## 3. Manejo de errores

* No exponer al usuario final mensajes internos de PostgreSQL, credenciales, consultas completas ni información sensible de la estructura de la base de datos.
* Los errores deben registrarse de forma controlada cuando corresponda.

## 4. Cambios sobre la base de datos

* Trabajar únicamente sobre la base de datos de desarrollo `tp_bd2_trabajo`.
* No ejecutar cambios destructivos sobre una base de datos real o de referencia sin autorización explícita.
* Antes de cambios estructurales importantes, realizar un respaldo de la base de trabajo.
* Probar las modificaciones dentro de una transacción cuando sea posible y utilizar `ROLLBACK` durante las pruebas.

## 5. Uso de inteligencia artificial

* La IA puede generar código, consultas y documentación, pero las decisiones técnicas deben ser revisadas y aprobadas por el estudiante.
* Ninguna modificación generada por IA debe ejecutarse sobre la base de datos sin ser revisada y probada previamente.
* No asumir que una respuesta generada por IA es correcta sin verificarla contra el esquema y el comportamiento real de PostgreSQL.