#import "core/format/ntc1486.typ": ntc1486

#show: ntc1486.with(
  title: "Proyecto introducción a sistemas distribuidos",
  subtitle: "gestión inteligente de tráfico urbano",
  author: (
    "Juliana sofía novoa solano",
    "Ismael Santiago Forero Romero",
    "Johan sebastian lopez arciniegas ",
  ),
  institution: "Pontificia Universidad Javeriana",
  faculty: "Facultad de Ingeniería",
  program: "Ingeniería de Sistemas",
  city: "Bogotá",
  year: "2026",
  advisor: "Rafael Vicente Paez Mendez

",
  work-type: "Proyecto Final",
)

= Resumen

Este proyecto presenta el diseño, desarrollo y evaluación de rendimiento de la plataforma distribuida Gestión Inteligente de Tráfico Urbano (GITU), desarrollada bajo el paradigma de arquitectura orientada a eventos. La infraestructura se desplegó en un entorno real de tres nodos (PC1, PC2 y PC3) utilizando la librería ZeroMQ (ZMQ) con patrones PUB/SUB, PUSH/PULL y REQ/REP para desacoplar la ingesta de sensores, el servicio de analítica y el módulo de monitoreo. Para garantizar la alta disponibilidad, se implementó un mecanismo de tolerancia a fallos por enmascaramiento que redirige de forma transparente el flujo de persistencia hacia una base de datos réplica en el PC2 ante la desconexión del nodo principal (PC3). El núcleo de la investigación consistió en un análisis experimental de escalabilidad que contrastó un diseño de Broker monohilo frente a una variante multihilo (Design Multithreading) bajo escenarios de carga nominal y crítica. Los resultados empíricos demostraron que la arquitectura multihilo maximiza el rendimiento de inserción en la base de datos (solicitudes/2 minutos) y reduce drásticamente la latencia en los tiempos de respuesta de los semáforos, concluyendo que es el único diseño capaz de sostener un crecimiento exponencial de sensores asegurando la estabilidad del sistema distribuido.

PALABRAS CLAVE: Sistemas Distribuidos, ZeroMQ, Arquitectura Orientada a Eventos, Tolerancia a Fallos, Multithreading, Escalabilidad, Gestión de Tráfico Urbano.

// revisar
= Glosario

= Introducción

En este documento se presenta el diseño, implementación y evaluación de rendimiento de una plataforma distribuida para la Gestión Inteligente de Tráfico Urbano (GITU). El objetivo principal de este proyecto es resolver los desafíos de concurrencia, persistencia de datos y tolerancia a fallos asociados al monitoreo y control en tiempo real de una red vial simulada sobre una cuadrícula de $N * M$.

La problemática de coordinar flujos masivos provenientes de sensores (cámaras de tráfico y GPS) exige abandonar los enfoques síncronos convencionales. Por ello, el sistema propuesto se fundamenta en una arquitectura distribuida orientada a eventos, empleando la librería de mensajería ZeroMQ (ZMQ) como middleware para garantizar un desacoplamiento estricto entre los componentes del sistema. A través de este enfoque, se busca analizar el impacto de la distribución de carga y estudiar cómo mitigar los puntos únicos de falla en entornos de red reales.

Para cumplir con las especificaciones del diseño, la plataforma distribuye sus responsabilidades en tres entornos independientes: el PC1, dedicado a la generación asíncrona e ingesta de eventos; el PC2, encargado del procesamiento lógico de las reglas de analítica y el control dinámico de semáforos; y el PC3, orientado a la persistencia en una base de datos centralizada y a la exposición de servicios de consulta para el usuario operador. Adicionalmente, el proyecto define un marco de experimentación riguroso para evaluar dos atributos clave de calidad: la resiliencia, mediante protocolos de conmutación por error (failover) hacia bases de datos réplica, y la escalabilidad horizontal, contrastando directamente el rendimiento del diseño original monohilo frente a la implementación de un diseño modificado multihilo (Design Multithreading) basado en un pool de hilos de trabajo.

= Planteamiento del problema 

== Descripción del problema 

El diseño de plataformaspara el monitoreo y control del tráfico vehicular urbano en tiempo real se enfrenta a complejidades técnicas críticas cuando se escala a escenarios de alta densidad. El principal desafío radica en la necesidad de capturar, procesar y reaccionar de manera inmediata ante flujos masivos y concurrentes de telemetría vial que provienen de múltiples intersecciones simuladas de forma distribuida.

