# Guion de voz del tutorial — instructora COSSMIL

Cada línea es UN clip de audio. El `id` es el nombre de archivo final:
`assets/vof_tutorial/<id>.mp3`. El texto es exactamente lo que dicen las
burbujas del coach en cada paso (sin emojis, que no se leen). Si cambias el
texto de una burbuja en el código, actualiza aquí y regenera ese clip.

La versión legible por máquina (para los scripts) está en `tutorial_lines.json`.

---

## Invitación (aparece la primera vez en Inicio)

- **invite** — «¡Bienvenido a COSSMIL! Soy tu instructora. Te puedo enseñar a
  sacar una ficha, es decir, una cita médica, paso a paso. Toma menos de un
  minuto, y puedes repetir el tutorial cuando quieras, desde tu Perfil.»

## Tutorial: Sacar una ficha (recorrido "ficha")

- **ficha_00** — «¡Hola! Vamos a sacar tu primera ficha juntos. Todo empieza
  aquí, en Inicio. Toca la primera opción del menú, el botón verde, Nueva
  Reserva.»
- **ficha_01** — «¡Muy bien! Así se inicia una reserva. Ahora, elige tu
  hospital o policlínico. Estos son los que tienes habilitados, agrupados por
  regional.»
- **ficha_02** — «¡Muy bien! Ahora, elige la especialidad médica que
  necesitas.»
- **ficha_03** — «Estos son los médicos disponibles para esa especialidad.
  Elige el que prefieras.»
- **ficha_04** — «Ahora, elige el día. Cada tarjeta te muestra si el médico
  atiende, y si quedan fichas.»
- **ficha_05** — «¡Ya casi terminamos! Elige un horario disponible, dentro del
  día que escogiste.»
- **ficha_06** — «Revisa que todos los datos estén correctos. Luego, toca
  Confirmar Reserva. No te preocupes, aquí no se creará ninguna cita real.»
- **ficha_07** — «¡Misión cumplida! Esto fue solo una demostración, y no se
  creó ninguna cita real. Puedes ver tu ficha de ejemplo, o volver al inicio.»

## Tutorial: Consultar horarios (recorrido "calendario")

- **calendario_00** — «¡Hola! Te voy a enseñar a consultar los horarios de los
  médicos. Empezamos desde Inicio. Toca la tarjeta Calendario de Atención.»
- **calendario_01** — «Aquí puedes ver los días y horarios en que atiende cada
  médico, sin reservar nada. Empieza eligiendo tu hospital o policlínico.»
- **calendario_02** — «¡Muy bien! Ahora, elige la especialidad que quieres
  consultar.»
- **calendario_03** — «Estos son los médicos de esa especialidad. Toca uno,
  para ver su horario de atención.»
- **calendario_04** — «¡Eso es todo! Aquí ves los días, turnos y horas en que
  atiende este médico. Recuerda que esto es solo una consulta. Para sacar una
  ficha, usa Nueva Reserva, en Inicio. Puedes repetir este tutorial desde tu
  Perfil.»

## Tutorial: Generar un trámite (recorrido "tramites")

- **tramites_00** — «¡Hola! Vamos a generar un trámite, paso a paso. Empezamos
  desde Inicio. Toca la tarjeta Procedimientos COSSMIL.»
- **tramites_01** — «Aquí puedes generar documentos oficiales, con tus datos
  ya cargados. Los trámites se organizan por gerencia. Entra a Gerencia de
  Salud.»
- **tramites_02** — «¡Muy bien! Esta gerencia agrupa sus dependencias. Entra a
  Hospital.»
- **tramites_03** — «Ya casi llegamos. Cada categoría agrupa documentos. Abre
  Formularios.»
- **tramites_04** — «¡Listo! Cada tarjeta abre un formulario con tu nombre y
  cédula ya completados. Puedes imprimirlo, compartirlo o descargarlo. Y
  puedes repetir este tutorial desde tu Perfil.»

## Modo Guiado — reserva REAL narrada (recorrido "guiado")

> Registro tonal DISTINTO al resto: profesional, institucional militar (COSSMIL,
> Bolivia), trato de usted, sin jergas ni signos de exclamación de apertura.
> Frases cortas: la locución respira en cada coma, y en voz sintética una
> subordinada larga sale atropellada.
> La instructora recuerda que la cita es REAL. Un clip por pantalla del flujo de
> reserva real (Regional → Especialidad → Médico → Día → Hora → Confirmar) más
> intro y cierre. Si cambia el texto de una burbuja, regenerar ese clip.

- **guiado_intro** — «Bienvenido a la reserva guiada de COSSMIL. Le acompañaré
  paso a paso. Tenga en cuenta que esta reserva es real, y su cita quedará
  registrada. Comencemos.»
- **guiado_regional** — «Primero, elija el hospital o policlínico donde desea
  atenderse. Están ordenados por regional.»
- **guiado_especialidad** — «Ahora, elija la especialidad médica que
  necesita.»
- **guiado_medico** — «Muy bien. Elija al médico con quien desea atenderse.»
- **guiado_dia** — «Elija el día de su cita. Cada tarjeta le muestra si el
  médico atiende, y si hay fichas disponibles.»
- **guiado_hora** — «Ahora, elija el horario que prefiera.»
- **guiado_confirmar** — «Revise que sus datos sean correctos. Cuando esté
  listo, presione Confirmar, y su cita quedará registrada.»
- **guiado_final** — «Su cita fue registrada con éxito. Puede ver o descargar
  su ficha cuando lo necesite. Gracias por confiar en COSSMIL.»
