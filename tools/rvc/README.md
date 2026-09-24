# Voz de la instructora del tutorial (RVC v2)

Objetivo: que la instructora **diga en voz alta** cada paso del tutorial, con la
**misma voz** que las locuciones `vof` — sin pagar suscripciones, usando
**RVC v2** (Retrieval-based Voice Conversion, open-source).

> ⚠️ RVC **no corre en este repo/máquina** (necesita PyTorch + GPU + descargar
> modelos). Se entrena/convierte en **Google Colab** (gratis) o en un PC con
> GPU. Aquí queda todo lo PREVIO ya preparado: dataset, guion y narración fuente.

> **Atajo (sep 2026): usar `COSSMIL_estudio_voz.ipynb`.** Estudio de voz en Colab:
> entrena una vez con las vof (embebidas) y luego genera **cualquier texto** con la
> voz de la locutora (celda 6), desde archivos .txt/.json/.csv (celda 7), el guion
> completo de la app (celda 8) o compara voces base (celda 9). El modelo queda en
> `MyDrive/cossmil_rvc/modelo/` y no se reentrena salvo que agregues audio en
> `MyDrive/cossmil_rvc/audio_extra/`. Lo de abajo es la receta manual de referencia.
>
> - Motor: `estudio_voz_lib.py` (pruebas: `python3 tools/rvc/test_estudio_voz_lib.py`).
> - Notebook: se genera con `python3 tools/rvc/build_colab_notebook.py` (editar el
>   script o el motor, nunca el `.ipynb`).
> - Applio está fijado al commit con el que se validaron los flags (CLI Click con
>   guiones: `batch-infer`, `--model-name`…); la celda 3 permite probar `main`.

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