Los enfoques arquitectónicos tradicionales y de comunicación estrictamente síncrona resultan inviables en estos entornos debido a tres problemáticas fundamentales de los sistemas distribuidos:

1. *Saturación por Concurrencia (Cuellos de Botella):* El procesamiento secuencial (monohilo) en los intermediarios de mensajería (Brokers) degrada el rendimiento del sistema ante ráfagas masivas de datos. Cuando el número de sensores o su frecuencia de transmisión aumentan de forma crítica, una arquitectura monohilo encola las solicitudes. Esto retrasa tanto la persistencia de datos históricos como la ejecución de comandos prioritarios de control vial forzados por los operadores.

2. *Vulnerabilidad ante Puntos Únicos de Falla:* La centralización de servicios críticos compromete la alta disponibilidad de la plataforma. Si el nodo físico dedicado a consolidar la persistencia de datos históricos y a servir las consultas de monitoreo sufre una caída de red o un colapso de software, toda la operación de auditoría e interacción del usuario se interrumpe por completo, dejando el sistema en un estado vulnerable y no resiliente.

3. *Acoplamiento de Componentes:* La comunicación directa entre sensores, motores de reglas de analítica y actuadores semafóricos genera dependencias rígidas. Esto impide que los diferentes componentes de software evolucionen, se escalen horizontalmente o absorban fallas de red de manera independiente y transparente para el usuario final.

= Objetivos

== Objetivo General

Diseñar, implementar y evaluar el rendimiento de una plataforma distribuida orientada a eventos para la Gestión Inteligente de Tráfico Urbano (GITU), utilizando la librería de mensajería ZeroMQ (ZMQ) sobre un entorno real de tres nodos independientes, garantizando la alta disponibilidad del sistema y la mitigación de cuellos de botella ante escenarios de carga crítica.

== Objetivos específicos

- Diseñar e implementar una arquitectura desacoplada basada en eventos, distribuyendo las responsabilidades del sistema en tres nodos independientes (PC1 para la simulación e ingesta, PC2 para la analítica lógica y PC3 para la persistencia y monitoreo) empleando combinaciones estratégicas de los patrones PUB/SUB, PUSH/PULL y REQ/REP.
- Desarrollar un mecanismo de tolerancia a fallos automatizado y transparente para el usuario mediante protocolos de Health Check, asegurando la conmutación por error (failover) del flujo operativo hacia una base de datos réplica en el PC2 ante la desconexión total del nodo de persistencia principal (PC3).
- Construir una variante arquitectónica optimizada mediante hilos de ejecución (Design Multithreading) en el Broker de mensajería, con el fin de paralelizar el procesamiento de telemetría heterogénea proveniente de la red de sensores.
- Evaluar empíricamente la escalabilidad horizontal del sistema, contrastando mediante métricas cuantitativas (rendimiento de inserciones en base de datos y latencia en los tiempos de respuesta de control) el desempeño del diseño original monohilo frente al diseño modificado multihilo bajo escenarios de carga nominal y de estrés.

= Modelos del sistema y Diseño arquitectónicos

== Modelo arquitectónico y de componentes

La arquitectura del sistema sigue un estilo por Capas (Layered) combinado con un enfoque Dirigido por eventos (Event-Driven Architecture - EDA) y el patrón Broker para desacoplar a los productores de datos de los consumidores. 

La plataforma se compone de cinco capas lógicas principales, estructuradas de la siguiente manera:

#figure(
    image(
      "assets/diagramaComponentes.png",
    ),
    caption: [
      Diagrama de Componentes
    ],
  )

Componentes y Patrones de Comunicación ZeroMQ Utilizados:

1. *Simulador de Sensores (`simulador_sensores.py`):*
   - *Patrón ZMQ:* `PUB` (Editor).
   - *Funcionamiento:* Se conecta al puerto `XSUB` del Broker. Genera eventos periódicos simulados según tres niveles de congestión (`baja`, `media`, `alta`) para Cámaras (`CAM`), Espiras (`ESP`) y dispositivos GPS.
   - *Tópicos publicados:* `"camara"`, `"espira_inductiva"`, `"gps"`.

