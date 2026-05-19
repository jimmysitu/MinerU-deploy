# MinerU-deploy

Docker images and scripts to run the [MinerU](https://github.com/opendatalab/MinerU) **`mineru-api`** service with **host-mounted model weights** (images do not bundle pipeline/VLM checkpoints).

Two image variants are published to GHCR:

| Variant | Base | Use when |
|---------|------|----------|
| **GPU** (default) | `vllm/vllm-openai` + `mineru[core]` | NVIDIA GPU with CUDA; VLM / hybrid backends |
| **CPU (slim)** | `python:3.10-slim` + `mineru[core]` + PyTorch CPU wheels | No GPU; x86_64 Linux; pipeline backend only |

CPU packaging follows the community approach in [MinerU discussion #4011](https://github.com/opendatalab/MinerU/discussions/4011). Inference on CPU is much slower than GPU and is best for light or non-latency-sensitive workloads.

## Container images (GHCR)

### GPU image

Workflow [`.github/workflows/mineru-image.yml`](.github/workflows/mineru-image.yml) builds and pushes:

| Registry path | Tags |
|---------------|------|
| `ghcr.io/jimmysitu/mineru-deploy` | `mineru-<semver>`, `latest` |

Trigger: **Actions → MinerU image → Run workflow**, or weekly (Sunday 00:00 UTC).

### CPU image (slim)

Workflow [`.github/workflows/mineru-cpu-image.yml`](.github/workflows/mineru-cpu-image.yml) builds and pushes:

| Registry path | Tags |
|---------------|------|
| `ghcr.io/jimmysitu/mineru-deploy` | `mineru-<semver>-cpu`, `cpu-latest` |

`<semver>` follows upstream tags such as `mineru-3.1.14-released` → `mineru-3.1.14-cpu`.

Trigger: **Actions → MinerU CPU image → Run workflow**, or weekly (Sunday 01:00 UTC).

Both workflows resolve the latest upstream `mineru-*-released` tag unless you set **MinerU release tag** manually. Set **push image** to `false` to build locally without publishing.

## Host prerequisites

- Docker.
- **GPU image:** NVIDIA Container Toolkit if you use the default `GPU_ARGS=--gpus all`.
- **CPU image:** no GPU or CUDA required; `linux/amd64` only.
- Enough disk space for pipeline + VLM weights (same download script for both variants).
- Python 3 + MinerU extras **only on the machine where you download models** (see below).

## Quick start (GPU)

1. **Download weights** (on a machine with network access and `mineru-models-download`, e.g. after `pip install -U "mineru[core]"`):

   ```bash
   ./scripts/download_mineru_models.sh
   ```

   Optional: `-s huggingface|modelscope`, `-m pipeline|vlm|all`, `-d /path/to/mineru-models`.  
   Deploy expects **both** `pipeline/` and `vlm/` under `MODELS_DIR` unless you set `PIPELINE_MODELS_DIR` and `VLM_MODELS_DIR` yourself.

2. **Run the API** (defaults match the GPU GHCR image):

   ```bash
   ./scripts/deploy_mineru_image.sh
   ```

   Default image: `ghcr.io/jimmysitu/mineru-deploy:latest`. Pin a version with e.g. `IMAGE=ghcr.io/jimmysitu/mineru-deploy:mineru-3.1.14`.

   Help: `./scripts/deploy_mineru_image.sh --help`

## Quick start (CPU)

CPU deploy uses the **pipeline** backend only; you do **not** need VLM weights. Download pipeline models only:

```bash
./scripts/download_mineru_models.sh -m pipeline
IMAGE=ghcr.io/jimmysitu/mineru-deploy:cpu-latest ./scripts/deploy_mineru_image.sh
```

The deploy script detects `cpu-latest` / `*-cpu` tags: no GPU, no VLM directory check, and `--device cpu`. Select the pipeline backend from the client request, for example with `mineru -b pipeline`. If `mineru-models/vlm` exists it is still mounted (optional).

Override API flags with `EXTRA_MINERU_API_ARGS` if needed.

Example client (pipeline backend):

```bash
mineru -p input.pdf -o output -b pipeline --api-url http://127.0.0.1:8000
```

## Layout

| Path | Role |
|------|------|
| `docker/Dockerfile` | GPU runtime: `vllm/vllm-openai` + `mineru[core]` + `/etc/mineru/mineru.json` |
| `docker/Dockerfile.cpu` | CPU runtime: `python:3.10-slim` + `mineru[core]` (PyTorch CPU index) + same config layout |
| `scripts/download_mineru_models.sh` | Fetch weights; symlinks `mineru-models/pipeline`, `mineru-models/vlm` |
| `scripts/deploy_mineru_image.sh` | `docker run` with volume mounts for models and host data dir |

API URL after deploy: `http://127.0.0.1:8000` (default host port `8000`).

## Build images locally

```bash
# GPU (set version to match a PyPI mineru release)
docker build -f docker/Dockerfile \
  --build-arg MINERU_VERSION=3.1.14 \
  --build-arg MINERU_RELEASE_TAG=mineru-3.1.14-released \
  -t mineru-deploy:local docker

# CPU (slim)
docker build -f docker/Dockerfile.cpu \
  --build-arg MINERU_VERSION=3.1.14 \
  --build-arg MINERU_RELEASE_TAG=mineru-3.1.14-released \
  -t mineru-deploy:cpu-local docker
```
