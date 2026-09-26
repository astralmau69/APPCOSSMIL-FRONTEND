# Guion de grabación para la locutora — COSSMIL

**Para qué sirve.** Hoy el motor de voz solo tiene **~40 segundos** de la voz de la
locutora (las 7 locuciones de `assets/vof/`). Es lo que más limita el parecido y la
naturalidad. Con **10–15 minutos** de grabación limpia:

1. El motor tiene **referencias mucho mejores** para clonar la voz (más parecido,
   entonación más natural).
2. Se abre la puerta a **ajustar (fine-tuning) el modelo** con su voz — hoy no tiene
   sentido con 40 s.
3. Y lo mejor para la app: si ella graba directamente las **frases de la app (Parte A)**,
   esos audios son **voz humana real**, sin ningún artefacto. La clonación queda para los
   textos que no se graben o que cambien después.

## Cómo grabar (importante)

- **Mismo lugar y mismo micrófono** que se usaron para las locuciones `vof`; misma
  distancia al micrófono (un palmo) y mismo tono calmado e institucional.
- Habitación **silenciosa**: sin ventilador, aire acondicionado, música, eco ni otras voces.
  Mejor un cuarto con cortinas o muebles que uno vacío.
- Formato: **WAV** (o FLAC), **44,1 o 48 kHz**, 16 o 24 bits, **mono**. Si solo hay
  celular, grabar en la app de grabadora en máxima calidad, sin "mejoras" ni filtros.
- **Sin procesar**: nada de compresión, reverberación ni "reducción de ruido" del editor.
- Dejar **1 segundo de silencio** entre frase y frase. Si se equivoca, repetir la frase
  completa (luego se corta).
- Grabar **por bloques** (un archivo por bloque): `A1_guiado.wav`, `A2_tutorial.wav`,
  `B1.wav`, `B2.wav`, … Así el notebook tiene varias referencias entre las que elegir.

## Dónde ponerlas

Subir los archivos a **Google Drive → `Mi unidad/cossmil_rvc/audio_extra/`**. El notebook
(`tools/rvc/COSSMIL_estudio_voz.ipynb`) los detecta solo, vuelve a elegir la mejor
referencia y genera con la voz mejorada. (Las grabaciones directas de la Parte A, además,
se pueden limpiar y exportar tal cual para la app.)

---

## Parte A1 — Modo Guiado (trato de usted, tono institucional) · ~1 min

1. `guiado_intro` — Bienvenido a la reserva guiada de COSSMIL. Le acompañaré paso a paso. Tenga en cuenta que esta reserva es real, y su cita quedará registrada. Comencemos.
2. `guiado_regional` — Primero, elija el hospital o policlínico donde desea atenderse. Están ordenados por regional.
3. `guiado_especialidad` — Ahora, elija la especialidad médica que necesita.
4. `guiado_medico` — Muy bien. Ahora, elija al médico con quien desea realizar su consulta.
5. `guiado_dia` — Elija el día de su cita. Los días en rojo no tienen fichas disponibles. Para continuar, seleccione un día en verde, que sí tiene fichas disponibles.
6. `guiado_hora` — Ahora, elija el horario de su preferencia.
7. `guiado_confirmar` — Revise que sus datos sean correctos. Cuando esté listo, presione Confirmar.
8. `guiado_aviso` — Antes de continuar, lea con atención este aviso importante. Si acumula tres inasistencias, se suspenderá su acceso para sacar fichas en línea. Cuando termine de leerlo, presione Entiendo, continuar con la reserva.
9. `guiado_registrada` — Su cita fue registrada con éxito. Si desea verla, presione Ver Imagen de la Cita Médica.
10. `guiado_ficha` — Esta es la imagen de su cita médica. Con Descargar, puede guardarla o imprimirla. Con Compartir, puede enviarla a quien desee. Gracias por su atención, que tenga un buen día.
11. `guiado_despedida` — Gracias por su atención. Le esperamos en su próxima reserva.

## Parte A2 — Tutoriales (tono cercano, de "tú") · ~2 min

