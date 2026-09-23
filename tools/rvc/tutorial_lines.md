# Guion de voz del tutorial — instructora COSSMIL

Cada línea es UN clip de audio. El `id` es el nombre de archivo final:
`assets/vof_tutorial/<id>.mp3`. El texto es exactamente lo que dicen las
burbujas del coach en cada paso (sin emojis, que no se leen). Si cambias el
texto de una burbuja en el código, actualiza aquí y regenera ese clip.

La versión legible por máquina (para los scripts) está en `tutorial_lines.json`.

---

## Invitación (aparece la primera vez en Inicio)

- **invite** — «¡Bienvenido a COSSMIL! Soy tu instructora y te puedo enseñar a
  sacar una ficha, una cita médica, paso a paso. Toma menos de un minuto y
  puedes repetir el tutorial cuando quieras desde tu Perfil.»

## Tutorial: Sacar una ficha (recorrido "ficha")

- **ficha_00** — «¡Hola! Vamos a sacar tu primera ficha juntos. Todo empieza
  aquí, en Inicio: toca la primera opción del menú, el botón verde "Nueva
  Reserva".»
- **ficha_01** — «¡Muy bien! Así se inicia una reserva. Ahora elige tu hospital
  o policlínico; estos son los que tienes habilitados, agrupados por regional.»
- **ficha_02** — «¡Muy bien! Ahora elige la especialidad médica que necesitas.»
- **ficha_03** — «Estos son los médicos disponibles para esa especialidad.
  Elige el que prefieras.»
- **ficha_04** — «Ahora elige el día; cada tarjeta muestra si el médico atiende
  y si quedan fichas.»
- **ficha_05** — «¡Ya casi terminamos! Elige un horario disponible dentro del
  día que escogiste.»
- **ficha_06** — «Revisa que todos los datos estén correctos. Toca "Confirmar
  Reserva"; no te preocupes: aquí no se creará ninguna cita real.»
- **ficha_07** — «¡Misión cumplida! Esto fue solo una demostración; no se creó
  ninguna cita real. Puedes ver tu ficha de ejemplo o volver al inicio.»

## Tutorial: Consultar horarios (recorrido "calendario")

- **calendario_00** — «¡Hola! Te voy a enseñar a consultar los horarios de los
  médicos. Empezamos desde Inicio: toca la tarjeta "Calendario de Atención".»
- **calendario_01** — «Aquí puedes ver los días y horarios en que atiende cada
  médico, sin reservar nada. Empieza eligiendo tu hospital o policlínico.»
- **calendario_02** — «¡Muy bien! Ahora elige la especialidad que quieres
  consultar.»
- **calendario_03** — «Estos son los médicos de esa especialidad. Toca uno para
  ver su horario de atención.»
- **calendario_04** — «¡Eso es todo! Aquí ves los días, turnos y horas en que
  atiende este médico. Recuerda: esto es solo consulta; para sacar una ficha
  usa "Nueva Reserva" en Inicio. Puedes repetir este tutorial desde tu Perfil.»

## Tutorial: Generar un trámite (recorrido "tramites")

- **tramites_00** — «¡Hola! Vamos a generar un trámite paso a paso. Empezamos
  desde Inicio: toca la tarjeta "Procedimientos COSSMIL".»
- **tramites_01** — «Aquí puedes generar documentos oficiales con tus datos ya
  cargados. Los trámites se organizan por gerencia: entra a "Gerencia de
  Salud".»
- **tramites_02** — «¡Muy bien! Esta gerencia agrupa sus dependencias. Entra a
  "Hospital".»
- **tramites_03** — «Ya casi llegamos. Cada categoría agrupa documentos. Abre
  "Formularios".»
- **tramites_04** — «¡Listo! Cada tarjeta abre un formulario con tu nombre y
  cédula ya completados, listo para imprimir, compartir o descargar. Puedes
  repetir este tutorial desde tu Perfil.»

## Modo Guiado — reserva REAL narrada (recorrido "guiado")

> Registro tonal DISTINTO al resto: profesional, institucional militar (COSSMIL,
> Bolivia), trato de usted, sin jergas ni signos de exclamación de apertura.
> La instructora recuerda que la cita es REAL. Un clip por pantalla del flujo de
> reserva real (Regional → Especialidad → Médico → Día → Hora → Confirmar) más
> intro y cierre. Si cambia el texto de una burbuja, regenerar ese clip.

- **guiado_intro** — «Bienvenido al asistente de reserva guiada de COSSMIL. Le
  acompañaré en cada paso. Tenga presente que esta gestión registrará una cita
  médica real. Le indicaré qué hacer en cada pantalla y usted seleccionará las
  opciones que correspondan. Comencemos.»
- **guiado_regional** — «Seleccione el establecimiento donde desea ser atendido.
  Los hospitales y policlínicos se encuentran agrupados por regional.»
- **guiado_especialidad** — «Seleccione la especialidad médica que requiere.»
- **guiado_medico** — «Seleccione al profesional médico con quien desea reservar
  su cita.»
- **guiado_dia** — «Seleccione el día de atención. Cada tarjeta indica si el
  médico atiende y la disponibilidad de fichas.»
- **guiado_hora** — «Seleccione el horario de su preferencia dentro del día
  elegido.»
- **guiado_confirmar** — «Verifique que sus datos sean correctos. Al presionar
  Confirmar, su cita quedará registrada de manera definitiva.»
- **guiado_final** — «Su cita ha sido registrada correctamente. Puede consultar
  o descargar su ficha. Gracias por utilizar los servicios de COSSMIL.»