2. *Broker ZMQ Centralizado (`broker_zmq.py` o `broker_multihilo_zmq.py`):*
   - *Patrón ZMQ:* `XSUB` / `XPUB` enlazados mediante un dispositivo intermediario (`zmq.proxy`).
   - *Funcionamiento:* Actúa como proxy asíncrono para desacoplar a los sensores de la analítica. Recibe publicaciones en el socket `XSUB` (puerto `5555`) y las retransmite a través del socket `XPUB` (puerto `5556`) a los consumidores suscritos.
   - *Versión Multihilo:* Para escenarios de alto rendimiento y experimentos de escalabilidad, `broker_multihilo_zmq.py` implementa la canalización mediante dos hilos demonios independientes que ejecutan la transferencia bidireccional no bloqueante de subscripciones y datos.

3. *Servicio de Analítica de Tráfico (`servicio_analitica.py`):*
   - *Patrones ZMQ:* `SUB` (Consumidor), `PUSH` (Productor a base de datos y control), `REP` (Servidor de comandos).
   - *Funcionamiento:* Es el núcleo del sistema.
     - Se suscribe al Broker (`SUB`) para ingerir y correlacionar datos de sensores.
     - Procesa los flujos de datos en su *Motor de Correlación* aplicando lógica difusa/reglas de semaforización.
     - Envía directivas de control (`PUSH`) al Control de Semáforos.
     - Envía réplicas de registros procesados (`PUSH` con bandera `zmq.NOBLOCK`) a la BD Principal en PC3 y a la BD Réplica en PC2.
     - Expone una interfaz de red segura (`REP`, puerto `5562`) para recibir solicitudes manuales del módulo de monitoreo.

4. *Servicio de Control de Semáforos (`control_semaforos.py`):*
   - *Patrón ZMQ:* `PULL` (Consumidor de control).
   - *Funcionamiento:* Escucha de forma local en el puerto `5557`. Procesa de manera no bloqueante los comandos de cambio de luces o extensión de fases enviados por el Servicio de Analítica. Mantiene el estado lógico de los semáforos de la intersección (vías tipo CALLE y vías tipo CARRERA).

5. *Bases de Datos Principal (`base_datos_principal.py`) y Réplica (`base_datos_replica.py`):*
   - *Patrones ZMQ:* `PULL` (Receptor de persistencia), `REP` (Servidor de consultas históricas), `REQ` / `REP` (Sincronización diferencial).
   - *Funcionamiento:*
     - Ambas guardan de forma asíncrona la información en archivos físicos SQLite localmente (`trafico_principal.db` en PC3 y `trafico_replica.db` en PC2).
     - Proveen endpoints `REP` para resolver las consultas del Cliente de Monitoreo.
     - La BD Principal cuenta con un socket `REQ` para solicitar registros perdidos a la réplica durante su restauración post-falla (puerto `5561`).

6. *Interfaz de Monitoreo (`interfaz_monitoreo.py`):*
   - *Patrón ZMQ:* `REQ` (Cliente con temporizador de recepción).
   - *Funcionamiento:* Realiza consultas históricas de tráfico o envía solicitudes de prioridad (e.g., paso de ambulancia) enviando peticiones síncronas. Integra la clase `ClientePersistencia` que maneja el ciclo de vida de conexión hacia las BDs de manera tolerante a fallas.

  === Tipos de Máquinas a utilizar en el proyecto

  A continuación, se detallan las características de hardware virtual, el sistema operativo y el direccionamiento IP asignado a cada máquina dentro de la topología de la red:

