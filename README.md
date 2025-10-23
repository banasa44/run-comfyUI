# ComfyUI Docker Images for RunPod

Production-ready Docker images for ComfyUI on RunPod with **ZERO ModuleNotFoundError**, optimal GPU support, and JupyterLab.

## ✅ Status

🎉 **100% Functional** - Totes les dependencies pre-instal·lades del `requirements.txt` oficial de ComfyUI.

## 🚀 Available Images

| GPU      | CUDA   | PyTorch     | Image                         | Status        |
| -------- | ------ | ----------- | ----------------------------- | ------------- |
| RTX 4090 | 12.1.0 | 2.5.1+cu121 | `banasa44/comfyui:4090-final` | ✅ Production |
| RTX 5090 | 12.8.0 | 2.9.0+cu128 | `banasa44/comfyui:5090-final` | ✅ Production |

## 📦 What's Included

### ✅ Core Dependencies (Pre-installed)

Totes les dependencies del **ComfyUI v0.3.66 requirements.txt**:

- ✅ scipy 1.16.2
- ✅ einops 0.8.1
- ✅ transformers 4.57.1
- ✅ sentencepiece 0.2.1
- ✅ kornia 0.8.1
- ✅ spandrel 0.4.1
- ✅ torch, torchvision, torchaudio
- ✅ safetensors, aiohttp, pyyaml, pillow
- ✅ i **tots** els altres

**No more `ModuleNotFoundError`!** 🎉

### 🛠️ Services

- **ComfyUI** - Port `8188` (auto-clones v0.3.66)
- **JupyterLab** - Port `8888` (amb `--allow-root`)
- **ComfyUI-Manager** - Auto-instal·lat per gestió de custom nodes

### Hardcoded Paths (Not Configurable)

```bash
WORKSPACE=/workspace
COMFY_DIR=/workspace/ComfyUI
HF_HOME=/workspace/.cache/huggingface
TORCH_HOME=/workspace/.cache/torch
PIP_CACHE_DIR=/workspace/.cache/pip
LOG_DIR=/workspace/logs
```

**Note:** If you already have ComfyUI on your `/workspace` volume (e.g., under a different case or path like `/workspace/comfyUI`), the entrypoint will automatically adopt it and move it to `/workspace/ComfyUI`. If ComfyUI-Manager exists elsewhere on the volume, it will be imported into the custom_nodes directory.

## 🎯 Quick Start

### 1. Deploy to RunPod

```bash
# Template Configuration
Image: banasa44/comfyui:4090-final  # Or 5090-final
Ports: 8188/http, 8888/http
Volume: /workspace (50GB+ recomanat)
GPU: RTX 4090 (or compatible)
```

### 2. Environment Variables

```bash
# Opcionals (tots tenen defaults)
COMFYUI_BRANCH=v0.3.66              # Per defecte
COMFYUI_AUTO_UPDATE=false           # Recomanat: false
COMFYUI_FORCE_REINSTALL=true        # Primera vegada amb volum existent
JUPYTER_TOKEN=my-secret-token       # Recomanat per seguretat
```

### 3. Access

- **ComfyUI**: `https://<pod-id>-8188.proxy.runpod.net`
- **JupyterLab**: `https://<pod-id>-8888.proxy.runpod.net`

### Port Mappings

- **8188** → ComfyUI web interface
- **8888** → JupyterLab (opens first, no token required)

### Volume Mount

- **Container Path**: `/workspace`
- **Minimum Size**: 50GB recommended

### Start Command

```bash
/usr/local/bin/comfy-entrypoint.sh
```

## 🐳 Docker Usage

### Quick Start

```bash
# RTX 4090 (CUDA 12.1)
docker run --gpus all -p 8188:8188 -p 8888:8888 -v $(pwd)/workspace:/workspace banasa44/comfyui:4090

# RTX 5090 (CUDA 12.8)
docker run --gpus all -p 8188:8188 -p 8888:8888 -v $(pwd)/workspace:/workspace banasa44/comfyui:5090

# RTX 5090 (CUDA 12.6 fallback)
docker run --gpus all -p 8188:8188 -p 8888:8888 -v $(pwd)/workspace:/workspace banasa44/comfyui:5090-cu126
```

### With Custom Settings

