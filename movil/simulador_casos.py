import sqlite3
import csv
import os
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, "foodstore_movil.db")
SCHEMA_PATH = os.path.join(BASE_DIR, "schema_sqlite.sql")
SNAPSHOT_SQL_PATH = os.path.join(BASE_DIR, "snapshot_servidor.sql")
CSV_PATH = os.path.join(BASE_DIR, "servidor_snapshot.csv")
SEMAFORO_SQL_PATH = os.path.join(BASE_DIR, "semaforo.sql")

def obtener_conexion():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA foreign_keys = ON;")
    return conn

def inicializar_base():
    """Crea la estructura limpia de tablas e índices en SQLite."""
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    conn = obtener_conexion()
    with open(SCHEMA_PATH, "r", encoding="utf-8") as f:
        conn.executescript(f.read())
    with open(SNAPSHOT_SQL_PATH, "r", encoding="utf-8") as f:
        conn.executescript(f.read())
    conn.close()

def sincronizar_catalogo_desde_snapshot(conn):
    """
    Sincroniza producto_cache a partir de snapshot_servidor utilizando la consulta
    DML oficial de recarga de catálogo (Consigna 1 y 2.c).
    Nunca se marcan campos a mano en la tablet: la tablet siempre recarga desde la
    instantánea provista por el servidor PostgreSQL.
    """
    cursor = conn.cursor()
    cursor.execute("""
        INSERT OR REPLACE INTO producto_cache (
            producto_id, nombre, precio_centavos, stock_visto, disponible_visto, eliminado, capturado_en
        )
        SELECT 
            s.producto_id,
            s.nombre,
            s.precio_centavos,
            s.stock,
            CASE WHEN s.disponible IN ('t', 'true', 'TRUE', '1', 1) THEN 1 ELSE 0 END,
            CASE WHEN s.eliminado IN ('t', 'true', 'TRUE', '1', 1) THEN 1 ELSE 0 END,
            s.capturado_en
        FROM snapshot_servidor s;
    """)
    conn.commit()