#figure(
  table(
    columns: (1.5fr, 2.5fr, 1.2fr, 1.5fr),
    stroke: 0.5pt + black, 
    fill: none,           
    align: (col, row) => if row == 0 { center + horizon } else { left + horizon },
    
   
    table.header(
      [*Componente*],
      [*Características de Hardware y SO*],
      [*Dirección IP*],
      [*Componentes Lógicos*],
    ),

    
    [*(PC1)*],
    [
      - *SO:* Ubuntu Server 24.04.3 LTS
      - *RAM:* 2 GB
      - *Almacenamiento:* 25 GB SSD
      - *CPU:* 4 vCores (Intel i7-7700 \@ 3.60GHz)
    ],
    `100.110.49.29`,
    [
      - Procesos de Sensores (Cámaras, Espiras, GPS).
      - Instancia central del Broker ZeroMQ.
    ],

    
    [*(PC2)*],
    [
      - *SO:* Ubuntu Server 24.04.3 LTS
      - *RAM:* 2 GB
      - *Almacenamiento:* 25 GB SSD
      - *CPU:* 4 vCores (Intel i7-7700 \@ 3.60GHz)
    ],
    `100.87.47.66`,
    [
      - Servicio de Analítica de Tráfico.
      - Servicio de Control de Semáforos.
      - Base de Datos Réplica (Backup).
    ],

    
    [*(PC3)*],
    [
      - *SO:* Ubuntu Server 24.04.3 LTS
      - *RAM:* 2 GB
      - *Almacenamiento:* 25 GB SSD
      - *CPU:* 4 vCores (Intel i7-7700 \@ 3.60GHz)
    ],
    `100.90.114.97`,
    [
      - Módulo de Monitoreo y Consulta.
      - Base de Datos Principal (Persistencia).
    ],
  ),
  caption: [Especificaciones de infraestructura y direccionamiento de red para los nodos distribuidos.],
) <tabla-infraestructura>
=== Justificación del Entorno Homogéneo

La asignación equilibrada de recursos (*4 vCores* y *2 GB de RAM* para cada nodo) responde a las demandas específicas del procesamiento distribuido en tiempo real:

1. *Capacidad de Cómputo:* El uso de 4 núcleos virtuales basados en el procesador Intel i7-7700 asegura que el *PC1* pueda ejecutar múltiples hilos de sensores simulados concurrentemente sin saturar el Broker ZMQ. Asimismo, el *PC2* dispone de la potencia necesaria para procesar los algoritmos de analítica y conmutación de semáforos en paralelo.
2. *Rendimiento de Persistencia:* Los *25 GB de espacio en almacenamiento de tipo SSD* garantizan tasas de transferencia elevadas para las operaciones de escritura asíncrona de los logs históricos en la Base de Datos Principal (*PC3*) y su correspondiente replicación en el *PC2*.
3. *Simulación de Tolerancia a Fallos:* Al contar con réplicas exactas de hardware y sistema operativo, el mecanismo de conmutación por error (*failover*) hacia la Base de Datos Réplica en el *PC2* ante la caída del *PC3* se ejecuta bajo las mismas condiciones de rendimiento, garantizando la transparencia del sistema.

== Modelo Físico y de Despliegue

El sistema está diseñado para un despliegue distribuido en tres computadores o entornos virtuales independientes (`PC1`, `PC2`, y `PC3`), interactuando mediante protocolos TCP/IP.

== Modelo de interacción

Este modelo detalla la arquitectura de software interna mediante un diagrama de clases estructurado, y el flujo de los mensajes mediante diagramas de secuencia para los escenarios clave.

#figure(
    image(
      "assets/diagramaSecuencia.drawio.png",
    ),
    caption: [
      Diagrama de Secuencia
    ],
  )

=== Diagrama de clases

El diseño orientado a objetos y estructurado del software cuenta con las siguientes clases clave que resuelven problemas de negocio, sincronización y validación:

#figure(
    image(
      "assets/diagramaClases.drawio.png",
    ),
    caption: [
      Diagrama de clases
    ],
  )

=== Diagrama de secuencia: Ingesta de Datos y Control de Semáforos (Vía Broker)

Este flujo ilustra el procesamiento asíncrono y desacoplado de las mediciones de los sensores para tomar decisiones automatizadas en los semáforos y persistir los históricos.

=== 3.3 Diagrama de Secuencia: Priorización Manual (Ola Verde de Emergencia)

Muestra la interacción síncrona `REQ/REP` cuando el operador fuerza una "Ola Verde" para habilitar el paso prioritario de una ambulancia o vehículo de emergencia.

== Modelo de Fallos

El sistema implementa mecanismos explícitos de tolerancia a fallas que garantizan una alta disponibilidad y resiliencia ante una caída total del *PC3* (donde corre la Base de Datos Principal).

#figure(
    image(
      "assets/modeloFallos.drawio.png",
    ),
    caption: [
      Modelo Fallos
    ],
  )

