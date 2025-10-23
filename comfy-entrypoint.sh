#!/usr/bin/env bash
set -euo pipefail

# ========================================================================
# Hardcoded paths and ports (no env overrides)
# ========================================================================
WORKSPACE=/workspace
COMFY_DIR=$WORKSPACE/ComfyUI
HF_HOME=$WORKSPACE/.cache/huggingface
TORCH_HOME=$WORKSPACE/.cache/torch
PIP_CACHE_DIR=$WORKSPACE/.cache/pip
LOG_DIR=$WORKSPACE/logs

COMFYUI_PORT=8188
JUPYTER_PORT=8888

# Export cache directories
export HF_HOME
export TORCH_HOME
export PIP_CACHE_DIR

# Prevent interactive git prompts
export GIT_TERMINAL_PROMPT=0

# ========================================================================
# Behavior environment variables (with defaults)
# ========================================================================
COMFYUI_BRANCH="${COMFYUI_BRANCH:-v0.3.66}"
COMFYUI_AUTO_UPDATE="${COMFYUI_AUTO_UPDATE:-false}"
JUPYTER_TOKEN="${JUPYTER_TOKEN:-}"

# ========================================================================
# Setup logging
# ========================================================================
mkdir -p "$LOG_DIR"
exec 3>>"$LOG_DIR/entrypoint.log"
echo "[$(date -Is)] ============================================" >&3
echo "[$(date -Is)] ENTRYPOINT START" >&3
echo "[$(date -Is)] COMFYUI_BRANCH=$COMFYUI_BRANCH" >&3
echo "[$(date -Is)] COMFYUI_AUTO_UPDATE=$COMFYUI_AUTO_UPDATE" >&3
echo "[$(date -Is)] ============================================" >&3

# ========================================================================
# Helper function for resilient git cloning
# ========================================================================
try_clone() {
  local url="$1" dir="$2" branch="${3:-}"
  local clone_args="--depth=1"
  [ -n "$branch" ] && clone_args="$clone_args --branch $branch"
  
  for i in {1..3}; do
    git clone $clone_args "$url" "$dir" && return 0
    echo "[$(date -Is)] Clone attempt $i failed, retrying..." >&3
    sleep 2
  done
  echo "[$(date -Is)] ERROR: failed to clone $url after 3 attempts" >&3
  return 1
}

# ========================================================================
# Start JupyterLab first (background) with optional token
# ========================================================================
echo "[$(date -Is)] Starting JupyterLab on 0.0.0.0:$JUPYTER_PORT" >&3
if [ -n "$JUPYTER_TOKEN" ]; then
  echo "[$(date -Is)] Using custom Jupyter token" >&3
  nohup jupyter lab --ip=0.0.0.0 --port=$JUPYTER_PORT --no-browser \
    --ServerApp.root_dir=/workspace \
    --ServerApp.token="$JUPYTER_TOKEN" \
    --ServerApp.allow_origin='*' \
    --ServerApp.allow_remote_access=true \
    >> "$LOG_DIR/jupyter.log" 2>&1 &
else
  echo "[$(date -Is)] Using auto-generated Jupyter token (check jupyter.log)" >&3
  nohup jupyter lab --ip=0.0.0.0 --port=$JUPYTER_PORT --no-browser \
    --ServerApp.root_dir=/workspace \
    --ServerApp.allow_origin='*' \
    --ServerApp.allow_remote_access=true \
    >> "$LOG_DIR/jupyter.log" 2>&1 &
fi

# ========================================================================
# Ensure ComfyUI repository
# ========================================================================
if [ ! -d "$COMFY_DIR/.git" ]; then
  echo "[$(date -Is)] Cloning ComfyUI (branch: $COMFYUI_BRANCH)" >&3
  try_clone "https://github.com/comfyanonymous/ComfyUI.git" "$COMFY_DIR" "$COMFYUI_BRANCH" || exit 1
else
  echo "[$(date -Is)] ComfyUI already exists at $COMFY_DIR" >&3
  if [ "$COMFYUI_AUTO_UPDATE" = "true" ]; then
    echo "[$(date -Is)] Auto-update enabled, pulling latest changes" >&3
    git -C "$COMFY_DIR" fetch --depth=1 origin "$COMFYUI_BRANCH" || true
    git -C "$COMFY_DIR" checkout "$COMFYUI_BRANCH" || true
    git -C "$COMFY_DIR" pull --ff-only || true
  fi
