# 🚀 Deployment Guide - ComfyUI RunPod

## ✅ Imatges Disponibles

Les imatges estan **100% funcionals** amb totes les dependencies:

| GPU      | CUDA   | PyTorch     | Tag                  | Status   |
| -------- | ------ | ----------- | -------------------- | -------- |
| RTX 4090 | 12.1.0 | 2.5.1+cu121 | `comfyui:4090-final` | ✅ Ready |
| RTX 5090 | 12.8.0 | 2.9.0+cu128 | `comfyui:5090-final` | ✅ Ready |

## 📦 Dependencies Incloses

✅ **ComfyUI v0.3.66** amb tots els requirements oficials:

- scipy 1.16.2
- einops 0.8.1
- transformers 4.57.1
- sentencepiece 0.2.1
- kornia 0.8.1
- spandrel 0.4.1
- i **tots** els altres del `requirements.txt` oficial

✅ **JupyterLab** funcionant amb `--allow-root`

✅ **Sistema**:

- Git LFS
- uv (per ComfyUI Manager)
- ffmpeg, opencv
- CUDA runtime (no drivers, RunPod els proveeix)

## 🎯 Deployment a RunPod

### 1. Push imatges al registry

```bash
# Docker Hub
docker tag comfyui:4090-final yourusername/comfyui:4090-v0.3.66
docker tag comfyui:5090-final yourusername/comfyui:5090-v0.3.66
docker push yourusername/comfyui:4090-v0.3.66
docker push yourusername/comfyui:5090-v0.3.66

# O GitHub Container Registry
docker tag comfyui:4090-final ghcr.io/yourusername/comfyui:4090-v0.3.66
docker tag comfyui:5090-final ghcr.io/yourusername/comfyui:5090-v0.3.66
docker push ghcr.io/yourusername/comfyui:4090-v0.3.66
docker push ghcr.io/yourusername/comfyui:5090-v0.3.66
```

### 2. Crear Template a RunPod

**Container Configuration:**

- **Image**: `yourusername/comfyui:4090-v0.3.66` (o 5090)
- **Docker command**: _(deixar buit, usa CMD del Dockerfile)_
- **Expose Ports**: `8188/http`, `8888/http`
- **Volume Mount**: `/workspace` (recomanat: 50GB+)

**Environment Variables:**

```bash
# Obligatòries (cap)

# Opcionals
COMFYUI_BRANCH=v0.3.66              # Per defecte
COMFYUI_AUTO_UPDATE=false           # Recomanat: false
JUPYTER_TOKEN=my-secret-123         # Recomanat per seguretat
```

**GPU Selection:**

- Per imatge 4090: RTX 4090, RTX 4080, RTX 3090
- Per imatge 5090: RTX 5090 (quan disponible)

### 3. Primera arrencada (volum buit)

Tot hauria de funcionar automàticament:

1. **Entrypoint** clona ComfyUI v0.3.66
2. **Jupyter** arrenca al port 8888
3. **ComfyUI** arrenca al port 8188
4. **Custom nodes** es poden instal·lar via ComfyUI Manager

**Temps estimat:** ~2-3 minuts

**Verificació:**

- ComfyUI: `https://<pod-id>-8188.proxy.runpod.net`
- Jupyter: `https://<pod-id>-8888.proxy.runpod.net`

### 4. Arrencada amb volum existent

Si el volum té una instal·lació antiga de ComfyUI:

**Opció A - Force reinstall (recomanat primera vegada):**

```bash
COMFYUI_FORCE_REINSTALL=true
```

**Opció B - Deixar estat existent:**
L'entrypoint **adopta** l'estat del volum i només reinstal·la si detecta discrepàncies.

## 🔧 Customització

### Afegir custom nodes

```bash
# Via SSH al pod
cd /workspace/ComfyUI/custom_nodes
git clone https://github.com/author/node-name
# Restart pod
```

O usa **ComfyUI Manager** des de la UI.

### Canviar versió de ComfyUI

```bash
COMFYUI_BRANCH=main  # O qualsevol branch/tag
```

### Disable JupyterLab

Si no el necessites, pots ignorar el port 8888. Jupyter arrenca igualment però no consumeix recursos significatius.

## 📊 Recursos

**Mínim recomanat:**

- GPU: 16GB VRAM
- RAM: 32GB
- Disk: 50GB (models ocupen molt)

**Òptim:**

- GPU: 24GB VRAM (RTX 4090/5090)
- RAM: 64GB
- Disk: 100GB+ (per múltiples models)

## 🐛 Troubleshooting

Consulta [RUNPOD_TROUBLESHOOTING.md](./RUNPOD_TROUBLESHOOTING.md) per errors comuns.

**Quick checks:**

```bash
# Logs del pod
docker logs <pod-id> | grep -E "(ERROR|Starting server|Total VRAM)"

# Port check
ss -lnt | grep -E "(8188|8888)"

# Dependency check
python -c "import scipy, einops, torch; print('✅ OK')"
```

## 🎉 Features

✅ **GPU-ready**: CUDA runtime correcte per cada GPU  
✅ **Persistent state**: Adopta estat del volum sense forçar reinstal·lacions  
✅ **Custom nodes**: Compatible amb ComfyUI Manager  
✅ **JupyterLab**: Per development i debugging  
✅ **Auto-recovery**: Healthcheck i retry logic  
✅ **Clean caching**: HuggingFace, pip i torch cache al volum

## 📝 Notes

1. **No ModuleNotFoundError**: Totes les dependencies del `requirements.txt` oficial estan pre-instal·lades
2. **Jupyter root fix**: `--allow-root` ja activat
3. **Multi-stage builds**: Imatges més lleugeres (runtime sense build tools)
4. **Git LFS**: Inicialitzat automàticament per models grans
5. **ComfyUI Manager**: Compatible amb `uv` per gestió de packages

## 🔄 Updates

Per actualitzar a noves versions:

```bash
# Build nova imatge
docker build -t comfyui:4090-v0.3.67 \
  --build-arg COMFYUI_COMMIT=<new-commit> \
  -f Dockerfiles/Dockerfile.4090 .

# Test localment
./Scripts/test-local.sh 4090

# Push
docker push yourusername/comfyui:4090-v0.3.67
```

---

**Fet amb ❤️ per deployment robust a RunPod**
