/* ============================================================================
   ESTADÍSTICAS ADMIN — COSSMIL
   Consultas de agregación para el micro-servicio de estadísticas.

   OBJETIVO: alimentar gráficos (tortas/barras) SIN cargar la BD de producción.

   CÓMO USAR (en el micro-servicio, NO en la app):
     1. El servicio corre estas consultas 1× por hora o por día (cron).
     2. Cachea el resultado (memoria/JSON) y expone GET /estadisticas.
     3. La app Flutter SOLO consume ese endpoint cacheado.

   DECISIONES PARA NO IMPACTAR LA BD:
     - READ UNCOMMITTED: no toma bloqueos sobre tablas de producción (citas
       pesa ~2.2 GB). Lee datos aproximados — aceptable para estadística.
     - Filtrado SIEMPRE por rango de fechas (@desde/@hasta).
     - GROUP BY: devuelve filas resumidas (KB), no las filas crudas.

   ⚠️ A VERIFICAR CONTRA EL DICCIONARIO DE DATOS (marcado con «VERIFICAR»):
     - Tipo real de citas.fecha_cita (date vs datetime/char).
     - Significado y valores de citas.estado (códigos → etiquetas).
     - Mapeo de citas.idesp a la tabla parametrica (qué idtipo es especialidad).
   ============================================================================ */

-- Lee sin bloquear: las estadísticas no deben frenar la operación real.
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

-- Parámetros de rango. El micro-servicio los inyecta (ej. últimos 12 meses).
DECLARE @desde date = DATEADD(MONTH, -12, CAST(GETDATE() AS date));
DECLARE @hasta date = DATEADD(DAY, 1, CAST(GETDATE() AS date)); -- exclusivo


/* ----------------------------------------------------------------------------
   1) CITAS POR ESTADO  → gráfico de TORTA
   estado es un código; mapear a etiqueta en el micro-servicio o aquí con CASE.
   «VERIFICAR» los valores reales de estado.
---------------------------------------------------------------------------- */
SELECT
    c.estado,
    COUNT(*) AS total
FROM citas AS c
WHERE c.fecha_cita >= @desde
  AND c.fecha_cita <  @hasta
GROUP BY c.estado
ORDER BY total DESC;


/* ----------------------------------------------------------------------------
   2) CITAS POR MES  → gráfico de BARRAS (serie temporal)
---------------------------------------------------------------------------- */
SELECT
    YEAR(c.fecha_cita)  AS anio,
    MONTH(c.fecha_cita) AS mes,
    COUNT(*)            AS total
FROM citas AS c
WHERE c.fecha_cita >= @desde
  AND c.fecha_cita <  @hasta
GROUP BY YEAR(c.fecha_cita), MONTH(c.fecha_cita)
ORDER BY anio, mes;


/* ----------------------------------------------------------------------------
   3) TOP 10 ESPECIALIDADES por demanda  → BARRAS
   «VERIFICAR»: cómo se obtiene el nombre de la especialidad.
   Aquí se asume que está en parametrica (idpar = idesp). Si el nombre vive en
   otra tabla o requiere filtrar por par_tipo, ajustar el JOIN.
---------------------------------------------------------------------------- */
SELECT TOP 10
    c.idesp,
    COALESCE(p.des, CONCAT('Esp. ', c.idesp)) AS especialidad,
    COUNT(*) AS total
FROM citas AS c
LEFT JOIN parametrica AS p
       ON p.idpar = c.idesp        -- «VERIFICAR» (¿y un AND p.idtipo = <X>?)
WHERE c.fecha_cita >= @desde
  AND c.fecha_cita <  @hasta
GROUP BY c.idesp, p.des
ORDER BY total DESC;


/* ----------------------------------------------------------------------------
   4) CITAS POR HOSPITAL / SUCURSAL  → BARRAS o TORTA
   sucursal tiene clave compuesta (idins, idsuc) y el nombre en 'des'.
---------------------------------------------------------------------------- */
SELECT
    c.idins,
    c.idsuc,
    COALESCE(s.des, CONCAT('Suc. ', c.idins, '-', c.idsuc)) AS hospital,
    COUNT(*) AS total
FROM citas AS c
LEFT JOIN sucursal AS s
       ON s.idins = c.idins
      AND s.idsuc = c.idsuc
WHERE c.fecha_cita >= @desde
  AND c.fecha_cita <  @hasta
GROUP BY c.idins, c.idsuc, s.des
ORDER BY total DESC;


/* ----------------------------------------------------------------------------
   5) TOP 10 MÉDICOS por demanda  → BARRAS
   Nombre del médico desde la tabla medico (nom + pat + mat).
---------------------------------------------------------------------------- */
SELECT TOP 10
    c.idmed,
    LTRIM(RTRIM(
        ISNULL(m.nom,'') + ' ' + ISNULL(m.pat,'') + ' ' + ISNULL(m.mat,'')
    )) AS medico,
    COUNT(*) AS total
FROM citas AS c
LEFT JOIN medico AS m
       ON m.idmed = c.idmed
WHERE c.fecha_cita >= @desde
  AND c.fecha_cita <  @hasta
GROUP BY c.idmed, m.nom, m.pat, m.mat
ORDER BY total DESC;


/* ----------------------------------------------------------------------------
   6) OFERTA vs DEMANDA por día  → BARRAS agrupadas o líneas
   medagendacab ya trae oferta/demanda pre-calculados por agenda → muy barato.
   «VERIFICAR» el tipo de la columna fecha en medagendacab.
---------------------------------------------------------------------------- */
SELECT
    CAST(a.fecha AS date) AS fecha,
    SUM(a.oferta)         AS oferta,
    SUM(a.demanda)        AS demanda
FROM medagendacab AS a
WHERE a.fecha >= @desde
  AND a.fecha <  @hasta
GROUP BY CAST(a.fecha AS date)
ORDER BY fecha;


/* ----------------------------------------------------------------------------
   7) CALIFICACIÓN PROMEDIO de médicos  → BARRAS (Top mejor calificados)
   Desde medcalificacion. HAVING evita rankear médicos con muy pocas reseñas.
   «VERIFICAR» que calificacion sea numérica.
---------------------------------------------------------------------------- */
SELECT TOP 10
    mc.idmed,
    LTRIM(RTRIM(
        ISNULL(m.nom,'') + ' ' + ISNULL(m.pat,'') + ' ' + ISNULL(m.mat,'')
    )) AS medico,
    AVG(CAST(mc.calificacion AS float)) AS promedio,
    COUNT(*)                            AS reseñas
FROM medcalificacion AS mc
LEFT JOIN medico AS m
       ON m.idmed = mc.idmed
GROUP BY mc.idmed, m.nom, m.pat, m.mat
HAVING COUNT(*) >= 5
ORDER BY promedio DESC;


/* ----------------------------------------------------------------------------
   8) KPIs RESUMEN (tarjetas: total citas, médicos activos, etc.)  → una fila
---------------------------------------------------------------------------- */
SELECT
    COUNT(*)                          AS total_citas,
    COUNT(DISTINCT c.idmed)           AS medicos_con_citas,
    COUNT(DISTINCT c.idesp)           AS especialidades_activas,
    COUNT(DISTINCT CONCAT(c.idins,'-',c.idsuc)) AS hospitales_activos
FROM citas AS c
WHERE c.fecha_cita >= @desde
  AND c.fecha_cita <  @hasta;
