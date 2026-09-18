# Guion de voz — instructora del tutorial COSSMIL

Documento autocontenido para entregar a un modelo de voz (TTS o clonación).
Contiene **18 clips**. Cada clip es un archivo independiente.

## Instrucciones para la generación

- **Idioma:** español de Bolivia (neutro andino). Evitar seseo peninsular y
  muletillas mexicanas marcadas.
- **Voz:** femenina, joven-adulta. Es una instructora amable que acompaña a un
  usuario mayor usando la app por primera vez.
- **Tono:** cálido, cercano, paciente. Ritmo **pausado** (ligeramente más lento
  que conversacional): mucha gente mayor la escucha mientras mira la pantalla.
- **Energía:** las líneas que empiezan con "¡Hola!", "¡Muy bien!", "¡Listo!",
  "¡Eso es todo!" o "¡Misión cumplida!" son de felicitación — suben un punto de
  entusiasmo, sin gritar.
- **Nombres de botones:** las palabras entre comillas ("Nueva Reserva",
  "Calendario de Atención", "Procedimientos COSSMIL", "Gerencia de Salud",
  "Hospital", "Formularios", "Confirmar Reserva") se pronuncian con un
  pequeño énfasis y una micropausa antes: son lo que el usuario debe tocar.
- **Siglas:** "COSSMIL" se pronuncia como palabra ("cosmil"), no deletreada.
- **Formato de salida:** MP3 mono, 44.1 kHz, sin silencio inicial y con máximo
  ~300 ms de silencio final.
- **Nombre de archivo:** exactamente el `id` del clip + `.mp3`
  (ej. `ficha_00.mp3`). Sin prefijos ni numeración extra.

---

## Recorrido 0 — Invitación

Aparece la primera vez que el usuario entra al inicio de la app.

**`invite`**
> ¡Bienvenido a COSSMIL! Soy tu instructora y te puedo enseñar a sacar una ficha, una cita médica, paso a paso. Toma menos de un minuto y puedes repetir el tutorial cuando quieras desde tu Perfil.

---

## Recorrido 1 — Sacar una ficha (8 clips)

**`ficha_00`**
> ¡Hola! Vamos a sacar tu primera ficha juntos. Todo empieza aquí, en Inicio: toca la primera opción del menú, el botón verde "Nueva Reserva".

**`ficha_01`**
> ¡Muy bien! Así se inicia una reserva. Ahora elige tu hospital o policlínico; estos son los que tienes habilitados, agrupados por regional.

**`ficha_02`**
> ¡Muy bien! Ahora elige la especialidad médica que necesitas.

**`ficha_03`**
> Estos son los médicos disponibles para esa especialidad. Elige el que prefieras.

**`ficha_04`**
> Ahora elige el día; cada tarjeta muestra si el médico atiende y si quedan fichas.

**`ficha_05`**
> ¡Ya casi terminamos! Elige un horario disponible dentro del día que escogiste.

**`ficha_06`**
> Revisa que todos los datos estén correctos. Toca "Confirmar Reserva"; no te preocupes: aquí no se creará ninguna cita real.

**`ficha_07`** *(cierre, celebratorio)*
> ¡Misión cumplida! Esto fue solo una demostración; no se creó ninguna cita real. Puedes ver tu ficha de ejemplo o volver al inicio.

---

## Recorrido 2 — Consultar horarios (5 clips)

**`calendario_00`**
> ¡Hola! Te voy a enseñar a consultar los horarios de los médicos. Empezamos desde Inicio: toca la tarjeta "Calendario de Atención".

**`calendario_01`**
> Aquí puedes ver los días y horarios en que atiende cada médico, sin reservar nada. Empieza eligiendo tu hospital o policlínico.

**`calendario_02`**
> ¡Muy bien! Ahora elige la especialidad que quieres consultar.

**`calendario_03`**
> Estos son los médicos de esa especialidad. Toca uno para ver su horario de atención.

**`calendario_04`** *(cierre, celebratorio)*
> ¡Eso es todo! Aquí ves los días, turnos y horas en que atiende este médico. Recuerda: esto es solo consulta; para sacar una ficha usa "Nueva Reserva" en Inicio. Puedes repetir este tutorial desde tu Perfil.

---

## Recorrido 3 — Generar un trámite (5 clips)