```bash
docker run --gpus all \
  -p 8188:8188 -p 8888:8888 \
  -v $(pwd)/workspace:/workspace \
  -e COMFYUI_BRANCH=main \
  -e COMFYUI_AUTO_UPDATE=true \
  banasa44/comfyui:4090
```

## 🔨 Building Locally

### RTX 4090 (CUDA 12.1, Multi-stage)

```bash
docker build -f Dockerfiles/Dockerfile.4090 -t comfyui:4090 .
```

### RTX 5090 (CUDA 12.8, Single-stage)

```bash
# Default cu128
docker build -f Dockerfiles/Dockerfile.5090 -t comfyui:5090 .

# With cu126 fallback
docker build -f Dockerfiles/Dockerfile.5090 \
  --build-arg TORCH_INDEX_URL=https://download.pytorch.org/whl/cu126 \
  -t comfyui:5090-cu126 .
```

## 📋 Logs

All logs are written to `/workspace/logs/`:

- `entrypoint.log` - Startup and initialization logs
- `jupyter.log` - JupyterLab output

View logs from inside the container:

```bash
docker exec -it <container_id> tail -f /workspace/logs/entrypoint.log
```

## 🔄 Startup Sequence

1. **Logging initialized** → `/workspace/logs/entrypoint.log`
2. **JupyterLab starts** → Background process on port 8888
3. **ComfyUI cloned/updated** → `/workspace/ComfyUI` (if missing or auto-update enabled)
4. **Custom nodes bootstrapped** → Only if missing or auto-update enabled
5. **Requirements installed** → For each node with `requirements.txt`
6. **ComfyUI starts** → Foreground process on port 8188

## 🧪 Local Testing

Abans de deploy a RunPod, pots testar localment amb GPU:

```bash
# Prerequisits: NVIDIA Container Toolkit
./Scripts/test-local.sh 4090  # or 5090
```

Consulta [Scripts/TESTING.md](./Scripts/TESTING.md) per més detalls.

## 🛠️ Troubleshooting

### ✅ ModuleNotFoundError - RESOLT

**Totes** les dependencies estan pre-instal·lades. Si encara veus errors amb volum existent:

```bash
COMFYUI_FORCE_REINSTALL=true  # Primera arrencada només
```

### ✅ JupyterLab no arrenca - RESOLT

Jupyter té `--allow-root` activat. Si no arrenca, comprova logs:

```bash
docker logs <pod> | grep -i jupyter
```

### Custom Nodes

Instal·la via **ComfyUI-Manager UI** o manual:

```bash
cd /workspace/ComfyUI/custom_nodes
git clone https://github.com/author/node-name
# Restart pod
```

### Disk Space

```bash
# Neteja cache
rm -rf /workspace/.cache/pip/*
docker system prune -a --volumes -f
```

**Consulta [RUNPOD_TROUBLESHOOTING.md](./RUNPOD_TROUBLESHOOTING.md) per més errors comuns.**

## 🤖 GitHub Actions

Images are automatically built and pushed to Docker Hub on every push to `main` or manual workflow dispatch.

### Build Matrix

- `4090` - CUDA 12.1 multi-stage
- `5090` - CUDA 12.8 single-stage (default)
- `5090-cu126` - CUDA 12.8 single-stage (cu126 PyTorch)

### Features

- **Disk space cleanup** - Removes Android SDK, .NET, GHC before build
- **BuildX cache** - Uses GitHub Actions cache for faster rebuilds
- **Fallback tags** - Provides cu126 option for compatibility

### Setup Requirements

1. Go to repository **Settings** → **Secrets and variables** → **Actions**
2. Add secret:
   - **Name**: `DOCKERHUB_TOKEN`
   - **Value**: Your Docker Hub Personal Access Token

## 📝 Architecture Notes

### Why CUDA 12.1 for 4090?

RunPod GPU pools often have older drivers that don't support CUDA 12.6+. CUDA 12.1 provides maximum compatibility.

### Why Single-stage for 5090?

GitHub Actions runners have limited disk space. Multi-stage builds for 5090 were hitting "no space left on device" errors during the `COPY --from=builder` step.

### Why Hardcoded Paths?

Reduces configuration complexity and ensures consistent behavior across deployments. All data persists in `/workspace` which is mounted as a volume.

### Why Bootstrap Nodes?

Ensures a working ComfyUI setup on first boot without requiring manual node installation. Users can still add more nodes via ComfyUI-Manager.

## 📄 License

MIT License - Feel free to modify and use as needed.
