import sys
import zmq
import json
from datetime import datetime

def log(mensaje):
    ts = datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] [MONITOREO-CLIENTE] {mensaje}")

def mostrar_menu():
    print("\n" + "="*50)
    print("      SISTEMA DE GESTIÓN INTELIGENTE DE TRÁFICO")
    print("="*50)
    print("1. [CONSULTA] Verificar estado de la BD Principal")
    print("2. [PRIORIDAD] Forzar Ola Verde (Paso de Ambulancia)")
    print("3. Salir del sistema")
    print("="*50)

def main():
    if len(sys.argv) != 4:
        print("\n[ERROR] Parámetros insuficientes.")
        print("Uso correcto: python interfaz_monitoreo.py <ip_bd_pc3> <puerto_rep_bd> <puerto_rep_analitica>")
        print("Ejemplo local: python PC3_Monitoreo/interfaz_monitoreo.py 127.0.0.1 5560 5562\n")
        sys.exit(1)

    IP_BD             = sys.argv[1]
    PORT_REP_BD       = sys.argv[2]
    PORT_REP_ANALITICA = sys.argv[3]

    context = zmq.Context()

    
    socket_req_bd = context.socket(zmq.REQ)
    socket_req_bd.connect(f"tcp://{IP_BD}:{PORT_REP_BD}")
    socket_req_bd.setsockopt(zmq.RCVTIMEO, 2000)

    
    socket_req_analitica = context.socket(zmq.REQ)
    socket_req_analitica.connect(f"tcp://127.0.0.1:{PORT_REP_ANALITICA}")
    socket_req_analitica.setsockopt(zmq.RCVTIMEO, 2000)

    while True:
        mostrar_menu()
        opcion = input("Seleccione una opción de control distributed-ready (1-3): ").strip()

        if opcion == "1":
            print("\n--- SUB-MENÚ DE CONSULTAS HISTÓRICAS ---")
            print("A. Verificar estado y último ID global de la BD")
            print("B. Consultar registros por rango de tiempo (Hora Pico)")
            sub_op = input("Seleccione (A/B): ").strip().upper()
            
            if sub_op == "A":
                try:
                    socket_req_bd.send_string(json.dumps({"accion": "ping_estado"}))
                    respuesta = json.loads(socket_req_bd.recv_string())
                    print(f"\n[RESPUESTA BD]: Estado -> {respuesta.get('status')} | Último ID Secuencial: {respuesta.get('ultimo_id')}")
                except zmq.Again: log("[-] Error: Tiempo de espera agotado con PC3.")
                
            elif sub_op == "B":
                h_inicio = input("Ingrese hora de inicio (Format HH:MM:SS, Ej: 15:10:00): ").strip()
                h_fin    = input("Ingrese hora de fin    (Format HH:MM:SS, Ej: 15:25:00): ").strip()
                
                payload_q = {"accion": "consulta_historica", "hora_inicio": h_inicio, "hora_fin": h_fin}
                
                try:
                    socket_req_bd.send_string(json.dumps(payload_q))
                    respuesta = json.loads(socket_req_bd.recv_string())
                    registros = respuesta.get("datos", [])
                    
                    print(f"\n================ MÉTRICAS HISTÓRICAS ENCONTRADAS: {len(registros)} ================")
                    for r in registros:
                        print(f" ID: {r['id']} | {r['interseccion']} | Sensor: {r['sensor'].upper()} | Registrado a las: {r['ts']}")
                    print("="*70)
                except zmq.Again:
                    log("[-] Error: El servidor de persistencia histórica no responde.")

        elif opcion == "2":
            interseccion = input("Ingrese el identificador de la intersección a priorizar (Ej: INT_C3): ").strip().upper()
            log(f"Emitiendo indicación directa de OLA VERDE para {interseccion} hacia el PC2...")
            
            comando_prioritario = {
                "accion": "forzar_verde",
                "interseccion": interseccion,
                "motivo": "EMERGENCIA_AMBULANCIA: Priorización manual de vía solicitada por operador."
            }
            
            try:
                socket_req_analitica.send_string(json.dumps(comando_prioritario))
                respuesta = json.loads(socket_req_analitica.recv_string())
                print(f"\n[RESPUESTA ANALÍTICA]: Transición -> {respuesta.get('status')} | {respuesta.get('mensaje')}")
            except zmq.Again:
                log("[FALLO DETECTADO] El Servicio de Analítica (PC2) no se encuentra disponible.")

        elif opcion == "3":
            print("\nCerrando consola de monitoreo. Liberando sockets...")
            break
        else:
            print("\n[ADVERTENCIA] Opción inválida. Elija 1, 2 o 3.")

    socket_req_bd.close()
    socket_req_analitica.close()
    context.term()

if __name__ == "__main__":
    main()