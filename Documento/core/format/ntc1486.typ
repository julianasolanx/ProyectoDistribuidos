// ntc1486.typ
// Plantilla optimizada para la Norma Técnica Colombiana NTC 1486 (ICONTEC)

#let ntc1486(
  title: "",
  subtitle: "",
  author: (),
  work-type: "", // Ej: "Trabajo de grado", "Monografía"
  advisor: "", // Nombre del asesor/director
  advisor-title: "", // Título académico del asesor
  institution: "",
  faculty: "",
  program: "",
  city: "",
  year: "",
  show-toc: true,
  show-figures-list: true,
  show-tables-list: true,
  show-annexes-list: false, // Por defecto false, se activa si el documento tiene anexos
  body,
) = {
  let author-metadata = if type(author) == array { author.join(", ") } else { author }
  set document(title: title, author: author-metadata)

  set page(
    paper: "us-letter",
    // Para poder imprimir a dos caras, margenes iguales a 3cm
    margin: (top: 3cm, bottom: 3cm, left: 3cm, right: 3cm),
    numbering: "1",
    footer: context {
      let current = counter(page).get().first()
      if current > 2 {
        align(center)[
          #set text(font: "Arial", size: 12pt)
          #str(current)
        ]
      }
    },
  )

  // Configuración de texto (Arial, 12pt, interlineado sencillo)
  set text(
    font: "Times New Roman",
    size: 12pt,
    lang: "es",
    region: "co",
  )

  // Redacción impersonal, texto justificado, interlineado sencillo
  // En Typst, un leading de 0.65em emula bien el interlineado sencillo de Arial.
  set par(
    justify: true,
    leading: 0.65em,
  )
  // Doble espacio entre párrafos (punto aparte)
  set par(spacing: 2em)

  // Configuración de los títulos (Máximo hasta el nivel 4)
  set heading(numbering: (..nums) => {
    let n = nums.pos()
    if n.len() <= 4 {
      n.map(str).join(".") + " "
    }
  })

  show heading.where(level: 1): it => {
    pagebreak(weak: true) //El título de cada capítulo debe comenzar en una hoja independiente
    v(1cm)
    align(center)[
      #set text(weight: "bold", size: 12pt)
      #upper(it.body)
    ]
    v(2em)
  }

  // Subcapítulos (Nivel 2 y 3) en Mayúscula Sostenida, alineados a la izquierda
  show heading.where(level: 2): it => {
    v(1.5em)
    set text(weight: "bold", size: 12pt)
    upper(it)
    v(1em)
  }

  show heading.where(level: 3): it => {
    v(1.5em)
    set text(weight: "bold", size: 12pt)
    upper(it)
    v(1em)
  }

  // Nivel 4: Mayúscula inicial, tipo oración
  show heading.where(level: 4): it => {
    v(1.5em)
    set text(weight: "bold", size: 12pt)
    it
    v(1em)
  }

  // Formato para Tablas, Figuras y Cuadros según la norma
  show figure.where(kind: table): it => {
    v(2em) // 2 interlineas antes
    set align(center)
    // Título arriba: Tabla X. Nombre
    block(width: 100%, align(left)[
      #set text(size: 12pt)
      *Tabla #it.counter.display().* #it.caption.body
    ])
    v(0.5em)
    it.body
    v(0.5em)
    // Fuente abajo
    if it.has("supplement") {
      align(left)[#set text(size: 10pt); #it.supplement]
    }
    v(2em) // 2 interlineas después
  }

  // Función interna para renderizar los autores uno debajo del otro en mayúscula sostenida
  let render-authors() = {
    if type(author) == array {
      author.map(a => text(weight: "bold")[#upper(a)]).join([\ \ ])
    } else {
      text(weight: "bold")[#upper(author)]
    }
  }

  // --- CUBIERTA (Página 1) ---
  if title != "" {
    pagebreak(weak: true)
    align(center)[
      #v(1cm) // Compensa los 3cm de margen para dar 4cm al título
      #text(weight: "bold")[#upper(title)]

      #if subtitle != "" [
        #v(0.5em)
        #text(weight: "regular")[#upper(subtitle)]
      ]

      #v(4cm)
      // Renderiza todos los autores alineados y apilados verticalmente
      #render-authors()

      #v(1fr)
      #text(weight: "regular")[
        #upper(institution) \
        #if faculty != "" [ #upper(faculty) \ ]
        #if program != "" [ #upper(program) \ ]
        #upper(city) \
        #year
      ]
    ]
    pagebreak()
  }

  // --- PORTADA (Página 2) ---
  if title != "" {
    align(center)[
      #v(1cm)
      #text(weight: "bold")[#upper(title)]
      #if subtitle != "" [ \ #upper(subtitle) ]

      #v(2.5cm)
      #render-authors()

      #v(2.5cm)
      // Leyenda del trabajo (Clase de trabajo realizado)
      #align(center)[
        #set block(width: 60%)
        #text(size: 11pt)[#work-type]
      ]

      #v(1.5cm)
      // Datos del Asesor
      #if advisor != "" [
        Asesor: #advisor #if advisor-title != "" [, #advisor-title]
      ]

      #v(1fr)
      #text(weight: "regular")[
        #upper(institution) \
        #if faculty != "" [ #upper(faculty) \ ]
        #if program != "" [ #upper(program) \ ]
        #upper(city) \
        #year
      ]
    ]
    pagebreak()
  }

  // --- TABLA DE CONTENIDO (Página 3) ---
  if show-toc {
    outline(
      title: "CONTENIDO",
      depth: 3,
      indent: 1.5em,
    )
  }

  // --- TABLA DE FIGURAS (Especiales de tipo imagen) ---
  if show-figures-list {
    outline(
      title: "LISTA DE FIGURAS",
      target: figure.where(kind: image),
    )
  }

  // --- TABLA DE TABLAS (Especiales de tipo tabla) ---
  if show-tables-list {
    outline(
      title: "LISTA DE TABLAS",
      target: figure.where(kind: table),
    )
  }

  // --- TABLA DE ANEXOS (Especiales de tipo anexo) ---
  if show-annexes-list {
    outline(
      title: "LISTA DE ANEXOS",
      target: figure.where(kind: "anexo"),
    )
  }

  // Asegura un salto de página después de la última lista para que el cuerpo empiece limpio
  if show-toc or show-figures-list or show-tables-list or show-annexes-list {
    pagebreak(weak: true)
  }

  body
}

// --- ENTORNOS COMPLEMENTARIOS ADICIONALES ---

// Función para citas extensas (Más de 5 renglones)
#let citaExtensa(body) = {
  block(
    inset: (left: 4em), // Sangría de 4 espacios (emula los 4 espacios de la norma)
    breakable: true,
    text(size: 11pt, body), // Ligeramente menor o igual, manteniendo el estilo
  )
}