fi

# ========================================================================
# Install ComfyUI requirements if changed
# ========================================================================
REQ_FILE="$COMFY_DIR/requirements.txt"
REQ_MARK="$WORKSPACE/.state/comfyui-reqs.installed"

install_requirements_if_needed() {
  mkdir -p "$WORKSPACE/.state"
  local new_sum old_sum
  new_sum="$(sha256sum "$REQ_FILE" | awk '{print $1}')"
  if [ -f "$REQ_MARK" ]; then old_sum="$(cat "$REQ_MARK")"; else old_sum=""; fi
  if [ "$new_sum" != "$old_sum" ]; then
    echo "[$(date -Is)] Installing ComfyUI requirements..." >&3
    python -m pip install --no-cache-dir -r "$REQ_FILE"
    echo "$new_sum" > "$REQ_MARK"
  else
    echo "[$(date -Is)] Requirements unchanged; skipping install." >&3
  fi
}
install_requirements_if_needed

# ========================================================================
# Ensure ComfyUI directories
# ========================================================================
echo "[$(date -Is)] Ensuring ComfyUI directory structure" >&3
mkdir -p "$COMFY_DIR/models" \
         "$COMFY_DIR/input" \
         "$COMFY_DIR/output" \
         "$COMFY_DIR/custom_nodes"

# ========================================================================
# Bootstrap minimal custom nodes
# ========================================================================
declare -A NODES=(
  ["ComfyUI-Manager"]="https://github.com/ltdrdata/ComfyUI-Manager"
  ["comfyui_controlnet_aux"]="https://github.com/Fannovel16/comfyui_controlnet_aux"
  ["ComfyUI-Impact-Pack"]="https://github.com/ltdrdata/ComfyUI-Impact-Pack"
  ["ComfyUI-Impact-Subpack"]="https://github.com/ltdrdata/ComfyUI-Impact-Subpack"
)

for NODE_NAME in "${!NODES[@]}"; do
  NODE_URL="${NODES[$NODE_NAME]}"
  NODE_DIR="$COMFY_DIR/custom_nodes/$NODE_NAME"
  
  if [ ! -d "$NODE_DIR/.git" ]; then
    echo "[$(date -Is)] Installing $NODE_NAME" >&3
    if try_clone "$NODE_URL" "$NODE_DIR"; then
      # Install requirements if present
      if [ -f "$NODE_DIR/requirements.txt" ] && [ ! -f "$NODE_DIR/.installed" ]; then
        echo "[$(date -Is)] Installing requirements for $NODE_NAME" >&3
        python -m pip install --no-cache-dir -r "$NODE_DIR/requirements.txt" && \
          touch "$NODE_DIR/.installed"
      fi
    else
      echo "[$(date -Is)] WARNING: Failed to clone $NODE_NAME, skipping" >&3
    fi
  else
    echo "[$(date -Is)] $NODE_NAME already exists" >&3
    if [ "$COMFYUI_AUTO_UPDATE" = "true" ]; then
      echo "[$(date -Is)] Auto-update enabled, updating $NODE_NAME" >&3
      git -C "$NODE_DIR" pull --ff-only || true
      
      # Reinstall requirements if they changed
      if [ -f "$NODE_DIR/requirements.txt" ]; then
        echo "[$(date -Is)] Updating requirements for $NODE_NAME" >&3
        python -m pip install --no-cache-dir -r "$NODE_DIR/requirements.txt" || true
      fi
    fi
  fi
done

# ========================================================================
# Launch ComfyUI
# ========================================================================
cd "$COMFY_DIR"
echo "[$(date -Is)] Starting ComfyUI on 0.0.0.0:$COMFYUI_PORT" >&3
echo "[$(date -Is)] ============================================" >&3

exec python main.py \
  --listen 0.0.0.0 \
  --port "$COMFYUI_PORT" \
  --enable-cors-header \
  --output-directory "$COMFY_DIR/output" \
  --input-directory "$COMFY_DIR/input"
