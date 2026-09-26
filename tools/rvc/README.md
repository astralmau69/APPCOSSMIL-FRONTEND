# Voz de la instructora del tutorial (RVC v2)

Objetivo: que la instructora **diga en voz alta** cada paso del tutorial, con la
**misma voz** que las locuciones `vof` — sin pagar suscripciones, usando
**RVC v2** (Retrieval-based Voice Conversion, open-source).

> ⚠️ RVC **no corre en este repo/máquina** (necesita PyTorch + GPU + descargar
> modelos). Se entrena/convierte en **Google Colab** (gratis) o en un PC con
> GPU. Aquí queda todo lo PREVIO ya preparado: dataset, guion y narración fuente.

> **Usar `COSSMIL_estudio_voz.ipynb` (sep 2026).** La voz ya NO sale de edge-tts + RVC
> (sonaba robótica): se **clona directamente** de las `vof` con **Chatterbox
> Multilingual** (Resemble AI, licencia MIT, español), instalado en un entorno
> aislado (`/content/voz_env`, Python 3.11) para no chocar con el numpy/torch de Colab.
>
> - Celda 6 prepara una referencia por cada vof, clona la misma frase con cada una y
>   elige la más parecida (WavLM-SV + tono/ritmo/entonación). Se guarda en
>   `MyDrive/cossmil_rvc/modelo/referencia.wav` + `voz_clonada.json`.
> - Celda 7 (activa): voces del **Modo Guiado** (+ tutorial) → `vof_tutorial_*.zip`.
> - Celda 8: cualquier texto; `EXPRESIVIDAD`, `RITMO` (cfg), `VARIACION`, `SEMILLA`
>   (otra toma) y referencia manual (una vof concreta).
> - Cada frase se revisa por duración esperada (sílabas / ritmo de la locutora) y se
>   regenera si sale cortada o con balbuceo; los números pasan a palabras.
> - RVC (Applio) queda como refuerzo opcional (`REFORZAR_CON_RVC`, apagado).
> - Motor: `estudio_voz_lib.py` (pruebas: `python3 tools/rvc/test_estudio_voz_lib.py`);
>   notebook: `python3 tools/rvc/build_colab_notebook.py` (nunca editar el `.ipynb`).
>
> - Cada toma se limpia (DeepFilterNet), se mide (DNSMOS: fondo ≥ 4,0 como las vof), se
>   compara con la huella de la locutora (WavLM, "misma persona") y se ecualiza suavemente al
>   color de las vof (solo si no ensucia).
> - **Para mejorar de verdad:** grabar a la locutora con `guion_grabacion_locutora.md`
>   (8–10 min) y subirlo a `MyDrive/cossmil_rvc/audio_extra/`.
>
> Lo de abajo es la receta RVC manual original, solo como referencia.

## Piezas de esta carpeta

| Archivo | Qué hace | Dónde corre |
|---|---|---|
| `prep_dataset.sh` | vof → dataset de entrenamiento (WAV mono 44.1k normalizado) | aquí (ffmpeg) |
| `tutorial_lines.md` / `.json` | el guion: id + texto exacto de cada clip | referencia |
| `gen_source_tts.py` | genera la narración FUENTE con edge-tts (gratis) | Colab/PC con internet |

## Idea en una línea

RVC **cambia el timbre** de una grabación pero conserva su ritmo. Así que:

```
vof (voz objetivo)  ──entrenar──►  modelo .pth
narración fuente (edge-tts leyendo el guion)  ──convertir con el .pth──►  clips con la voz vof
```

## Paso a paso

### 1. Dataset (aquí)

```bash
bash tools/rvc/prep_dataset.sh          # crea ./rvc_dataset/*.wav
zip -r rvc_dataset.zip rvc_dataset
```

Sube `rvc_dataset.zip`. Cuanta más voz limpia de la misma persona, mejor
(2–10 min ideal). Las 7 vof dan ~1–2 min: sirve, pero si consigues más
grabaciones de esa voz, agrégalas a `rvc_dataset/` antes de comprimir.

### 2. Entrenar el modelo (Colab)

Abre el Colab oficial de **RVC-Project (Retrieval-based-Voice-Conversion-WebUI)**
o **Mangio-RVC**. En la WebUI, pestaña *Train*:

1. **Experiment name**: `instructora`. **Target sample rate**: `40k`.
2. Sube/――apunta a `rvc_dataset/`. **Process data**.
3. **Feature extraction**: pitch method **rmvpe** (el más limpio).
4. **Train**: `save_every_epoch=25`, `total_epoch=150–250` (poca data → no te
   pases: vigila que no sobreentrene). GPU de Colab basta.
5. Descarga `weights/instructora.pth` **y** `logs/instructora/added_*.index`.

### 3. Narración fuente (Colab)

```bash
pip install edge-tts
python3 tools/rvc/gen_source_tts.py --out source_tts --voice es-BO-SofiaNeural
```

Genera `source_tts/<id>.mp3` para las 19 líneas. Prueba varias voces
(`edge-tts --list-voices | grep es-`) y quédate con la que más se parezca a la
vof — RVC igual la lleva al timbre objetivo, pero partir cerca ayuda.

### 4. Convertir en lote (Colab)

En la WebUI, pestaña *Inference* (o *Batch*):

- Modelo: `instructora.pth`; index: el `added_*.index`; **index ratio** ~0.6.
- **f0 method**: rmvpe. **Transpose**: 0 (súbelo/bájalo en semitonos solo si el
  género de la voz fuente no calza con la vof).
- Input: carpeta `source_tts/`. Output: una carpeta nueva.
- Convierte. Escucha 2–3 y ajusta transpose/index ratio si hace falta.

### 5. Meter los clips en la app

- Exporta cada resultado como **mp3** con el nombre exacto del id:
  `ficha_00.mp3`, `calendario_01.mp3`, … (ver `tutorial_lines.md`).
- Colócalos en **`assets/vof_tutorial/`** del proyecto.
- La reproducción por paso (sincronizada con el coach, con botón de silencio)
  es el enganche que falta en la app — pídeme que lo cablee y lo dejo andando
  en cuanto tengas aunque sea un par de clips para probar.

## Notas

- Mantén el texto de `tutorial_lines.*` en sync con las burbujas del coach; si
  editas una burbuja, regenera ese clip.
- Alternativa sin RVC (si algún día quieres): `flutter_tts` lee las burbujas con
  la voz del sistema (offline, pero no es la voz vof).
