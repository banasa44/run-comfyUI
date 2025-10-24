#!/usr/bin/env bash
set -euo pipefail

# ========================================================================
# ComfyUI entrypoint - inspired by ComfyUI_with_Flux
# ========================================================================

WORKSPACE=/workspace
COMFY_DIR=$WORKSPACE/ComfyUI
LOG_DIR=$WORKSPACE/logs

# Export cache directories
export HF_HOME=$WORKSPACE/.cache/huggingface
export TORCH_HOME=$WORKSPACE/.cache/torch
export PIP_CACHE_DIR=$WORKSPACE/.cache/pip
export GIT_TERMINAL_PROMPT=0

# Behavior environment variables
COMFYUI_AUTO_UPDATE="${COMFYUI_AUTO_UPDATE:-false}"
JUPYTER_TOKEN="${JUPYTER_TOKEN:-}"
HF_TOKEN="${HF_TOKEN:-}"

# ========================================================================
# Setup logging
# ========================================================================
mkdir -p "$LOG_DIR"
exec 3>>"$LOG_DIR/entrypoint.log"
echo "[$(date -Is)] ============================================" >&3
echo "[$(date -Is)] ENTRYPOINT START" >&3
echo "[$(date -Is)] COMFYUI_AUTO_UPDATE=$COMFYUI_AUTO_UPDATE" >&3
echo "[$(date -Is)] HF_TOKEN set: $([ -n "$HF_TOKEN" ] && echo 'yes' || echo 'no')" >&3
git lfs install || true
echo "[$(date -Is)] ============================================" >&3

# ========================================================================
# HuggingFace authentication (if token provided)
# ========================================================================
if [ -n "$HF_TOKEN" ] && [ "$HF_TOKEN" != "enter_your_huggingface_token_here" ]; then
  echo "[$(date -Is)] HF_TOKEN provided, logging in to HuggingFace..." >&3
  python -c "from huggingface_hub import login; login(token='${HF_TOKEN}')" 2>&1 | tee -a "$LOG_DIR/entrypoint.log" || {
    echo "[$(date -Is)] WARNING: HuggingFace login failed" >&3
  }
fi

# ========================================================================
# Handle workspace persistence with robust approach (like the 3rd party)
# ========================================================================
mkdir -p "$WORKSPACE"

if [ ! -d "$COMFY_DIR" ]; then
  # First run: move image ComfyUI to workspace
  if [ -d "/ComfyUI" ]; then
    echo "[$(date -Is)] First run: moving /ComfyUI to /workspace/ComfyUI" >&3
    mv /ComfyUI "$COMFY_DIR"
  else
    echo "[$(date -Is)] ERROR: /ComfyUI not found in image!" >&3
    exit 1
  fi
else
  # Subsequent runs: ALWAYS recreate symlink (robust approach)
  echo "[$(date -Is)] ComfyUI already exists in workspace" >&3
  rm -rf /ComfyUI 2>/dev/null || true
  ln -s "$COMFY_DIR" /ComfyUI
  echo "[$(date -Is)] Recreated symlink /ComfyUI -> $COMFY_DIR" >&3
fi

# Auto-update if enabled
if [ "$COMFYUI_AUTO_UPDATE" = "true" ] && [ -d "$COMFY_DIR/.git" ]; then
  echo "[$(date -Is)] Auto-update enabled, pulling latest changes" >&3
  git -C "$COMFY_DIR" pull --ff-only || true
fi

# Ensure ComfyUI directories
# ========================================================================
mkdir -p "$COMFY_DIR/models" \
         "$COMFY_DIR/input" \
         "$COMFY_DIR/output" \
         "$COMFY_DIR/custom_nodes"

# ========================================================================
# Custom nodes installation (minimal set - more can be added via Manager)
# ========================================================================
# Most nodes are already in the image from builder stage
# Only install additional ones if needed at runtime

