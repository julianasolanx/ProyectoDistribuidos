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

En esta sección se fundamentan las bases teóricas y el diseño estructural de la plataforma GITU, asociando cada modelo conceptual con su respectivo diagrama de soporte técnico.

== Modelo Arquitectónico y de Componentes

== Modelo Físico y de Despliegue













