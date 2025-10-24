# RunPod Troubleshooting Guide

## ✅ Primera Arrencada (Volum Buit)

Hauria de funcionar al 100% sense cap problema. La imatge inclou totes les dependencies crítiques:

- ✅ **ComfyUI**: Arrenca correctament al port 8188
- ✅ **JupyterLab**: Arrenca correctament al port 8888 (amb `--allow-root`)
- ✅ **Dependencies**: scipy, einops, transformers, torch pre-instal·lats

## ⚠️ Arrencada amb Volum Existent

Si el teu volum persistent ja té ComfyUI/custom nodes d'abans, pots trobar-te amb:

### Problema 1: ModuleNotFoundError malgrat la imatge nova

**Causa:** El volum té versions antigues de packages que sobrescriuen les de la imatge.

**Solució A - Ràpida (Recomanada):**

```bash
# Al template de RunPod, afegeix variable d'entorn:
COMFYUI_FORCE_REINSTALL=true
```

Això forçarà la reinstal·lació de requirements al primer arrencament. **Després pots treure aquesta variable.**

**Solució B - Netejar cache del volum:**
Connecta per SSH al pod i executa:

```bash
rm -rf /workspace/.state/comfyui-reqs.installed
rm -rf /workspace/.cache/pip/*
```

**Solució C - Reset complet (última opció):**

```bash
# ATENCIÓ: Això esborra tot excepte models
cd /workspace
mv models models_backup
rm -rf ComfyUI custom_nodes .cache .state
mv models_backup models
```

### Problema 2: Custom nodes incompatibles

**Símptoma:** Errors d'import després d'instal·lar custom nodes.

**Solució:**

```bash
# Desinstal·la custom nodes problemàtics temporalment
cd /workspace/ComfyUI/custom_nodes
mv NomDelNodeProblematic /workspace/disabled_nodes/
```

### Problema 3: Workflow es para al mig (sense error a UI)

**Símptoma:** El workflow comença, veus `got prompt`, però després s'atura. El container es reinicia automàticament.

**Causa més comuna:** **Out of Memory (OOM)** - El model està intentant carregar més VRAM del disponible.

**Com detectar-ho:**

```bash
# Comprova logs abans del restart
docker logs <pod-id> | grep -E "(Sampling|OOM|CUDA|killed)"

# Comprova GPU memory
nvidia-smi

# Busca el punt exacte on es para
docker logs <pod-id> | tail -100
```

**Solucions:**

1. **Reduir resolució del workflow:**
   - 704x704 → 512x512 o menys
   - Menys frames (121 → 60)
2. **Afegir variables d'entorn a RunPod:**

   ```bash
   PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512
   CUDA_LAUNCH_BLOCKING=1  # Debug mode (més lent però estable)
   ```

3. **Canviar VRAM mode al workflow:**

   - Busca nodes amb opció `vram` o `memory`
   - Canvia de `auto` a `lowvram` o `cpu`

4. **Reiniciar pod abans de workflow gran:**
   ```bash
   # SSH al pod
   docker restart <container-id>
   # O des de RunPod UI: Stop → Start
   ```

**Exemple de log quan es para:**

```
Sampling 121 frames at 704x704 with 3 steps
  0%|          | 0/3 [00:00<?, ?it/s]
[CONTAINER RESTART]
```

**Verificació:**
Si després de reduir resolució/frames el workflow completa, era OOM.

### Problema 4: Jupyter no arrenca

**Causa:** Port 8888 ja en ús o runtime dir no writable.

**Solució:**
Revisa els logs:

```bash
cat /workspace/logs/jupyter.log
```

## 🔍 Com Verificar que Tot Funciona

### 1. Check dependencies crítiques

Connecta per SSH i executa:

```bash
docker exec -it <pod-name> python -c "import einops, huggingface_hub, transformers; print('OK')"
```

### 2. Check logs d'arrencada

```bash
docker logs <pod-name> | grep -E "(ERROR|ModuleNotFoundError|Total VRAM|Starting server)"
```

### 3. Check que ComfyUI escolta

```bash
curl http://localhost:8188/
```

## 📋 Variables d'Entorn Útils

Al template de RunPod, pots configurar:

```bash
# Core
COMFYUI_BRANCH=v0.3.66              # Versió de ComfyUI
COMFYUI_AUTO_UPDATE=false           # No actualitzar automàticament
COMFYUI_FORCE_REINSTALL=true        # Forçar reinstal·lació (primera vegada)

# Jupyter
JUPYTER_TOKEN=your-secret-token     # Token d'accés (recomanat)

# Ports
COMFYUI_PORT=8188                   # Port de ComfyUI
JUPYTER_PORT=8888                   # Port de JupyterLab
```

## 🚨 Errors Comuns i Solucions

### Error: "JupyterLab no arrenca" o "Port 8888 no respon"

**Símptoma:** RunPod proxy mostra 502 Bad Gateway al port 8888.

**Causa:** Jupyter refusa arrencar com a root sense `--allow-root`.

**Solució:** ✅ **JA RESOLT** a les imatges finals. Jupyter té `--allow-root` activat.

**Verificació:**

```bash
# Comprova que Jupyter escolta
docker logs <pod> | grep "Jupyter Server.*is running"
ss -lnt | grep 8888
```

**Token d'accés:**

```bash
# Cerca el token als logs
docker logs <pod> | grep "token="
# O defineix-ne un personalitzat:
export JUPYTER_TOKEN=my-secret-token
```

### Error: "No space left on device"

```bash
# Neteja imatges Docker antigues
docker system prune -a --volumes -f

# Neteja cache de pip
rm -rf /workspace/.cache/pip/*
```

### Error: "pycairo" compilation failed

```bash
# És normal per comfyui_controlnet_aux
# No bloqueja ComfyUI principal, però si vols arreglar-ho:
apt-get update && apt-get install -y pkg-config libcairo2-dev
pip install pycairo
```

### Error: "CUDA out of memory"

```bash
# Redueix batch size o resolució
# O configura ComfyUI per usar menys VRAM:
# Settings → vram-management-mode → lowvram
```

## 📊 Checklist Pre-Deploy

Abans de pujar la imatge a RunPod:

- [ ] Build local exitós
- [ ] Test local amb GPU funciona
- [ ] No hi ha ModuleNotFoundError al test
- [ ] Imatge pujada al registry (Docker Hub/GHCR)
- [ ] Template RunPod configurat amb:
  - [ ] Imatge correcta
  - [ ] Volum muntat a `/workspace`
  - [ ] Ports 8188 i 8888 exposats
  - [ ] Variables d'entorn configurades
  - [ ] GPU seleccionada (RTX 4090/5090)

## 🎯 Configuració Recomanada RunPod Template

```yaml
Image: yourusername/comfyui:4090
Volume Mount: /workspace
Container Disk: 20GB (mínim)
Exposed Ports: 8188, 8888
Environment Variables:
  COMFYUI_BRANCH: v0.3.66
  COMFYUI_AUTO_UPDATE: false
  JUPYTER_TOKEN: <your-secure-token>
GPU: RTX 4090 (o 5090 amb imatge corresponent)
```

## 📞 Si Res Funciona

1. Comprova logs complets: `docker logs -f <pod-name>`
2. Connecta per SSH i executa manualment:
   ```bash
   cd /workspace/ComfyUI
   python main.py --listen 0.0.0.0 --port 8188
   ```
3. Comprova Python i dependencies:
   ```bash
   python --version
   pip list | grep -E 'torch|einops|transformers'
   ```
