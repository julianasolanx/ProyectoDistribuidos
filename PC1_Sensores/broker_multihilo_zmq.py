import sys
import zmq
import threading
from datetime import datetime

def log(mensaje):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    print(f"[{ts}] [BROKER-MULTIHILO] {mensaje}")

def canalizar_flujo_datos(socket_origen, socket_destino):
    """Hilo encargado de capturar un string y retransmitirlo inmediatamente."""
    while True:
        try:
            raw_msg = socket_origen.recv_string()
            socket_destino.send_string(raw_msg)
        except zmq.ZMQError:
            break

def main():
    if len(sys.argv) != 4:
        print("\n[ERROR] Parámetros incorrectos.")
        print("Uso: python broker_multihilo_zmq.py <ip> <puerto_xsub> <puerto_xpub>\n")
        sys.exit(1)

    IP_INTERFACE = sys.argv[1]
    PORT_XSUB    = sys.argv[2]
    PORT_XPUB    = sys.argv[3]

    context = zmq.Context.instance()

    socket_xsub = context.socket(zmq.XSUB)
    socket_xsub.bind(f"tcp://{IP_INTERFACE}:{PORT_XSUB}")

    socket_xpub = context.socket(zmq.XPUB)
    socket_xpub.bind(f"tcp://{IP_INTERFACE}:{PORT_XPUB}")

    log("Iniciando Escenarios de Prueba: Levantando hilos de comunicación paralelos...")

  
    hilo_ingesta = threading.Thread(
        target=canalizar_flujo_datos, 
        args=(socket_xsub, socket_xpub), 
        daemon=True
    )
    
    
    hilo_Suscrip = threading.Thread(
        target=canalizar_flujo_datos, 
        args=(socket_xpub, socket_xsub), 
        daemon=True
    )

    hilo_ingesta.start()
    hilo_Suscrip.start()

    log(f"Broker Multihilo operativo. Escuchando en puertos {PORT_XSUB} y {PORT_XPUB}.")
    
    try:
        
        hilo_ingesta.join()
    except KeyboardInterrupt:
        log("Apagando servidor multihilo de experimentos.")
    finally:
        socket_xsub.close()
        socket_xpub.close()
        context.term()

if __name__ == "__main__":
    main()