=== Tolerancia en la Ingesta de Datos (`servicio_analitica.py`)

Cuando el *PC3* se apaga o falla, el socket `PUSH` hacia la BD Principal se llenaría rápidamente y bloquearía el flujo de procesamiento completo del motor de analítica debido al mecanismo interno de High Water Mark (HWM) de ZeroMQ.

- *Solución Implementada:* El servicio de analítica realiza el envío de datos mediante la bandera de no-bloqueo:

  `try:
      socket_bd_p.send_string(msg_send, zmq.NOBLOCK)
  except zmq.Again:
      log("[FALLO EN PC3] Persistencia en canal secundario.")`

Si el PC3 no está disponible, el error `zmq.Again` es capturado de manera segura, el sistema registra la alerta en consola, continúa procesando las alertas de tráfico sin interrupciones y persistiendo los datos de respaldo en la base de datos réplica de PC2.

=== Tolerancia en las Consultas (`ClientePersistencia` en `interfaz_monitoreo.py`)

El cliente de monitoreo realiza consultas con un temporizador estricto de respuesta de *2 segundos* utilizando la opción `zmq.RCVTIMEO`:

`self.socket.setsockopt(zmq.RCVTIMEO, 2000)`

Si la base de datos principal en PC3 no responde en este período o cualquier otro que se le ponga, el cliente experimenta una excepción `zmq.Again`. Automáticamente ejecuta el *Failover Transparente*:
1. Cierra el socket con descarte de persistencia de mensajes (`linger=0`).
2. Conmuta el atributo `active_db` al estado `"replica"`.
3. Abre un nuevo socket hacia la dirección IP del *PC2* en el puerto de consultas de respaldo.
4. Vuelve a emitir la consulta de manera transparente para el usuario final.

=== Sincronización Diferencial y Reconciliación Post-Falla (`base_datos_principal.py`)

Cuando el *PC3* vuelve a estar en línea, las bases de datos se encuentran desalineadas debido a los registros escritos exclusivamente en la réplica durante el tiempo de inactividad del nodo principal.

El sistema implementa un *mecanismo de reconciliación automática diferencial*:

1. Al arrancar `base_datos_principal.py`, ejecuta `ejecutar_sincronizacion_diferencial(ip_replica)`.
2. Realiza una consulta SQL local para encontrar el último registro secuencial guardado con éxito: `   SELECT MAX(ejecucion_id) FROM historico_sensores;`
3. Establece una conexión síncrona temporal `REQ` con el socket `REP` de sincronización de la réplica (puerto `5561` en PC2).
4. Envía el último ID recibido (por ejemplo, `{"ultimo_id_recibido": 450}`).
5. El proceso de réplica en PC2 consulta su base de datos local: `SELECT * FROM historico_sensores WHERE ejecucion_id > 450 ORDER BY ejecucion_id ASC;`
6. Retorna en un JSON la lista de todos los registros que se guardaron mientras el PC3 estuvo fuera de línea.
7. La BD Principal los inserta diferencialmente (`INSERT OR IGNORE`) restaurando la consistencia e integridad del sistema distribuido de forma automatizada.

== Modelo de Seguridad

El sistema adopta políticas de diseño robustas ("Hardened Design") para mitigar los vectores de ataque comunes en entornos distribuidos industriales y redes IoT urbanas:

=== Capa de Validación Estructural y de Tipos (`ValidadorSeguridad`)
Ubicada en el punto de entrada de procesamiento del PC2, valida de manera determinista cada mensaje recibido 
desde el broker antes de pasarlo al motor de decisiones.

- *Control de Esquemas:* Define esquemas estrictos de llaves obligatorias para cada uno de los tipos de sensores (`camara`, `gps`, `espira_inductiva`). Si falta un solo campo, el mensaje es rechazado.
- *Validación de Tipos de Datos:* Valida tipos numéricos utilizando la función `isinstance(datos['volumen'], (int, float))`. Esto evita ataques de desbordamiento, inyección de caracteres especiales o inyección SQL en la capa de persistencia.

=== Mitigación de Ataques de Inyección y Sanitización de Cadenas

- *Sanitización de Identificadores:* Se comprueba que el campo de identificación de intersecciones cumpla con el formato preestablecido: 
`  if not isinstance(datos["interseccion"], str) or not datos["interseccion"].startswith("INT_"):
      return False, "Formato de identificador de intersección inválido o malicioso."`

