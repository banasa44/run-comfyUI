# ComfyUI Docker Images for RunPod

Hardened Docker images for running ComfyUI on RunPod with optimal GPU support, pre-installed custom nodes, and JupyterLab for development.

## 🚀 Available Images

| Tag                           | GPU      | CUDA | PyTorch | Description                             |
| ----------------------------- | -------- | ---- | ------- | --------------------------------------- |
| `banasa44/comfyui:4090`       | RTX 4090 | 12.1 | cu121   | Multi-stage build, optimized for RunPod |
| `banasa44/comfyui:5090`       | RTX 5090 | 12.8 | cu128   | Single-stage build, default             |
| `banasa44/comfyui:5090-cu126` | RTX 5090 | 12.8 | cu126   | Fallback for compatibility              |

## 📦 What's Included

### Pre-installed Custom Nodes

- **ComfyUI-Manager** - Node package manager
- **comfyui_controlnet_aux** - ControlNet auxiliary preprocessors
- **ComfyUI-Impact-Pack** - Advanced workflow tools
- **ComfyUI-Impact-Subpack** - Additional Impact Pack components

### Services

- **ComfyUI** - Main application on port `8188`
- **JupyterLab** - Development environment on port `8888` (token-free)

### Hardcoded Paths (Not Configurable)

```bash
WORKSPACE=/workspace
COMFY_DIR=/workspace/ComfyUI
HF_HOME=/workspace/.cache/huggingface
TORCH_HOME=/workspace/.cache/torch
PIP_CACHE_DIR=/workspace/.cache/pip
LOG_DIR=/workspace/logs
```

## 🎯 RunPod Template Configuration

### Environment Variables

Only two environment variables are supported:

```bash
COMFYUI_BRANCH=v0.3.66          # ComfyUI version/branch
COMFYUI_AUTO_UPDATE=false       # Auto-update on container start
```

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

## 🛠️ Troubleshooting

### CUDA Driver Mismatch (4090)

If you see driver errors on RTX 4090, the image uses CUDA 12.1 to avoid RunPod driver compatibility issues.

### Disk Space Issues (5090)

The 5090 image uses a single-stage build to prevent "no space left on device" errors during GitHub Actions builds.

### Custom Nodes

Additional nodes can be installed via ComfyUI-Manager UI or by git cloning into `/workspace/ComfyUI/custom_nodes/`.

### JupyterLab Access

JupyterLab is configured with no token/password for convenience. Access at `http://<host>:8888`.

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
