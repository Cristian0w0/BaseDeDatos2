// ============================================================================
// BDII - Unidad 7: NoSQL y nuevas formas de almacenamiento (Food Store)
// Archivo: consultas_mongodb.js
// ============================================================================

// Seleccionar la base de datos de trabajo de forma compatible con scripts JS y REPL
db = db.getSiblingDB("foodstore_nosql");

// Limpiar la colección para garantizar idempotencia en la ejecución
db.pedidos.drop();

// ----------------------------------------------------------------------------
// Consigna 2: Migración e inserción de 5 pedidos con datos completos
// ----------------------------------------------------------------------------
db.pedidos.insertMany([
  {
    "_id": NumberLong("1"),
    "fecha_pedido": ISODate("2026-10-10T12:30:00Z"),
    "estado": "ENTREGADO",
    "forma_pago": "EFECTIVO",
    "total": 6500.00,
    "cliente": {
      "cliente_id": NumberLong("1"),
      "nombre": "Carlos",
      "apellido": "González",
      "email": "carlos.gonzalez@example.com"
    },
    "lineas": [
      {
        "producto_id": NumberLong("1"),
        "nombre_producto": "Hamburguesa Clásica",
        "cantidad": 2,
        "precio_unitario": 2500.00,
        "subtotal": 5000.00
      },
      {
        "producto_id": NumberLong("4"),
        "nombre_producto": "Gaseosa Cola 500ml",
        "cantidad": 1,
        "precio_unitario": 1500.00,
        "subtotal": 1500.00
      }
    ]
  },
  {
    "_id": NumberLong("2"),
    "fecha_pedido": ISODate("2026-10-11T14:15:00Z"),
    "estado": "PENDIENTE",
    "forma_pago": "TARJETA",
    "total": 3500.00,
    "cliente": {
      "cliente_id": NumberLong("2"),
      "nombre": "Ana",
      "apellido": "Martínez",
      "email": "ana.martinez@example.com"
    },
    "lineas": [
      {
        "producto_id": NumberLong("2"),
        "nombre_producto": "Papas Fritas Medianas",
        "cantidad": 1,
        "precio_unitario": 2000.00,
        "subtotal": 2000.00
      },
      {
        "producto_id": NumberLong("4"),
        "nombre_producto": "Gaseosa Cola 500ml",
        "cantidad": 1,
        "precio_unitario": 1500.00,
        "subtotal": 1500.00
      }
    ]
  },
  {
    "_id": NumberLong("3"),
    "fecha_pedido": ISODate("2026-10-12T20:00:00Z"),
    "estado": "ENTREGADO",
    "forma_pago": "TRANSFERENCIA",
    "total": 11000.00,
    "cliente": {
      "cliente_id": NumberLong("3"),
      "nombre": "Lucía",
      "apellido": "Fernández",
      "email": "lucia.fernandez@example.com"
    },
    "lineas": [
      {
        "producto_id": NumberLong("1"),
        "nombre_producto": "Hamburguesa Clásica",
        "cantidad": 3,
        "precio_unitario": 2500.00,
        "subtotal": 7500.00
      },
      {
        "producto_id": NumberLong("3"),
        "nombre_producto": "Cerveza Artesanal IPA",
        "cantidad": 1,
        "precio_unitario": 3500.00,
        "subtotal": 3500.00
      }
    ]
  },
  {
    "_id": NumberLong("4"),
    "fecha_pedido": ISODate("2026-10-13T21:45:00Z"),
    "estado": "ENTREGADO",
    "forma_pago": "EFECTIVO",
    "total": 16500.00,
    "cliente": {
      "cliente_id": NumberLong("1"),
      "nombre": "Carlos",
      "apellido": "González",
      "email": "carlos.gonzalez@example.com"
    },
    "lineas": [
      {
        "producto_id": NumberLong("5"),
        "nombre_producto": "Pizza Especial Mozzarella",
        "cantidad": 2,
        "precio_unitario": 7000.00,
        "subtotal": 14000.00
      },
      {
        "producto_id": NumberLong("1"),
        "nombre_producto": "Hamburguesa Clásica",
        "cantidad": 1,
        "precio_unitario": 2500.00,
        "subtotal": 2500.00
      }
    ]
  },
  {
    "_id": NumberLong("5"),
    "fecha_pedido": ISODate("2026-10-14T13:10:00Z"),
    "estado": "CONFIRMADO",
    "forma_pago": "TARJETA",
    "total": 5500.00,
    "cliente": {
      "cliente_id": NumberLong("4"),
      "nombre": "Martín",
      "apellido": "Gómez",
      "email": "martin.gomez@example.com"
    },
    "lineas": [
      {
        "producto_id": NumberLong("2"),
        "nombre_producto": "Papas Fritas Medianas",
        "cantidad": 2,
        "precio_unitario": 2000.00,
        "subtotal": 4000.00
      },
      {
        "producto_id": NumberLong("4"),
        "nombre_producto": "Gaseosa Cola 500ml",
        "cantidad": 1,
        "precio_unitario": 1500.00,
        "subtotal": 1500.00
      }
    ]
  }
]);

// Verificación de cantidad de documentos insertados
print("Total de documentos en la colección pedidos: " + db.pedidos.countDocuments());

// ============================================================================
// Parte 2 � Consultas y verificaci�n
// ============================================================================

print("\n--- Consigna 4a: Mostrar todos los pedidos, incluyendo su identificador y estado ---");
const consulta4a = db.pedidos.find({}, { _id: 1, estado: 1, total: 1 }).toArray();
printjson(consulta4a);

print("\n--- Consigna 4b: Filtrar pedidos por un estado que exista (estado: 'ENTREGADO') ---");
const consulta4b = db.pedidos.find({ estado: "ENTREGADO" }, { _id: 1, estado: 1, total: 1 }).toArray();
printjson(consulta4b);

print("\n--- Consigna 4c: Buscar pedidos que contengan un producto determinado (producto_id: 1 - Hamburguesa Cl�sica) ---");
const consulta4c = db.pedidos.find(
  { "lineas.producto_id": NumberLong("1") },
  { _id: 1, estado: 1, "lineas.producto_id": 1, "lineas.nombre_producto": 1 }
).toArray();
printjson(consulta4c);

print("\n--- Consigna 4d: Buscar pedidos cuyo total sea superior a un importe elegido (total > $10.000) ---");
const consulta4d = db.pedidos.find(
  { total: { $gt: 10000.00 } },
  { _id: 1, total: 1, "cliente.nombre": 1, "cliente.apellido": 1 }
).toArray();
printjson(consulta4d);
