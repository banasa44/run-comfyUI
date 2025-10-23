#!/usr/bin/env bash
# ========================================================================
# Test local de les imatges Docker abans de pujar a RunPod
# ========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuració
GPU_TYPE="${1:-4090}"  # 4090 o 5090
TEST_WORKSPACE="${TEST_WORKSPACE:-$HOME/test-comfyui-workspace}"
IMAGE_TAG="comfyui:test-${GPU_TYPE}"

echo -e "${GREEN}=== Testing ComfyUI Docker Image ===${NC}"
echo "GPU Type: $GPU_TYPE"
echo "Test Workspace: $TEST_WORKSPACE"
echo "Image Tag: $IMAGE_TAG"
echo ""

# ========================================================================
# 1. Check NVIDIA Docker Runtime
# ========================================================================
echo -e "${YELLOW}[1/5] Checking NVIDIA Docker runtime...${NC}"
if ! docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi &>/dev/null; then
  echo -e "${RED}ERROR: NVIDIA Docker runtime no disponible${NC}"
  echo "Instal·la nvidia-container-toolkit:"
  echo "  https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
  exit 1
fi
echo -e "${GREEN}✓ NVIDIA runtime OK${NC}"
echo ""

# ========================================================================
# 2. Build Image
# ========================================================================
echo -e "${YELLOW}[2/5] Building Docker image...${NC}"
DOCKERFILE="$REPO_ROOT/Dockerfiles/Dockerfile.$GPU_TYPE"

if [ ! -f "$DOCKERFILE" ]; then
  echo -e "${RED}ERROR: $DOCKERFILE no existeix${NC}"
  exit 1
fi

cd "$REPO_ROOT"
if ! docker build -t "$IMAGE_TAG" -f "$DOCKERFILE" .; then
  echo -e "${RED}ERROR: Docker build failed${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Build OK${NC}"
echo ""

# ========================================================================
# 3. Create Test Workspace
# ========================================================================
echo -e "${YELLOW}[3/5] Creating test workspace...${NC}"
mkdir -p "$TEST_WORKSPACE"
echo -e "${GREEN}✓ Workspace created at $TEST_WORKSPACE${NC}"
echo ""

# ========================================================================
# 4. Run Container (detached, amb timeout)
# ========================================================================
echo -e "${YELLOW}[4/5] Running container...${NC}"
CONTAINER_NAME="comfyui-test-$$"

docker run -d --rm \
  --name "$CONTAINER_NAME" \
  --gpus all \
  -p 18188:8188 \
  -p 18888:8888 \
  -v "$TEST_WORKSPACE:/workspace" \
  -e COMFYUI_BRANCH=v0.3.66 \
  -e COMFYUI_AUTO_UPDATE=false \
  "$IMAGE_TAG"

echo "Container $CONTAINER_NAME arrencant..."
echo ""

# Function to cleanup on exit
cleanup() {
  echo ""
  echo -e "${YELLOW}Cleaning up...${NC}"
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  echo -e "${GREEN}✓ Container stopped${NC}"
}
trap cleanup EXIT

# ========================================================================
# 5. Wait for ComfyUI to Start + Health Check
# ========================================================================
echo -e "${YELLOW}[5/5] Waiting for ComfyUI to start (max 120s)...${NC}"
SUCCESS=false

for i in {1..60}; do
  # Check if container is still running
  if ! docker ps --filter "name=$CONTAINER_NAME" --format '{{.Names}}' | grep -q "$CONTAINER_NAME"; then
    echo -e "${RED}ERROR: Container exited prematurely${NC}"
    echo ""
    echo "=== Container Logs ==="
    docker logs "$CONTAINER_NAME" 2>&1 | tail -n 50
    exit 1
  fi
  
  # Check ComfyUI endpoint
  if curl -f -s http://localhost:18188/ > /dev/null 2>&1; then
    SUCCESS=true
    break
  fi
  
  echo -n "."
  sleep 2
done

echo ""

if [ "$SUCCESS" = true ]; then
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}✓ SUCCESS: ComfyUI is running!${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  echo "ComfyUI UI: http://localhost:18188/"
  echo "JupyterLab: http://localhost:18888/"
  echo ""
  echo "Check logs:"
  echo "  docker logs -f $CONTAINER_NAME"
  echo ""
  echo "Stop container:"
  echo "  docker stop $CONTAINER_NAME"
  echo ""
  
  # Show last 20 lines of logs
  echo -e "${YELLOW}=== Last 20 lines of logs ===${NC}"
  docker logs "$CONTAINER_NAME" 2>&1 | tail -n 20
  
  # Keep container running for inspection
  echo ""
  echo -e "${YELLOW}Container running. Press Ctrl+C to stop.${NC}"
  
  # Wait for user interrupt
  while true; do
    sleep 10
    # Verify container still running
    if ! docker ps --filter "name=$CONTAINER_NAME" --format '{{.Names}}' | grep -q "$CONTAINER_NAME"; then
      echo -e "${RED}Container stopped unexpectedly${NC}"
      exit 1
    fi
  done
  
else
  echo -e "${RED}========================================${NC}"
  echo -e "${RED}✗ FAILURE: ComfyUI failed to start${NC}"
  echo -e "${RED}========================================${NC}"
  echo ""
  echo "=== Full Container Logs ==="
  docker logs "$CONTAINER_NAME" 2>&1
  exit 1
fi
