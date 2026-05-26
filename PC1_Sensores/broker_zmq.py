import sys
import zmq
from datetime import datetime

def log(mensaje):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    print(f"[{ts}] [BROKER-ZMQ] {mensaje}")

def main():
    if len(sys.argv) != 4:
        print("\n[ERROR] Parámetros incorrectos.")
        print("Uso correcto:")
        print("  python3 broker_zmq.py <ip_interfaz> <puerto_sensores_xsub> <puerto_analitica_xpub>")
        print("Ejemplo de despliegue físico distribuido (Interfaces de red internas):")
        print("  python3 broker_zmq.py 192.168.1.10 5555 5556\n")
        sys.exit(1)

    IP_INTERFACE = sys.argv[1]
    PORT_XSUB    = sys.argv[2]
    PORT_XPUB    = sys.argv[3]

    XSUB_URL = f"tcp://{IP_INTERFACE}:{PORT_XSUB}"
    XPUB_URL = f"tcp://{IP_INTERFACE}:{PORT_XPUB}"

    log("Inicializando contexto central de ZeroMQ...")
    context = zmq.Context.instance()

    socket_xsub = context.socket(zmq.XSUB)
    try:
        socket_xsub.bind(XSUB_URL)
        log(f"Socket XSUB enlazado exitosamente en {XSUB_URL} (Ingesta de sensores)")
    except zmq.ZMQError as e:
        log(f"[CRÍTICO] Fallo al enlazar XSUB en {XSUB_URL}: {e}")
        sys.exit(1)

  
    socket_xpub = context.socket(zmq.XPUB)
    try:
        socket_xpub.bind(XPUB_URL)
        log(f"Socket XPUB enlazado exitosamente en {XPUB_URL} (Distribución a Analítica)")
    except zmq.ZMQError as e:
        log(f"[CRÍTICO] Fallo al enlazar XPUB en {XPUB_URL}: {e}")
        socket_xsub.close()
        sys.exit(1)

    log("Dispositivo Proxy XSUB/XPUB configurado. Iniciando flujo de datos no bloqueante...")
    
    try:
        
        zmq.proxy(socket_xsub, socket_xpub)
        
    except KeyboardInterrupt:
        log("Interrupción detectada. Iniciando apagado controlado del Broker...")
    except zmq.ContextTerminated:
        log("El contexto de ZeroMQ fue terminado externamente.")
    except Exception as e:
        log(f"[ERROR ANÓMALO]: {e}")
    finally:
        socket_xsub.close()
        socket_xpub.close()
        context.term()
        log("Contexto y conexiones cerradas de manera segura. Servidor fuera de línea.")

if __name__ == "__main__":
    main()