1. `invite` — ¡Bienvenido a COSSMIL! Soy tu instructora. Te puedo enseñar a sacar una ficha, es decir, una cita médica, paso a paso. Toma menos de un minuto, y puedes repetir el tutorial cuando quieras, desde tu Perfil.
2. `ficha_00` — ¡Hola! Vamos a sacar tu primera ficha juntos. Todo empieza aquí, en Inicio. Toca la primera opción del menú, el botón verde, Nueva Reserva.
3. `ficha_01` — ¡Muy bien! Así se inicia una reserva. Ahora, elige tu hospital o policlínico. Estos son los que tienes habilitados, agrupados por regional.
4. `ficha_02` — ¡Muy bien! Ahora, elige la especialidad médica que necesitas.
5. `ficha_03` — Estos son los médicos disponibles para esa especialidad. Elige el que prefieras.
6. `ficha_04` — Ahora, elige el día. Cada tarjeta te muestra si el médico atiende, y si quedan fichas.
7. `ficha_05` — ¡Ya casi terminamos! Elige un horario disponible, dentro del día que escogiste.
8. `ficha_06` — Revisa que todos los datos estén correctos. Luego, toca Confirmar Reserva. No te preocupes, aquí no se creará ninguna cita real.
9. `ficha_07` — ¡Misión cumplida! Esto fue solo una demostración, y no se creó ninguna cita real. Puedes ver tu ficha de ejemplo, o volver al inicio.
10. `calendario_00` — ¡Hola! Te voy a enseñar a consultar los horarios de los médicos. Empezamos desde Inicio. Toca la tarjeta Calendario de Atención.
11. `calendario_01` — Aquí puedes ver los días y horarios en que atiende cada médico, sin reservar nada. Empieza eligiendo tu hospital o policlínico.
12. `calendario_02` — ¡Muy bien! Ahora, elige la especialidad que quieres consultar.
13. `calendario_03` — Estos son los médicos de esa especialidad. Toca uno, para ver su horario de atención.
14. `calendario_04` — ¡Eso es todo! Aquí ves los días, turnos y horas en que atiende este médico. Recuerda que esto es solo una consulta. Para sacar una ficha, usa Nueva Reserva, en Inicio. Puedes repetir este tutorial desde tu Perfil.
15. `tramites_00` — ¡Hola! Vamos a generar un trámite, paso a paso. Empezamos desde Inicio. Toca la tarjeta Procedimientos COSSMIL.
16. `tramites_01` — Aquí puedes generar documentos oficiales, con tus datos ya cargados. Los trámites se organizan por gerencia. Entra a Gerencia de Salud.
17. `tramites_02` — ¡Muy bien! Esta gerencia agrupa sus dependencias. Entra a Hospital.
18. `tramites_03` — Ya casi llegamos. Cada categoría agrupa documentos. Abre Formularios.
19. `tramites_04` — ¡Listo! Cada tarjeta abre un formulario con tu nombre y cédula ya completados. Puedes imprimirlo, compartirlo o descargarlo. Y puedes repetir este tutorial desde tu Perfil.

## Parte B — Frases variadas (mismo tono calmado) · ~4–5 min

Sirven para que el motor aprenda cómo suena ella en situaciones distintas: preguntas,
números, fechas, sonidos difíciles (rr, ñ, ll, j, z) y frases largas.

1. Buenos días. Bienvenido a la Corporación del Seguro Social Militar.
2. Su cita médica fue programada para el martes quince de octubre, a las ocho y treinta de la mañana.
3. Le recordamos presentarse quince minutos antes de su consulta, con su carnet de asegurado.
4. Si no puede asistir, cancele su cita hasta las seis de la mañana del día asignado.
5. El Hospital Militar Central atiende de lunes a viernes, de siete a diecinueve horas.
6. Por favor, verifique que su número de teléfono esté actualizado en su perfil.
7. Estimado asegurado, su solicitud fue registrada correctamente.
8. Para más información, comuníquese con la agencia regional más cercana.
9. La especialidad de cardiología no tiene fichas disponibles para esta fecha.
10. Puede consultar el horario de atención de cada médico en el calendario.
11. ¿Desea reservar una cita para usted o para un familiar?
12. ¿Está seguro de que quiere cancelar su reserva?
13. ¡Muy bien! Su trámite está casi listo.
14. ¡Atención! Su sesión se cerrará en un minuto por inactividad.
15. ¿Necesita ayuda? Toque el botón de soporte en la parte inferior.
16. El perro corre rápido por la carretera del cerro.
17. La niña pequeña llevaba un pañuelo amarillo y una mochila.
18. Juan y Jorge jugaban ajedrez junto al gimnasio.
19. El examen de la próxima semana será en el auditorio.
20. Cinco zapatos azules quedaron cerca de la plaza.
21. Muchas gracias por su paciencia y comprensión.
22. Hoy hace un día claro y tranquilo en la ciudad de La Paz.
23. Los resultados del laboratorio estarán listos en cuarenta y ocho horas.
24. Siga las indicaciones de su médico y tome la medicación a tiempo.
25. El farmacéutico le explicará cómo usar el medicamento.
26. Uno, dos, tres, cuatro, cinco, seis, siete, ocho, nueve, diez.
27. Once, doce, trece, catorce, quince, veinte, treinta, cuarenta, cincuenta.
28. Cien, doscientos, quinientos, mil, dos mil veintiséis.
29. Lunes, martes, miércoles, jueves, viernes, sábado y domingo.
30. Enero, febrero, marzo, abril, mayo, junio, julio, agosto, septiembre, octubre, noviembre y diciembre.
31. Son las siete y cuarto. Su turno es a las nueve y media.
32. Recuerde que puede descargar su ficha, compartirla con su familia o imprimirla cuando la necesite, desde la sección de reservas.
33. Nuestro compromiso es brindarle una atención de calidad, con respeto y puntualidad, en cada uno de nuestros establecimientos de salud.
34. Si acumula tres inasistencias, el sistema suspenderá temporalmente su acceso para sacar fichas médicas en línea.
35. Le agradecemos por utilizar la aplicación de citas médicas de la Corporación del Seguro Social Militar.

---

**Total aproximado:** 8–10 minutos grabando con calma (las Partes A y B), más las pausas.
Si hay tiempo, repetir la Parte B con otro ánimo (más cálido o más formal) suma todavía
más variedad.