Esto bloquea intentos de inyectar rutas de archivos o caracteres de escape SQL (e.g., `'; DROP TABLE...`) a través del identificador de la intersección.

- *Control de Longitud:* En los comandos de control manual por REP, se valida rigurosamente la longitud máxima del identificador de la intersección (`len(interseccion_m) > 10`) para prevenir vulnerabilidades de desbordamiento de búfer en memoria o ejecuciones imprevistas de scripts.

=== Aislamiento de Red y Seguridad de Arquitectura

- *Desacoplamiento de Productores:* Los sensores en PC1 jamás conocen la dirección IP ni los puertos del servicio de analítica (PC2), ni los puertos de almacenamiento de base de datos en PC3. El único punto de contacto público de los sensores es la IP del Broker ZMQ. Esto reduce drásticamente la superficie de ataque y el riesgo de ataques directos de denegación de servicio (DoS) a los procesadores del sistema.

- *Consultas Parametrizadas Precompiladas (SQLite):* Toda consulta SQL ejecutada tanto en la base de datos principal como en la réplica utiliza exclusivamente marcadores de posición parametrizados (`?`):

`  cursor.execute("SELECT ... WHERE time(timestamp) BETWEEN time(?) AND time(?)", (hora_inicio, hora_fin))`

La parametrización de variables previene al 100% ataques de inyección de código SQL clásico mediante la consola de monitoreo, garantizando la confidencialidad e integridad total del histórico de tráfico urbano.

= a) ¿Cómo obtienen los procesos la definición inicial de los recursos (número y tipo de sensores, tamaño de la matriz, número de semáforos, etc.)?

La infraestructura urbana inicial y sus parámetros operacionales están centralizados en un archivo de configuración estructurado en formato JSON y se distribuyen bajo dos metodologías dependiendo del rol del proceso: *carga estática inicial* o *inicialización dinámica bajo demanda (perezosa)*.

1. Archivo de Configuración Central (`config_ciudad.json`)

Este archivo sirve como la *"única fuente de verdad"* física en el disco:

- *Matriz de Intersecciones:* Define las dimensiones de la cuadrícula a través de listas de filas, por ejemplo, (`["A", "B", "C", "D", "E", "F"]`) y columnas (`[1, 2, 3, 4, 5, 6]`), lo cual define una malla de *$6 * 6$ (36 intersecciones posibles)*. O cualquier otro tamaño porque se maneja de manera dinámica.

- *Topología Urbana:* Enumera explícitamente cada intersección con su identificador único (`"INT_A1"`, `"INT_A2"`, etc.) y sus coordenadas vectoriales.

- *Configuración Global:* Establece constantes del sistema, como el tiempo de semáforo por defecto (`"tiempo_semaforo_normal_seg": 15`).

2. Mecanismo de Obtención por Proceso

- Simulador de Sensores (`simulador_sensores.py`):

  - *Carga:* Al arrancar el proceso de un sensor (por ejemplo, una Cámara en la intersección `INT_C3`), este ejecuta la función `cargar_topologia_urbana()`, la cual abre, lee y parsea dinámicamente el archivo `config_ciudad.json` desde su ruta relativa.
  - *Validación:* El proceso valida con la función `validar_interseccion(interseccion_id, config)` si la intersección ingresada por el operario en los argumentos de la terminal existe dentro del arreglo de IDs habilitados. Si el identificador no coincide con la topología, el sensor se apaga de inmediato informando el error de forma segura.

- Controlador de Semáforos (`control_semaforos.py`):

  - *Bajo Demanda:* Este componente no precarga el archivo JSON. Aplica un patrón de inicialización perezosa (*lazy initialization*).
  - Mantiene una estructura de datos en memoria (`malla_semaforos = {}`). Cuando el servicio de Analítica le envía un comando para controlar una intersección por primera vez, el controlador comprueba si ya la tiene registrada. Si no es el caso, la crea e inicializa dinámicamente con su estado por defecto (`{"CALLE": "VERDE", "CARRERA": "ROJO"}`).

