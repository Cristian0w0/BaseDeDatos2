// ============================================================================
// BDII - Unidad 7: NoSQL y nuevas formas de almacenamiento (Food Store)
// Archivo: consultas_mongodb.js
// ============================================================================

// Seleccionar la base de datos de trabajo de forma compatible con scripts JS y REPL
db = db.getSiblingDB("foodstore_nosql");

// Limpiar la colección para garantizar idempotencia en la ejecución
db.pedidos.drop();

// ----------------------------------------------------------------------------
// Consigna 2: Migración e inserción de 5 pedidos con datos completos de Food Store
// Los registros corresponden a los primeros 5 pedidos reales generados en PostgreSQL,
// conservando identificadores, nombres reales de clientes y catálogo de productos,
// cantidades, precios históricos congelados y estados operativos.
// ----------------------------------------------------------------------------
db.pedidos.insertMany([
  {
    "_id": NumberLong("1"),
    "fecha_pedido": ISODate("2026-10-15T12:00:00Z"),
    "estado": "ENTREGADO",
    "forma_pago": "EFECTIVO",
    "total": 100.00,
    "cliente": {
      "cliente_id": NumberLong("1"),
      "nombre": "Cliente",
      "apellido": "Inicial",
      "email": "cliente.inicial@foodstore.local"
    },
    "lineas": [
      {
        "producto_id": NumberLong("1"),
        "nombre_producto": "Producto Inicial",
        "cantidad": 1,
        "precio_unitario": 100.00,
        "subtotal": 100.00
      }
    ]
  },
  {
    "_id": NumberLong("2"),
    "fecha_pedido": ISODate("2026-10-16T15:30:00Z"),
    "estado": "CONFIRMADO",
    "forma_pago": "TARJETA",
    "total": 200.00,
    "cliente": {
      "cliente_id": NumberLong("1"),
      "nombre": "Cliente",
      "apellido": "Inicial",
      "email": "cliente.inicial@foodstore.local"
    },
    "lineas": [
      {
        "producto_id": NumberLong("1"),
        "nombre_producto": "Producto Inicial",
        "cantidad": 2,
        "precio_unitario": 100.00,
        "subtotal": 200.00
      }
    ]
  },
  {
    "_id": NumberLong("3"),
    "fecha_pedido": ISODate("2026-10-17T18:45:00Z"),
    "estado": "PENDIENTE",
    "forma_pago": "TRANSFERENCIA",
    "total": 175.50,
    "cliente": {
      "cliente_id": NumberLong("2"),
      "nombre": "María",
      "apellido": "Rodríguez",
      "email": "cliente_tp3_1_95b1d53ffb2a549855fa5c14da0b5071@tp3-carga.foodstore.internal"
    },
    "lineas": [
      {
        "producto_id": NumberLong("2"),
        "nombre_producto": "Producto Bebida TP3 #1",
        "cantidad": 3,
        "precio_unitario": 58.50,
        "subtotal": 175.50
      }
    ]
  },
  {
    "_id": NumberLong("4"),
    "fecha_pedido": ISODate("2026-10-18T20:10:00Z"),
    "estado": "ENTREGADO",
    "forma_pago": "EFECTIVO",
    "total": 268.00,
    "cliente": {
      "cliente_id": NumberLong("3"),
      "nombre": "Carlos",
      "apellido": "Pérez",
      "email": "cliente_tp3_2_5bc78832d7964aa4897e23ea2caef89a@tp3-carga.foodstore.internal"
    },
    "lineas": [
      {
        "producto_id": NumberLong("3"),
        "nombre_producto": "Producto Bebida TP3 #2",
        "cantidad": 4,
        "precio_unitario": 67.00,
        "subtotal": 268.00
      }
    ]
  },
  {
    "_id": NumberLong("5"),
    "fecha_pedido": ISODate("2026-10-19T21:20:00Z"),
    "estado": "CONFIRMADO",
    "forma_pago": "TARJETA",
    "total": 377.50,
    "cliente": {
      "cliente_id": NumberLong("4"),
      "nombre": "Ana",
      "apellido": "González",
      "email": "cliente_tp3_3_a255f5f862a672eae5a91a7f8b924135@tp3-carga.foodstore.internal"
    },
    "lineas": [
      {
        "producto_id": NumberLong("4"),
        "nombre_producto": "Producto Bebida TP3 #3",
        "cantidad": 5,
        "precio_unitario": 75.50,
        "subtotal": 377.50
      }
    ]
  }
]);

// Verificación de cantidad de documentos insertados
print("Total de documentos en la colección pedidos: " + db.pedidos.countDocuments());

// ============================================================================
// Parte 2 – Consultas y verificación
// ============================================================================

print("\n--- Consigna 4a: Mostrar todos los pedidos, incluyendo su identificador y estado ---");
const consulta4a = db.pedidos.find(
  {}, 
  { _id: 1, estado: 1, total: 1, "cliente.nombre": 1, "cliente.apellido": 1 }
).sort({ _id: 1 }).toArray();
printjson(consulta4a);

print("\n--- Consigna 4b: Filtrar pedidos por un estado que exista (estado: 'ENTREGADO') ---");
const consulta4b = db.pedidos.find(
  { estado: "ENTREGADO" }, 
  { _id: 1, estado: 1, fecha_pedido: 1, forma_pago: 1, total: 1 }
).sort({ _id: 1 }).toArray();
printjson(consulta4b);

print("\n--- Consigna 4c: Buscar pedidos que contengan un producto determinado (producto_id: 1 - Producto Inicial) ---");
const consulta4c = db.pedidos.find(
  { "lineas.producto_id": NumberLong("1") },
  { _id: 1, estado: 1, "lineas.producto_id": 1, "lineas.nombre_producto": 1 }
).sort({ _id: 1 }).toArray();
printjson(consulta4c);

print("\n--- Consigna 4d: Buscar pedidos cuyo total sea superior a un importe elegido (total > $200.00) ---");
const consulta4d = db.pedidos.find(
  { total: { $gt: 200.00 } },
  { _id: 1, total: 1, "cliente.nombre": 1, "cliente.apellido": 1, "lineas.nombre_producto": 1 }
).sort({ _id: 1 }).toArray();
printjson(consulta4d);
