# 🔍 Workflow Hang Diagnosis

## 📊 Analisi dels Logs

**Data:** 2025-10-23 16:27-16:29  
**Container:** RunPod amb RTX 4090 (22GB VRAM)  
**Workflow:** WanVideo I2V (Image to Video)

---

## ❌ Problema Identificat

### Símptomes:

1. ✅ ComfyUI arrenca correctament
2. ✅ Workflow comença (`got prompt`)
3. ✅ Model carrega correctament (WanVideo 14B)
4. ❌ **El sampling es para al 0%**
5. ❌ **Container es reinicia automàticament**
6. ❌ **No hi ha error explícit als logs**

### Punt exacte de fallada:

```
2025-10-23T16:28:02.618719777Z Sampling 121 frames at 704x704 with 3 steps
  0%|          | 0/3 [00:00<?, ?it/s]
2025-10-23T16:28:13.007846741Z
[CONTAINER RESTART - CUDA banner apareix]
```

**Temps transcorregut:** ~10 segons fins restart.

---

## 🎯 Causa Més Probable: **Out of Memory (OOM)**

### Evidència:

1. **Càrrega de memòria massiva:**

   - Model: WanVideo I2V 14B (~28GB amb pesos FP8)
   - Resolució: 704x704
   - Frames: 121
   - VRAM disponible: 22GB RTX 4090

2. **Càlcul aproximat:**

   ```
   Model base: ~14GB
   Activations per frame: ~150MB × 121 = ~18GB
   Overhead PyTorch: ~2-3GB
   TOTAL: ~35GB necessaris
   DISPONIBLE: 22GB
   DÈFICIT: ~13GB ❌
   ```

3. **Pattern típic d'OOM:**
   - Arrenca correctament
   - Model carrega OK
   - Crash durant sampling (quan s'al·loquen activations)
   - Restart silenciós (kernel mata el procés)

### Per què no hi ha error?

**OOM de CUDA mata el procés directament** sense donar temps a Python de capturar l'excepció. RunPod reinicia automàticament el container.

---

## ✅ Solucions

### 1. **Reduir càrrega de memòria** (Recomanat)

#### A. Al Workflow (UI de ComfyUI):

```
Resolució: 704x704 → 512x512 o 480x360
Frames: 121 → 60 o menys
Batch size: 1 (si és aplicable)
```

#### B. Variables d'entorn RunPod:

```bash
PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512
```

Això fa que PyTorch fragmenti menys la memòria, evitant OOM per fragmentació.

### 2. **Enable CPU offloading** (Si el node ho suporta)

Al workflow, busca opcions com:

- `vram_mode: lowvram`
- `cpu_offload: true`
- `model_management: cpu`

### 3. **Split processing** (Avançat)

Si el model ho suporta:

- Genera frames en batches petits
- Usa nodes de chunking/tiling
- Pipeline multi-etapa

### 4. **Debug mode** (Per confirmar OOM)

Afegeix a RunPod:

```bash
CUDA_LAUNCH_BLOCKING=1
```

Això farà que CUDA doni errors més verbosos (però serà més lent).

---

## 🧪 Testing Recomanat

### Pas 1: Confirmar OOM

```bash
# SSH al pod abans de córrer workflow
watch -n 1 nvidia-smi

# Veuràs la VRAM pujar fins 100% just abans del crash
```

### Pas 2: Test amb càrrega reduïda

Prova workflow amb:

- 32 frames @ 512x512 (càrrega ~10GB)
- Si funciona → confirmat OOM
- Si falla → altre problema

### Pas 3: Incremental testing

Augmenta gradualment:

1. 32 frames → OK?
2. 60 frames → OK?
3. 121 frames → Crash (límit trobat)

---

## 📝 Millores Implementades

### Al `comfy-entrypoint.sh`:

```bash
# Afegit trap per errors
trap 'echo "[ERROR] ComfyUI terminated (exit $?)"' ERR

# Afegit GPU memory logging
nvidia-smi --query-gpu=memory.used,memory.free,memory.total

# Afegit CUDA config
export PYTORCH_CUDA_ALLOC_CONF="${PYTORCH_CUDA_ALLOC_CONF:-max_split_size_mb:512}"
```

Ara els logs mostraran:

- GPU memory abans d'arrencar
- Exit code si ComfyUI crasheja
- Millor fragmentació de memòria

---

## 🔄 Alternatives

### Opció A: GPU més gran

RunPod amb RTX A6000 (48GB) o A100 (80GB) permetria córrer el workflow complet.

### Opció B: Model més petit

Usa variants del model:

- WanVideo 7B (en comptes de 14B)
- FP16 → FP8 o INT8 quantitzat
- Distilled/pruned versions

### Opció C: Resolution scaling

Genera a baixa resolució, després upscale amb un model separat:

- Generate: 480x360 @ 121 frames
- Upscale: VideoUpscale node per frame

---

## 📊 Memory Budget Estimat

| Config         | Model | Activations | Total | RTX 4090 | Status   |
| -------------- | ----- | ----------- | ----- | -------- | -------- |
| 704x704 × 121f | 14GB  | 18GB        | 32GB  | 22GB     | ❌ OOM   |
| 512x512 × 121f | 14GB  | 10GB        | 24GB  | 22GB     | ⚠️ Tight |
| 512x512 × 60f  | 14GB  | 5GB         | 19GB  | 22GB     | ✅ OK    |
| 480x360 × 121f | 14GB  | 6GB         | 20GB  | 22GB     | ✅ OK    |

---

## 🚀 Action Items

1. ✅ **Rebuild imatges amb millor logging** (fet)
2. ⏳ **Test workflow amb 60 frames @ 512x512**
3. ⏳ **Afegir variables PYTORCH_CUDA_ALLOC_CONF a template**
4. ⏳ **Documentar memory limits per model**
5. ⏳ **Considerar auto-scaling de resolució segons VRAM**

---

## 📖 Referències

- [PyTorch CUDA Memory Management](https://pytorch.org/docs/stable/notes/cuda.html#memory-management)
- [CUDA Out of Memory Best Practices](https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#device-memory)
- [ComfyUI Memory Optimization](https://github.com/comfyanonymous/ComfyUI/wiki/Optimizations)

---

**Conclusió:** El workflow es para per **Out of Memory**. Redueix resolució o frames per a RTX 4090. Amb les millores de logging, ara veuràs l'estat de memòria abans del crash.