**`tramites_00`**
> ¡Hola! Vamos a generar un trámite paso a paso. Empezamos desde Inicio: toca la tarjeta "Procedimientos COSSMIL".

**`tramites_01`**
> Aquí puedes generar documentos oficiales con tus datos ya cargados. Los trámites se organizan por gerencia: entra a "Gerencia de Salud".

**`tramites_02`**
> ¡Muy bien! Esta gerencia agrupa sus dependencias. Entra a "Hospital".

**`tramites_03`**
> Ya casi llegamos. Cada categoría agrupa documentos. Abre "Formularios".

**`tramites_04`** *(cierre, celebratorio)*
> ¡Listo! Cada tarjeta abre un formulario con tu nombre y cédula ya completados, listo para imprimir, compartir o descargar. Puedes repetir este tutorial desde tu Perfil.

---

## Apéndice — Bloque plano para copiar y pegar

Un clip por línea, formato `nombre_de_archivo | texto`.

```
invite | ¡Bienvenido a COSSMIL! Soy tu instructora y te puedo enseñar a sacar una ficha, una cita médica, paso a paso. Toma menos de un minuto y puedes repetir el tutorial cuando quieras desde tu Perfil.
ficha_00 | ¡Hola! Vamos a sacar tu primera ficha juntos. Todo empieza aquí, en Inicio: toca la primera opción del menú, el botón verde Nueva Reserva.
ficha_01 | ¡Muy bien! Así se inicia una reserva. Ahora elige tu hospital o policlínico; estos son los que tienes habilitados, agrupados por regional.
ficha_02 | ¡Muy bien! Ahora elige la especialidad médica que necesitas.
ficha_03 | Estos son los médicos disponibles para esa especialidad. Elige el que prefieras.
ficha_04 | Ahora elige el día; cada tarjeta muestra si el médico atiende y si quedan fichas.
ficha_05 | ¡Ya casi terminamos! Elige un horario disponible dentro del día que escogiste.
ficha_06 | Revisa que todos los datos estén correctos. Toca Confirmar Reserva; no te preocupes: aquí no se creará ninguna cita real.
ficha_07 | ¡Misión cumplida! Esto fue solo una demostración; no se creó ninguna cita real. Puedes ver tu ficha de ejemplo o volver al inicio.
calendario_00 | ¡Hola! Te voy a enseñar a consultar los horarios de los médicos. Empezamos desde Inicio: toca la tarjeta Calendario de Atención.
calendario_01 | Aquí puedes ver los días y horarios en que atiende cada médico, sin reservar nada. Empieza eligiendo tu hospital o policlínico.
calendario_02 | ¡Muy bien! Ahora elige la especialidad que quieres consultar.
calendario_03 | Estos son los médicos de esa especialidad. Toca uno para ver su horario de atención.
calendario_04 | ¡Eso es todo! Aquí ves los días, turnos y horas en que atiende este médico. Recuerda: esto es solo consulta; para sacar una ficha usa Nueva Reserva en Inicio. Puedes repetir este tutorial desde tu Perfil.
tramites_00 | ¡Hola! Vamos a generar un trámite paso a paso. Empezamos desde Inicio: toca la tarjeta Procedimientos COSSMIL.
tramites_01 | Aquí puedes generar documentos oficiales con tus datos ya cargados. Los trámites se organizan por gerencia: entra a Gerencia de Salud.
tramites_02 | ¡Muy bien! Esta gerencia agrupa sus dependencias. Entra a Hospital.
tramites_03 | Ya casi llegamos. Cada categoría agrupa documentos. Abre Formularios.
tramites_04 | ¡Listo! Cada tarjeta abre un formulario con tu nombre y cédula ya completados, listo para imprimir, compartir o descargar. Puedes repetir este tutorial desde tu Perfil.
```

---

## Dónde van los archivos generados

`assets/vof_tutorial/<id>.mp3` dentro del proyecto Flutter. La app los busca
por ese nombre exacto (`voiceId` en cada pantalla del tutorial); si falta un
clip, el paso simplemente se muestra sin voz.

La fuente de verdad de estos textos son las burbujas del coach en el código;
si cambias una burbuja, actualiza también `tools/rvc/tutorial_lines.json` y
este guion, y regenera ese clip.
