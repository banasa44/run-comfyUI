# ComfyUI Docker Images

This repository contains Docker configurations for running ComfyUI with different GPU configurations.

## Available Images

- **4090**: Optimized for RTX 4090 GPUs (CUDA 12.6.0)
- **5090**: Optimized for RTX 5090 GPUs (CUDA 12.8.0)

## Docker Hub Images

The images are automatically built and published to Docker Hub via GitHub Actions:

- `banasa44/comfyui:4090`
- `banasa44/comfyui:5090`

## Environment Variables

Copy `.env.example` to `.env` and modify as needed:

```bash
cp .env.example .env
```

Key variables:

- `COMFYUI_BRANCH`: ComfyUI version/branch to use
- `COMFYUI_PORT`: Port to expose ComfyUI on
- `COMFYUI_AUTO_UPDATE`: Whether to auto-update ComfyUI on startup

## Usage

```bash
# For RTX 4090
docker run --gpus all -p 8188:8188 banasa44/comfyui:4090

# For RTX 5090
docker run --gpus all -p 8188:8188 banasa44/comfyui:5090
```

## Building Locally

```bash
# Build 4090 image
docker build -f Dockerfiles/Dockerfile.4090 -t comfyui:4090 .

# Build 5090 image
docker build -f Dockerfiles/Dockerfile.5090 -t comfyui:5090 .
```

## GitHub Actions

The repository includes a GitHub Actions workflow that automatically builds and publishes Docker images to Docker Hub when:

- Code is pushed to the main branch
- Workflow is manually triggered

The workflow builds both GPU variants in parallel and tags them appropriately.

### Setup GitHub Secrets

To enable automatic publishing to Docker Hub, you need to set up the following GitHub repository secret:

1. Go to your GitHub repository
2. Navigate to Settings → Secrets and variables → Actions
3. Add the following repository secret:
   - **Name**: `DOCKERHUB_TOKEN`
   - **Value**: `[Your Docker Hub Personal Access Token]`

To create a Docker Hub Personal Access Token:
1. Log in to Docker Hub
2. Go to Account Settings → Security
3. Click "New Access Token"
4. Give it a descriptive name and copy the token
5. Use this token as the value for the `DOCKERHUB_TOKEN` secret

The Docker Hub username (`banasa44`) is already configured in the workflow as an environment variable.
