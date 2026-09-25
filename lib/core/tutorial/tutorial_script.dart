/// Guion de la instructora: qué dice en cada paso de cada recorrido.
///
/// Fuente ÚNICA de las burbujas. La clave es el id del clip de voz
/// (`assets/vof_tutorial/<id>.mp3`) y el valor son las burbujas de ese paso,
/// en orden de aparición. Unidas con un espacio dan EXACTAMENTE la línea que
/// la locución pronuncia — así está escrito en `tools/rvc/tutorial_lines.json`
/// y así lo verifica `test/core/tutorial_script_test.dart`.
///
/// El corte en varias burbujas es solo ritmo de chat: la instructora suelta
/// una idea por globo mientras la voz lee la frase entera de corrido. Por eso
/// se parte en los puntos de la locución y nunca a media frase, y por eso no
/// hay emojis — el clip no los pronuncia y el lector de pantalla los deletrea.
///
/// Si cambia el texto de un paso: edítalo aquí Y en `tutorial_lines.json`, y
/// regenera ese mp3 (ver `tools/rvc/README.md`). Cambiar solo uno de los tres
/// deja a la instructora diciendo una cosa y mostrando otra, que es justo lo
/// que pasó al regenerar las voces con el modelo nuevo.
library;

/// Burbujas por id de clip. Ver la doc de la librería para el contrato.
const Map<String, List<String>> kTutorialScript = {
  // ─── Invitación (primera vez en Inicio) ────────────────────────────────
  // La primera burbuja es el título del diálogo y la segunda su cuerpo.
  'invite': [
    '¡Bienvenido a COSSMIL!',
    'Soy tu instructora. Te puedo enseñar a sacar una ficha, es decir, una '
        'cita médica, paso a paso. Toma menos de un minuto, y puedes repetir '
        'el tutorial cuando quieras, desde tu Perfil.',
  ],

  // ─── Recorrido "ficha": sacar una cita (demostración) ──────────────────
  'ficha_00': [
    '¡Hola! Vamos a sacar tu primera ficha juntos.',
    'Todo empieza aquí, en Inicio.',
    'Toca la primera opción del menú, el botón verde, Nueva Reserva.',
  ],
  'ficha_01': [
    '¡Muy bien! Así se inicia una reserva.',
    'Ahora, elige tu hospital o policlínico.',
    'Estos son los que tienes habilitados, agrupados por regional.',
  ],
  'ficha_02': [
    '¡Muy bien!',
    'Ahora, elige la especialidad médica que necesitas.',
  ],
  'ficha_03': [
    'Estos son los médicos disponibles para esa especialidad.',
    'Elige el que prefieras.',
  ],
  'ficha_04': [
    'Ahora, elige el día.',
    'Cada tarjeta te muestra si el médico atiende, y si quedan fichas.',
  ],
  'ficha_05': [
    '¡Ya casi terminamos!',
    'Elige un horario disponible, dentro del día que escogiste.',
  ],
  'ficha_06': [
    'Revisa que todos los datos estén correctos.',
    'Luego, toca Confirmar Reserva.',
    'No te preocupes, aquí no se creará ninguna cita real.',
  ],
  'ficha_07': [
    '¡Misión cumplida!',
    'Esto fue solo una demostración, y no se creó ninguna cita real.',
    'Puedes ver tu ficha de ejemplo, o volver al inicio.',
  ],

  // ─── Recorrido "calendario": consultar horarios (solo lectura) ─────────
  'calendario_00': [
    '¡Hola! Te voy a enseñar a consultar los horarios de los médicos.',
    'Empezamos desde Inicio.',
    'Toca la tarjeta Calendario de Atención.',
  ],
  'calendario_01': [
    'Aquí puedes ver los días y horarios en que atiende cada médico, sin '
        'reservar nada.',
    'Empieza eligiendo tu hospital o policlínico.',
  ],
  'calendario_02': [
    '¡Muy bien!',
    'Ahora, elige la especialidad que quieres consultar.',
  ],
  'calendario_03': [
    'Estos son los médicos de esa especialidad.',
    'Toca uno, para ver su horario de atención.',
  ],
  'calendario_04': [
    '¡Eso es todo!',
    'Aquí ves los días, turnos y horas en que atiende este médico.',
    'Recuerda que esto es solo una consulta. Para sacar una ficha, usa Nueva '
        'Reserva, en Inicio.',
    'Puedes repetir este tutorial desde tu Perfil.',
  ],

  // ─── Recorrido "tramites": generar un documento ────────────────────────
  'tramites_00': [
    '¡Hola! Vamos a generar un trámite, paso a paso.',
    'Empezamos desde Inicio.',
    'Toca la tarjeta Procedimientos COSSMIL.',
  ],
  'tramites_01': [
    'Aquí puedes generar documentos oficiales, con tus datos ya cargados.',
    'Los trámites se organizan por gerencia.',
    'Entra a Gerencia de Salud.',
  ],
  'tramites_02': [
    '¡Muy bien!',
    'Esta gerencia agrupa sus dependencias.',
    'Entra a Hospital.',
  ],
  'tramites_03': [
    'Ya casi llegamos.',
    'Cada categoría agrupa documentos.',
    'Abre Formularios.',
  ],
  'tramites_04': [
    '¡Listo!',
    'Cada tarjeta abre un formulario con tu nombre y cédula ya completados.',
    'Puedes imprimirlo, compartirlo o descargarlo.',
    'Y puedes repetir este tutorial desde tu Perfil.',
  ],

  // ─── Modo Guiado: la MISMA reserva real, narrada ───────────────────────
  // Registro distinto al resto (trato de usted, institucional): aquí la cita
  // se registra de verdad y la instructora no puede sonar a demostración.
  'guiado_intro': [
    'Bienvenido a la reserva guiada de COSSMIL. Le acompañaré paso a paso.',
    'Tenga en cuenta que esta reserva es real, y su cita quedará registrada.',
    'Comencemos.',
  ],
  'guiado_regional': [
    'Primero, elija el hospital o policlínico donde desea atenderse.',
    'Están ordenados por regional.',
  ],
  'guiado_especialidad': ['Ahora, elija la especialidad médica que necesita.'],
  'guiado_medico': ['Muy bien.', 'Elija al médico con quien desea atenderse.'],
  'guiado_dia': [
    'Elija el día de su cita.',
    'Cada tarjeta le muestra si el médico atiende, y si hay fichas disponibles.',
  ],
  'guiado_hora': ['Ahora, elija el horario que prefiera.'],
  'guiado_confirmar': [
    'Revise que sus datos sean correctos.',
    'Cuando esté listo, presione Confirmar, y su cita quedará registrada.',
  ],
  'guiado_final': [
    'Su cita fue registrada con éxito.',
    'Puede ver o descargar su ficha cuando lo necesite.',
    'Gracias por confiar en COSSMIL.',
  ],
};

/// Burbujas del clip [voiceId]. Lista vacía si no hay guion para ese id (o si
/// es null): el coach se monta igual, solo que sin texto — nunca revienta por
/// un id que todavía no tiene locución.
List<String> tutorialBubbles(String? voiceId) =>
    kTutorialScript[voiceId] ?? const [];