# ========================================================================
# Support for customizable startup script (user can override behavior)
# ========================================================================
if [ ! -f "$WORKSPACE/start_user.sh" ]; then
  echo "[$(date -Is)] Creating default start_user.sh" >&3
  cat > "$WORKSPACE/start_user.sh" << 'EOF'
#!/bin/bash
# User-customizable startup script
# This file persists across container restarts
# Add your custom initialization here

echo "Running default user startup script..."

# Example: Download additional models
# wget -O /workspace/ComfyUI/models/checkpoints/my_model.safetensors "https://..."

# Example: Install additional custom nodes
# cd /workspace/ComfyUI/custom_nodes
# git clone https://github.com/user/custom-node
# pip install -r custom-node/requirements.txt

echo "User startup script completed"
EOF
  chmod +x "$WORKSPACE/start_user.sh"
fi

# ========================================================================
# Start JupyterLab
# ========================================================================
echo "[$(date -Is)] Starting JupyterLab on port 8888" >&3

# Configure JupyterLab to use bash with better terminal experience
export SHELL=/bin/bash

JUPYTER_ARGS=(
  lab
  --ip=0.0.0.0
  --port=8888
  --no-browser
  --allow-root
  --NotebookApp.allow_origin='*'
  --ServerApp.root_dir="$WORKSPACE"
  --ServerApp.terminado_settings="shell_command=['/bin/bash']"
)

# Token configuration: use env var if provided, otherwise disable token
if [ -n "${JUPYTER_TOKEN:-}" ]; then
  JUPYTER_ARGS+=( --NotebookApp.token="$JUPYTER_TOKEN" )
  echo "[$(date -Is)] JupyterLab will use custom token" >&3
else
  # Disable token authentication for easier access
  JUPYTER_ARGS+=( --NotebookApp.token='' --NotebookApp.password='' )
  echo "[$(date -Is)] JupyterLab started WITHOUT authentication (no token)" >&3
fi

jupyter "${JUPYTER_ARGS[@]}" >> "$LOG_DIR/jupyter.log" 2>&1 &
echo "[$(date -Is)] JupyterLab logs: $LOG_DIR/jupyter.log" >&3

# ========================================================================
# Execute user customization script
# ========================================================================
if [ -f "$WORKSPACE/start_user.sh" ]; then
  echo "[$(date -Is)] Executing user startup script..." >&3
  bash "$WORKSPACE/start_user.sh" 2>&1 | tee -a "$LOG_DIR/entrypoint.log" || {
    echo "[$(date -Is)] WARNING: User script failed, continuing anyway" >&3
  }
fi

# ========================================================================
# Launch ComfyUI
# ========================================================================
cd "$COMFY_DIR"
echo "[$(date -Is)] Starting ComfyUI on port 8188" >&3
echo "[$(date -Is)] Working directory: $(pwd)" >&3

# Log GPU info if available
if command -v nvidia-smi &> /dev/null; then
  echo "[$(date -Is)] GPU Info:" >&3
  nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>&1 | tee -a "$LOG_DIR/entrypoint.log" || true
  echo "[$(date -Is)] CUDA Version:" >&3
  nvcc --version 2>&1 | grep "release" | tee -a "$LOG_DIR/entrypoint.log" || echo "nvcc not available (runtime image)" | tee -a "$LOG_DIR/entrypoint.log"
else
  echo "[$(date -Is)] WARNING: nvidia-smi not found, GPU may not be available" >&3
fi

# Log Python environment
echo "[$(date -Is)] Python: $(python --version 2>&1)" >&3
echo "[$(date -Is)] PyTorch: $(python -c 'import torch; print(torch.__version__)' 2>&1)" >&3
echo "[$(date -Is)] CUDA available: $(python -c 'import torch; print(torch.cuda.is_available())' 2>&1)" >&3

exec python main.py \
  --listen 0.0.0.0 \
  --port 8188 \
  --enable-cors-header
