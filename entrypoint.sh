#!/usr/bin/env bash
set -euo pipefail

export RP_WORKSPACE="${RP_WORKSPACE:-/workspace}"
export HF_HOME="${HF_HOME:-$RP_WORKSPACE/.cache/huggingface}"
export TORCH_HOME="${TORCH_HOME:-$RP_WORKSPACE/.cache/torch}"
export PIP_CACHE_DIR="${PIP_CACHE_DIR:-$RP_WORKSPACE/.cache/pip}"
export COMFYUI_BRANCH="${COMFYUI_BRANCH:-v0.3.66}"
export COMFYUI_PORT="${COMFYUI_PORT:-8188}"
export COMFYUI_AUTO_UPDATE="${COMFYUI_AUTO_UPDATE:-false}"

COMFY_DIR="$RP_WORKSPACE/ComfyUI"
LOG_DIR="$RP_WORKSPACE/logs"; mkdir -p "$LOG_DIR"
exec 3>>"$LOG_DIR/entrypoint.log"

echo "[$(date -Is)] ENTRYPOINT start (branch=$COMFYUI_BRANCH auto_update=$COMFYUI_AUTO_UPDATE)" >&3

# 1) Clone/update ComfyUI
if [ ! -d "$COMFY_DIR/.git" ]; then
  echo "[$(date -Is)] Cloning ComfyUI ($COMFYUI_BRANCH)" >&3
  git clone --depth=1 --branch "$COMFYUI_BRANCH" https://github.com/comfyanonymous/ComfyUI.git "$COMFY_DIR"
else
  if [ "$COMFYUI_AUTO_UPDATE" = "true" ]; then
    echo "[$(date -Is)] Updating ComfyUI" >&3
    git -C "$COMFY_DIR" fetch --depth=1 origin "$COMFYUI_BRANCH" || true
    git -C "$COMFY_DIR" checkout "$COMFYUI_BRANCH" || true
    git -C "$COMFY_DIR" pull --ff-only || true
  fi
fi

# 2) Ensure internal dirs
mkdir -p "$COMFY_DIR/models" "$COMFY_DIR/input" "$COMFY_DIR/output" "$COMFY_DIR/custom_nodes" "$RP_WORKSPACE/.state"

# 3) ComfyUI-Manager
MANAGER_DIR="$COMFY_DIR/custom_nodes/ComfyUI-Manager"
if [ ! -d "$MANAGER_DIR/.git" ]; then
  echo "[$(date -Is)] Installing ComfyUI-Manager" >&3
  git clone --depth=1 https://github.com/ltdrdata/ComfyUI-Manager "$MANAGER_DIR"
  if [ -f "$MANAGER_DIR/requirements.txt" ] && [ ! -f "$MANAGER_DIR/.installed" ]; then
    python -m pip install --no-cache-dir -r "$MANAGER_DIR/requirements.txt" && touch "$MANAGER_DIR/.installed"
  fi
else
  if [ "$COMFYUI_AUTO_UPDATE" = "true" ]; then
    echo "[$(date -Is)] Updating ComfyUI-Manager" >&3
    git -C "$MANAGER_DIR" pull --ff-only || true
  fi
fi

# 4) Launch ComfyUI
cd "$COMFY_DIR"
echo "[$(date -Is)] Starting ComfyUI on 0.0.0.0:$COMFYUI_PORT" >&3
exec python main.py --listen 0.0.0.0 --port "$COMFYUI_PORT" --enable-cors-header \
  --output-directory "$COMFY_DIR/output" --input-directory "$COMFY_DIR/input"
