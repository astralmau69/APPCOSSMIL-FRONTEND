# Guion de voz del tutorial — instructora COSSMIL

Cada línea es UN clip de audio. El `id` es el nombre de archivo final:
`assets/vof_tutorial/<id>.mp3`. El texto es la VERSIÓN HABLADA de las
burbujas del coach en cada paso: mismas ideas y casi las mismas palabras, pero
escrita para la voz (rev. 24 sep 2026): frases cortas, pausas con comas o
puntos en vez de ":", ";" o "—", y sin emojis. Si cambias una burbuja en el
código, actualiza aquí y regenera ese clip (celda 7, `SOLO_ESTOS`).

La versión legible por máquina (para los scripts) está en `tutorial_lines.json`.

---

## Invitación (aparece la primera vez en Inicio)

- **invite** — «¡Bienvenido a COSSMIL! Soy tu instructora. Te puedo enseñar a sacar una ficha, es decir, una cita médica, paso a paso. Toma menos de un minuto, y puedes repetir el tutorial cuando quieras, desde tu Perfil.»

## Tutorial: Sacar una ficha (recorrido "ficha")

- **ficha_00** — «¡Hola! Vamos a sacar tu primera ficha juntos. Todo empieza aquí, en Inicio. Toca la primera opción del menú, el botón verde, Nueva Reserva.»
- **ficha_01** — «¡Muy bien! Así se inicia una reserva. Ahora, elige tu hospital o policlínico. Estos son los que tienes habilitados, agrupados por regional.»
- **ficha_02** — «¡Muy bien! Ahora, elige la especialidad médica que necesitas.»
- **ficha_03** — «Estos son los médicos disponibles para esa especialidad. Elige el que prefieras.»
- **ficha_04** — «Ahora, elige el día. Cada tarjeta te muestra si el médico atiende, y si quedan fichas.»
- **ficha_05** — «¡Ya casi terminamos! Elige un horario disponible, dentro del día que escogiste.»
- **ficha_06** — «Revisa que todos los datos estén correctos. Luego, toca Confirmar Reserva. No te preocupes, aquí no se creará ninguna cita real.»
- **ficha_07** — «¡Misión cumplida! Esto fue solo una demostración, y no se creó ninguna cita real. Puedes ver tu ficha de ejemplo, o volver al inicio.»

## Tutorial: Consultar horarios (recorrido "calendario")

- **calendario_00** — «¡Hola! Te voy a enseñar a consultar los horarios de los médicos. Empezamos desde Inicio. Toca la tarjeta Calendario de Atención.»
- **calendario_01** — «Aquí puedes ver los días y horarios en que atiende cada médico, sin reservar nada. Empieza eligiendo tu hospital o policlínico.»
- **calendario_02** — «¡Muy bien! Ahora, elige la especialidad que quieres consultar.»
- **calendario_03** — «Estos son los médicos de esa especialidad. Toca uno, para ver su horario de atención.»
- **calendario_04** — «¡Eso es todo! Aquí ves los días, turnos y horas en que atiende este médico. Recuerda que esto es solo una consulta. Para sacar una ficha, usa Nueva Reserva, en Inicio. Puedes repetir este tutorial desde tu Perfil.»

## Tutorial: Generar un trámite (recorrido "tramites")

- **tramites_00** — «¡Hola! Vamos a generar un trámite, paso a paso. Empezamos desde Inicio. Toca la tarjeta Procedimientos COSSMIL.»
- **tramites_01** — «Aquí puedes generar documentos oficiales, con tus datos ya cargados. Los trámites se organizan por gerencia. Entra a Gerencia de Salud.»
- **tramites_02** — «¡Muy bien! Esta gerencia agrupa sus dependencias. Entra a Hospital.»
- **tramites_03** — «Ya casi llegamos. Cada categoría agrupa documentos. Abre Formularios.»
- **tramites_04** — «¡Listo! Cada tarjeta abre un formulario con tu nombre y cédula ya completados. Puedes imprimirlo, compartirlo o descargarlo. Y puedes repetir este tutorial desde tu Perfil.»

## Modo Guiado — reserva REAL narrada (recorrido "guiado")

> Registro tonal DISTINTO al resto: profesional, institucional militar (COSSMIL,
> Bolivia), trato de usted, sin jergas ni signos de exclamación de apertura.
> La instructora recuerda que la cita es REAL. Un clip por pantalla del flujo de
> reserva real (Regional → Especialidad → Médico → Día → Hora → Confirmar), más
> intro, aviso de inasistencias, cita registrada, imagen de la cita y despedida. Si cambia el texto de una burbuja, regenerar ese clip.
>
> Escrito PARA LA VOZ (rev. 24 sep 2026, tras escuchar la 1ª versión clonada):
> frases cortas (≤ ~15 palabras), palabras de uso común, comas donde se respira,
> una idea por frase y siempre punto final. Evitar cadenas de sustantivos largos
> ("establecimiento… agrupados por regional") que la voz lee atropellado.

- **guiado_intro** — «Bienvenido a la reserva guiada de COSSMIL. Le acompañaré paso a paso. Tenga en cuenta que esta reserva es real, y su cita quedará registrada. Comencemos.»  
  _Suena: al elegir "Modo Guiado"._
- **guiado_regional** — «Primero, elija el hospital o policlínico donde desea atenderse. Están ordenados por regional.»  
  _Suena: pantalla de hospital / policlínico (paso 0)._
- **guiado_especialidad** — «Ahora, elija la especialidad médica que necesita.»  
  _Suena: pantalla de especialidad (paso 1)._
- **guiado_medico** — «Muy bien. Ahora, elija al médico con quien desea realizar su consulta.»  
  _Suena: pantalla de médico (paso 2)._
- **guiado_dia** — «Elija el día de su cita. Los días en rojo no tienen fichas disponibles. Para continuar, seleccione un día en verde, que sí tiene fichas disponibles.»  
  _Suena: pantalla de día / agenda (paso 3)._
- **guiado_hora** — «Ahora, elija el horario de su preferencia.»  
  _Suena: pantalla de horario (paso 4)._
- **guiado_confirmar** — «Revise que sus datos sean correctos. Cuando esté listo, presione Confirmar.»  
  _Suena: resumen, antes de confirmar (paso 5)._
- **guiado_aviso** — «Antes de continuar, lea con atención este aviso importante. Si acumula tres inasistencias, se suspenderá su acceso para sacar fichas en línea. Cuando termine de leerlo, presione Entiendo, continuar con la reserva.»  
  _Suena: al abrirse el emergente "Aviso Importante" (inasistencias) tras tocar Confirmar._
- **guiado_registrada** — «Su cita fue registrada con éxito. Si desea verla, presione Ver Imagen de la Cita Médica.»  
  _Suena: cita registrada (pantalla de confirmación)._
- **guiado_ficha** — «Esta es la imagen de su cita médica. Con Descargar, puede guardarla o imprimirla. Con Compartir, puede enviarla a quien desee. Gracias por su atención, que tenga un buen día.»  
  _Suena: al abrir "Ver Imagen de la Cita Médica" (explica Descargar / Imprimir y Compartir, y se despide)._
- **guiado_despedida** — «Gracias por su atención. Le esperamos en su próxima reserva.»  
  _Suena: al tocar "Volver al Inicio" SIN haber abierto la imagen de la cita._
