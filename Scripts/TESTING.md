# Testing Local abans de RunPod

## Pre-requisits

```bash
# Instal·lar NVIDIA Container Toolkit (si no el tens)
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker

# Verifica que funciona
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

## Test Imatge 4090

```bash
cd Scripts
./test-local.sh 4090
```

Això farà:

1. Build de `Dockerfiles/Dockerfile.4090`
2. Run en ports 18188 (ComfyUI) i 18888 (Jupyter)
3. Health check automàtic
4. Mostrarà logs si falla

Si tot va bé, veuràs:

```
✓ SUCCESS: ComfyUI is running!
ComfyUI UI: http://localhost:18188/
JupyterLab: http://localhost:18888/
```

## Test Imatge 5090

```bash
./test-local.sh 5090
```

## Debugging

Si falla, el script mostrarà els logs complets. També pots:

```bash
# Entrar al container mentre corre
docker exec -it comfyui-test-XXXXX /bin/bash

# Dins del container:
python -c "import einops; import huggingface_hub; print('OK')"
pip list | grep -E 'torch|einops|huggingface'
```

## Variables d'Entorn de Test

```bash
# Canviar workspace de test
export TEST_WORKSPACE=/path/to/custom/workspace
./test-local.sh 4090

# Testejar auto-update
docker run --rm -it --gpus all \
  -v ~/test-workspace:/workspace \
  -e COMFYUI_AUTO_UPDATE=true \
  comfyui:test-4090
```

## Neteja després del test

```bash
# El script auto-neteja al sortir (Ctrl+C)
# Per netejar manualment:
docker stop comfyui-test-*
docker rmi comfyui:test-4090 comfyui:test-5090

# Netejar workspace de test
rm -rf ~/test-comfyui-workspace
```

## Verificar que la imatge és RunPod-ready

Checklist:

- ✅ ComfyUI arrenca i escolta a `0.0.0.0:8188`
- ✅ JupyterLab arrenca a `0.0.0.0:8888`
- ✅ No errors de `ModuleNotFoundError`
- ✅ Logs mostren correctament `[YYYY-MM-DD] ...`
- ✅ Pot accedir a http://localhost:18188/ des del navegador

## Simular Volum Persistent de RunPod

```bash
# Primera run (volum buit)
./test-local.sh 4090

# Segona run (volum persistent amb dades)
./test-local.sh 4090  # Hauria de detectar ComfyUI existent i no re-clonar
```