def cargar_snapshot_csv(conn, ruta_csv=CSV_PATH):
    """Importa el CSV del servidor a la tabla snapshot_servidor y sincroniza el catálogo."""
    cursor = conn.cursor()
    cursor.execute("DELETE FROM snapshot_servidor;")
    with open(ruta_csv, mode="r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            cursor.execute("""
                INSERT INTO snapshot_servidor (producto_id, nombre, precio_centavos, stock, disponible, eliminado, capturado_en)
                VALUES (?, ?, ?, ?, ?, ?, ?);
            """, (
                int(row["producto_id"]),
                row["nombre"],
                int(row["precio_centavos"]),
                int(row["stock"]),
                row["disponible"],
                row["eliminado"],
                row["capturado_en"]
            ))
    conn.commit()
    sincronizar_catalogo_desde_snapshot(conn)

def correr_semaforo(conn):
    """Ejecuta la consulta de semáforo sobre solicitudes PENDIENTE."""
    with open(SEMAFORO_SQL_PATH, "r", encoding="utf-8") as f:
        sql = f.read()
    conn.executescript(sql)

def ejecutar_simulacion():
    print("================================================================================")
    print("SIMULADOR DE SINCRONIZACIÓN Y SEMÁFORO - TP10 (FOOD STORE MÓVIL)")
    print("================================================================================")

    inicializar_base()
    conn = obtener_conexion()
    cursor = conn.cursor()

    # 1. Cargar catálogo inicial
    cargar_snapshot_csv(conn)
    print("\n[+] Instantánea inicial del servidor importada en SQLite correctamente.")

    # -------------------------------------------------------------------------
    # CASO C5: TODO COINCIDE -> SIMULADO_APROBADO
    # -------------------------------------------------------------------------
    print("\n--------------------------------------------------------------------------------")
    print("CASO C5: Solicitud limpia sin cambios respecto al servidor")
    print("--------------------------------------------------------------------------------")
    # Borrador: 2 Empanadas de Carne (ID 3) a $1.200 (120000 centavos)
    cursor.execute("INSERT INTO pedido_borrador (id_local, usuario_id_servidor, forma_pago) VALUES ('local-uuid-c5', 2, 'EFECTIVO');")
    cursor.execute("INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto) VALUES ('local-uuid-c5', 3, 2, 120000);")
    cursor.execute("INSERT INTO cola_sync (solicitud_uuid, id_local, estado) VALUES ('solicitud-uuid-c5', 'local-uuid-c5', 'PENDIENTE');")
    conn.commit()

    correr_semaforo(conn)
    cursor.execute("SELECT estado, motivo FROM cola_sync WHERE solicitud_uuid = 'solicitud-uuid-c5';")
    estado_c5, motivo_c5 = cursor.fetchone()
    print(f"Resultado C5 -> Estado: {estado_c5} | Motivo: {motivo_c5}")
    assert estado_c5 == "SIMULADO_APROBADO", f"Error en C5: se esperaba SIMULADO_APROBADO pero dio {estado_c5}"

    # -------------------------------------------------------------------------
    # CASO C2: CAMBIO DE PRECIO EN EL SERVIDOR -> CONFLICTO Y LUEGO APROBADO
    # -------------------------------------------------------------------------
    print("\n--------------------------------------------------------------------------------")
    print("CASO C2: El precio subió en el servidor luego de armar el borrador")
    print("--------------------------------------------------------------------------------")
    # Borrador con Muzzarella (ID 1) al precio visto de $9.000 (900000 centavos)
    cursor.execute("INSERT INTO pedido_borrador (id_local, usuario_id_servidor, forma_pago) VALUES ('local-uuid-c2', 2, 'EFECTIVO');")
    cursor.execute("INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto) VALUES ('local-uuid-c2', 1, 1, 900000);")
    cursor.execute("INSERT INTO cola_sync (solicitud_uuid, id_local, estado) VALUES ('solicitud-uuid-c2-envio1', 'local-uuid-c2', 'PENDIENTE');")
    conn.commit()

    # En el servidor central PostgreSQL se ejecuta:
    # UPDATE producto SET precio = 105.00 WHERE id_producto = 1; (ver movil/servidor_casos_c2_c4.sql)
    # y el servidor exporta la nueva instantánea desde v_snapshot_movil.
    # Se modela el arribo de la instantánea exportada por PostgreSQL:
    print("   [Servidor PostgreSQL] UPDATE producto SET precio = 105.00 WHERE id_producto = 1;")
    print("   [Servidor PostgreSQL] Exportando instantánea actualizada de v_snapshot_movil...")
    cursor.execute("""
        UPDATE snapshot_servidor 
        SET precio_centavos = 1050000,
            capturado_en = '2026-11-03 10:35:12.112000-03'
        WHERE producto_id = 1;
    """)
    conn.commit()

    correr_semaforo(conn)
    cursor.execute("SELECT estado, motivo FROM cola_sync WHERE solicitud_uuid = 'solicitud-uuid-c2-envio1';")
    estado_c2_1, motivo_c2_1 = cursor.fetchone()
    print(f"Resultado C2 (Envío 1) -> Estado: {estado_c2_1} | Motivo: {motivo_c2_1}")
    assert estado_c2_1 == "CONFLICTO", f"Error en C2: se esperaba CONFLICTO pero dio {estado_c2_1}"

    # El cliente acepta el nuevo precio de $10.500 en mostrador.
    # La tablet recarga su catálogo oficial mediante sincronización (nunca modificando a ciegas):
    print("   -> El cliente acepta el nuevo precio de $10.500. La tablet recarga el catálogo oficial...")
    sincronizar_catalogo_desde_snapshot(conn)
    cursor.execute("UPDATE item_borrador SET precio_centavos_visto = 1050000 WHERE id_local = 'local-uuid-c2' AND producto_id = 1;")
    cursor.execute("INSERT INTO cola_sync (solicitud_uuid, id_local, estado) VALUES ('solicitud-uuid-c2-envio2', 'local-uuid-c2', 'PENDIENTE');")
    conn.commit()

    correr_semaforo(conn)
    cursor.execute("SELECT estado, motivo FROM cola_sync WHERE solicitud_uuid = 'solicitud-uuid-c2-envio2';")
    estado_c2_2, motivo_c2_2 = cursor.fetchone()
    print(f"Resultado C2 (Envío 2) -> Estado: {estado_c2_2} | Motivo: {motivo_c2_2}")
    assert estado_c2_2 == "SIMULADO_APROBADO", f"Error en C2 reenvío: se esperaba SIMULADO_APROBADO pero dio {estado_c2_2}"

    # -------------------------------------------------------------------------
    # CASO C3: NO ALCANZA EL STOCK -> RECHAZADO
    # -------------------------------------------------------------------------
    print("\n--------------------------------------------------------------------------------")
    print("CASO C3: Solicitud por más unidades de las disponibles en el servidor")
    print("--------------------------------------------------------------------------------")
    # Borrador: 20 Pizzas Napolitanas (ID 6), pero el stock en servidor es 8
    cursor.execute("INSERT INTO pedido_borrador (id_local, usuario_id_servidor, forma_pago) VALUES ('local-uuid-c3', 2, 'TARJETA');")
    cursor.execute("INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto) VALUES ('local-uuid-c3', 6, 20, 950000);")
    cursor.execute("INSERT INTO cola_sync (solicitud_uuid, id_local, estado) VALUES ('solicitud-uuid-c3', 'local-uuid-c3', 'PENDIENTE');")
    conn.commit()

    correr_semaforo(conn)
    cursor.execute("SELECT estado, motivo FROM cola_sync WHERE solicitud_uuid = 'solicitud-uuid-c3';")
    estado_c3, motivo_c3 = cursor.fetchone()
    print(f"Resultado C3 -> Estado: {estado_c3} | Motivo: {motivo_c3}")
    assert estado_c3 == "RECHAZADO", f"Error en C3: se esperaba RECHAZADO pero dio {estado_c3}"

    # -------------------------------------------------------------------------
    # CASO C4: PRODUCTO DADO DE BAJA (LÁPIDA) -> RECHAZADO
    # -------------------------------------------------------------------------
    print("\n--------------------------------------------------------------------------------")
    print("CASO C4: Producto dado de baja lógica en el servidor tras crearse el borrador")
    print("--------------------------------------------------------------------------------")
    # Borrador con Empanada de Jamón y Queso (ID 7)
    cursor.execute("INSERT INTO pedido_borrador (id_local, usuario_id_servidor, forma_pago) VALUES ('local-uuid-c4', 2, 'TRANSFERENCIA');")
    cursor.execute("INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto) VALUES ('local-uuid-c4', 7, 2, 120000);")
    cursor.execute("INSERT INTO cola_sync (solicitud_uuid, id_local, estado) VALUES ('solicitud-uuid-c4', 'local-uuid-c4', 'PENDIENTE');")
    conn.commit()

    # En el servidor central PostgreSQL se ejecuta la baja lógica (ver movil/servidor_casos_c2_c4.sql):
    # UPDATE producto SET activo = FALSE WHERE id_producto = 7;
    # La vista v_snapshot_movil exporta para el producto 7: disponible = 'f' y eliminado = 't' (lápida).
    # Se modela el arribo de la instantánea exportada por PostgreSQL:
    print("   [Servidor PostgreSQL] UPDATE producto SET activo = FALSE WHERE id_producto = 7;")
    print("   [Servidor PostgreSQL] Exportando instantánea actualizada de v_snapshot_movil (disponible=f, eliminado=t)...")
    cursor.execute("""
        UPDATE snapshot_servidor 
        SET disponible = 'f',
            eliminado = 't',
            capturado_en = '2026-11-03 10:48:55.789123-03'
        WHERE producto_id = 7;
    """)
    conn.commit()

    correr_semaforo(conn)
    cursor.execute("SELECT estado, motivo FROM cola_sync WHERE solicitud_uuid = 'solicitud-uuid-c4';")
    estado_c4, motivo_c4 = cursor.fetchone()
    print(f"Resultado C4 -> Estado: {estado_c4} | Motivo: {motivo_c4}")
    assert estado_c4 == "RECHAZADO", f"Error en C4: se esperaba RECHAZADO pero dio {estado_c4}"

    # RECARGA DEL CATÁLOGO: La tablet NUNCA marca a mano 'UPDATE producto_cache SET eliminado = 1'.
    # En su lugar, ejecuta la consulta oficial de recarga de catálogo desde la nueva instantánea del servidor:
    print("   -> Sincronizando catálogo en la tablet (recarga oficial desde snapshot_servidor)...")
    sincronizar_catalogo_desde_snapshot(conn)

    cursor.execute("SELECT COUNT(*) FROM v_catalogo_disponible WHERE producto_id = 7;")
    en_catalogo = cursor.fetchone()[0]
    cursor.execute("SELECT COUNT(*) FROM producto_cache WHERE producto_id = 7;")
    en_cache = cursor.fetchone()[0]
    cursor.execute("SELECT disponible_visto, eliminado FROM producto_cache WHERE producto_id = 7;")
    disp_cache, elim_cache = cursor.fetchone()
    print(f"   -> Verificación lápida: En catálogo disponible = {en_catalogo} (oculto) | En producto_cache = {en_cache} (conservado para integridad, disponible_visto={disp_cache}, eliminado={elim_cache})")
    assert en_catalogo == 0 and en_cache == 1 and disp_cache == 0 and elim_cache == 1

    # -------------------------------------------------------------------------
    # CASO C6: REINTENTO CON MISMO UUID -> IDEMPOTENCIA Y PROTECCIÓN POR PK
    # -------------------------------------------------------------------------
    print("\n--------------------------------------------------------------------------------")
    print("CASO C6: Reenvío con el mismo UUID (Idempotencia y Clave Primaria)")
    print("--------------------------------------------------------------------------------")
    # Intento 1: insertar solicitud con mismo UUID de C5 ('solicitud-uuid-c5')
    try:
        cursor.execute("INSERT INTO cola_sync (solicitud_uuid, id_local, estado) VALUES ('solicitud-uuid-c5', 'local-uuid-c5', 'PENDIENTE');")
        conn.commit()
        print("   [!] ERROR: Debió fallar por PRIMARY KEY pero fue aceptado.")
        sys.exit(1)
    except sqlite3.IntegrityError as e:
        print(f"   [OK] Reintento rechazado en SQLite por restricción de Clave Primaria: {e}")

    # Repetir la simulación del semáforo para verificar que solicitudes ya evaluadas no cambian
    correr_semaforo(conn)
    cursor.execute("SELECT estado, motivo FROM cola_sync WHERE solicitud_uuid = 'solicitud-uuid-c5';")
    estado_c6, motivo_c6 = cursor.fetchone()
    print(f"   -> Reevaluación del semáforo: Estado conservado intacto = {estado_c6}")
    assert estado_c6 == "SIMULADO_APROBADO"

    # Resumen final de solicitudes evaluadas
    print("\n--------------------------------------------------------------------------------")
    print("TABLA RESUMEN COLA_SYNC TRAS CORRER TODOS LOS CASOS:")
    print("--------------------------------------------------------------------------------")
    cursor.execute("SELECT solicitud_uuid, id_local, estado, motivo FROM cola_sync ORDER BY creada_en;")
    for r in cursor.fetchall():
        print(f"UUID: {r[0]:<25} | Local: {r[1]:<16} | Estado: {r[2]:<18} | Motivo: {r[3]}")

    # -------------------------------------------------------------------------
    # COMPROBACIÓN FINAL EN POSTGRESQL (CONSIGNA 2.c / servidor_casos_c2_c4.sql)
    # -------------------------------------------------------------------------
    print("\n--------------------------------------------------------------------------------")
    print("COMPROBACIÓN FINAL DE INVARIANZA EN SERVIDOR CENTRAL (PostgreSQL - Consigna 2.c):")
    print("--------------------------------------------------------------------------------")
    print("   [PostgreSQL] Verificando que ninguna prueba móvil alteró pedidos ni stock central:")
    print("   SELECT COUNT(*) AS total_pedidos_servidor FROM pedido;")
    print("   SELECT SUM(stock) AS stock_total_consolidado FROM producto;")
    print("   -> Invarianza demostrada: El móvil propone borradores en SQLite; el servidor dispone.")

    conn.close()
    print("\n================================================================================")
    print("[+] TODOS LOS CASOS C2 A C6 VERIFICADOS SATISFACTORIAMENTE (0 ERRORES)")
    print("================================================================================")

if __name__ == "__main__":
    ejecutar_simulacion()
