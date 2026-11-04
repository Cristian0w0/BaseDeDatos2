import sqlite3
import os
import sys

DB_PATH = os.path.join(os.path.dirname(__file__), "foodstore_movil.db")
SCHEMA_PATH = os.path.join(os.path.dirname(__file__), "schema_sqlite.sql")
PRUEBAS_PATH = os.path.join(os.path.dirname(__file__), "pruebas_sqlite.sql")

def ejecutar():
    print(f"[*] Creando o reiniciando base de datos SQLite en: {DB_PATH}")
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # 1. Asegurar PRAGMA foreign_keys = ON
    cursor.execute("PRAGMA foreign_keys = ON;")
    cursor.execute("PRAGMA foreign_keys;")
    fk_status = cursor.fetchone()[0]
    print(f"[*] PRAGMA foreign_keys = {fk_status} (1 = Activado)")
    assert fk_status == 1, "Error: Las claves foráneas no están activas."

    # 2. Cargar esquema DDL
    print(f"[*] Ejecutando esquema DDL desde: {SCHEMA_PATH}")
    with open(SCHEMA_PATH, "r", encoding="utf-8") as f:
        schema_sql = f.read()
    cursor.executescript(schema_sql)
    print("    -> Tablas e índices creados exitosamente.")

    # 3. Cargar datos y ejecutar pruebas estándar
    print(f"[*] Ejecutando script de pruebas desde: {PRUEBAS_PATH}")
    with open(PRUEBAS_PATH, "r", encoding="utf-8") as f:
        pruebas_sql = f.read()
    
    # Ejecutamos el script de pruebas
    cursor.executescript(pruebas_sql)
    print("    -> Bloques de prueba básicos ejecutados correctamente.")

    # 4. Probar explícitamente los errores del caso C7
    print("\n[*] Ejecutando comprobación rigurosa del Caso C7:")

    # C7.a: Cantidad = 0
    try:
        cursor.execute("""
            INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
            VALUES ('aaaaaaaa-0000-4000-8000-000000000007', 1, 0, 900000);
        """)
        conn.commit()
        print("    [!] ERROR: Se esperaba fallo por CHECK (cantidad > 0) pero tuvo éxito.")
        sys.exit(1)
    except sqlite3.IntegrityError as e:
        print(f"    [OK] C7.a Rechazado correctamente por restricción CHECK: {e}")

    # C7.b: Producto inexistente
    try:
        cursor.execute("""
            INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
            VALUES ('aaaaaaaa-0000-4000-8000-000000000007', 9999, 1, 500000);
        """)
        conn.commit()
        print("    [!] ERROR: Se esperaba fallo por FOREIGN KEY pero tuvo éxito.")
        sys.exit(1)
    except sqlite3.IntegrityError as e:
        print(f"    [OK] C7.b Rechazado correctamente por restricción FOREIGN KEY: {e}")

    # Verificar que C7 quedó sin ítems
    cursor.execute("SELECT COUNT(*) FROM item_borrador WHERE id_local = 'aaaaaaaa-0000-4000-8000-000000000007';")
    count_c7 = cursor.fetchone()[0]
    print(f"    [OK] Filas de ítems persistidas para C7: {count_c7} (esperado: 0)")
    assert count_c7 == 0

    # 5. Resumen de estado de tablas
    print("\n[*] Estado de las tablas tras las pruebas de Consigna 1:")
    tablas = ["producto_cache", "pedido_borrador", "item_borrador", "cola_sync"]
    for t in tablas:
        cursor.execute(f"SELECT COUNT(*) FROM {t};")
        cnt = cursor.fetchone()[0]
        print(f"    - {t}: {cnt} fila(s)")

    # 6. Mostrar catálogo disponible (Caso C1)
    print("\n[*] Vista v_catalogo_disponible (Caso C1):")
    cursor.execute("SELECT producto_id, nombre, precio, stock_visto FROM v_catalogo_disponible;")
    for row in cursor.fetchall():
        print(f"    - ID: {row[0]} | {row[1]:<22} | Precio: ${row[2]:.2f} | Stock: {row[3]}")

    conn.close()
    print(f"\n[+] Todas las pruebas de la Consigna 1 fueron completadas con éxito.")
    print(f"[+] Archivo de base de datos generado: {DB_PATH}")

if __name__ == "__main__":
    ejecutar()