- Servicio de Analítica (`servicio_analitica.py`):

  - *Buffer Dinámico:* Tampoco lee el archivo JSON directamente para evitar dependencias acopladas de disco.
  - En su lugar, inicializa un *Buffer de Correlación* en memoria (`bufer_intersecciones = {}`). A medida que van ingresando datos de los tópicos `"camara"`, `"espira_inductiva"` o `"gps"` para una intersección determinada, crea dinámicamente una tupla de correlación para agrupar y sincronizar las ventanas de tiempo del nodo antes de tomar decisiones lógicas.
  - Por seguridad, el sub-módulo `ValidadorSeguridad` sanitiza e inspecciona estructuralmente que los payloads que reportan los sensores pertenezcan a una intersección válida verificando que la cadena empiece estrictamente con el prefijo `"INT_"`.

= b) Reglas de Tránsito, tipos de consulta de los usuarios y ejemplos de indicaciones directas del servicio de Monitoreo al servicio de Analítica

1. Reglas de Tránsito (Motor de Correlación en `servicio_analitica.py`)

El motor evalúa concurrentemente los datos acumulados de los tres sensores sincronizados (`camara`, `gps` y `espira_inductiva`) por intersección. Aplica las siguientes reglas lógicas:

2. Tipos de Consulta de los Usuarios (`interfaz_monitoreo.py`)

El operador a través de la terminal realiza consultas utilizando un socket síncrono `REQ/REP` con la clase `ClientePersistencia`. El cliente implementa un temporizador de 2 segundos; si la base de datos principal (PC3) falla, conmuta automáticamente a la réplica (PC2) de forma transparente. Las consultas son:

- Consulta A: Verificación de Estado (Auditoría de consistencia):

  - Payload enviado (JSON):     { "accion": "ping_estado" }
  - Respuesta del Servidor (JSON):  Devuelve el estado del nodo y el ID secuencial global más alto guardado de forma persistente en SQLite para verificar la consistencia del clúster:     { "status": "ACK", "ultimo_id": 4820 }

- Consulta B: Consulta Histórica por Rango de Tiempo (Detección de horas pico):

  - Payload enviado (JSON):

      `{
      "accion": "consulta_historica",
      "hora_inicio": "15:10:00",
      "hora_fin": "15:25:00"
    }`

  - Respuesta del Servidor (JSON): Devuelve un arreglo relacional de registros ordenados de forma ascendente:

  `    {
      "status": "SUCCESS",
      "datos": [
        { "id": 1, "interseccion": "INT_C3", "sensor": "camara", "ts": "2026-05-27T15:12:04Z" },
        { "id": 2, "interseccion": "INT_C3", "sensor": "gps", "ts": "2026-05-27T15:12:05Z" }
      ]
    }`

3. Ejemplos de Indicaciones Directas (Monitoreo >>> Analítica)

En situaciones de emergencia, el operador de Monitoreo (PC3) puede puentear la inteligencia automática de los semáforos, transmitiendo una instrucción síncrona directa al Servicio de Analítica (PC2) usando un canal `REQ/REP`:

- Paso A: Envío de la Solicitud desde Monitoreo a la Analítica

El operador activa el protocolo "Ola Verde de Emergencia" para abrir paso inmediato a un vehículo prioritario (p. ej., ambulancia). El mensaje enviado es:

`{
  "accion": "forzar_verde",
  "interseccion": "INT_C3",
  "motivo": "EMERGENCIA_AMBULANCIA: Priorización manual de vía solicitada por operador."
}`

- Paso B: Propagación y Actuación (Analítica >>> Control de Semáforos)

La Analítica procesa e inspecciona el mensaje. Al validar la autenticidad e integridad del payload, suspende el procesamiento lógico automático de la intersección `INT_C3` y envía de inmediato por su canal `PUSH` la directiva imperativa al servicio de semáforos físico:

`{
  "interseccion": "INT_C3",
  "accion": "extender_verde",
  "motivo": "EMERGENCIA_AMBULANCIA: Priorización manual de vía solicitada por operador.",
  "tiempo_permanencia_seg": 30
}
`

- Paso C: Respuesta de Éxito devuelta al Operador de Monitoreo

La Analítica responde de forma síncrona indicando la finalización exitosa del comando:

`{
  "status": "SUCCESS",
  "mensaje": "Ola verde propagada con éxito de forma segura."
}
`


    




















