# MinerU-deploy

Docker image and scripts to run the [MinerU](https://github.com/opendatalab/MinerU) **`mineru-api`** service with **host-mounted model weights** (the image does not bundle pipeline/VLM checkpoints).

## Container images (GHCR)

GitHub Actions workflow [`.github/workflows/mineru-image.yml`](.github/workflows/mineru-image.yml) builds and pushes:

| Registry path | Tags |
|---------------|------|
| `ghcr.io/jimmysitu/mineru-deploy` | `mineru-<semver>` (pinned to upstream release), `latest` |

`<semver>` follows upstream tags such as `mineru-3.1.14-released` → image tag `mineru-3.1.14`.

Trigger manually (**Actions → MinerU image → Run workflow**) or wait for the weekly schedule. Optionally set **MinerU release tag** and whether to **push** the image.

## Host prerequisites

- Docker (GPU: NVIDIA Container Toolkit if you use `--gpus all`; override `GPU_ARGS` if needed).
- Enough disk space for pipeline + VLM weights.
- Python 3 + MinerU extras **only on the machine where you download models** (see below).

## Quick start

1. **Download weights** (on a machine with network access and `mineru-models-download`, e.g. after `pip install -U "mineru[core]"`):

   ```bash
   ./scripts/download_mineru_models.sh
   ```

   Optional: `-s huggingface|modelscope`, `-m pipeline|vlm|all`, `-d /path/to/mineru-models`.  
   Deploy expects **both** `pipeline/` and `vlm/` under `MODELS_DIR` unless you set `PIPELINE_MODELS_DIR` and `VLM_MODELS_DIR` yourself.

2. **Run the API** (defaults match this repo’s GHCR image):

   ```bash
   ./scripts/deploy_mineru_image.sh
   ```

   Default image: `ghcr.io/jimmysitu/mineru-deploy:latest`. Override with `IMAGE=...` for another registry or tag (for example `IMAGE=ghcr.io/jimmysitu/mineru-deploy:mineru-3.1.14`).

   Help:

   ```bash
   ./scripts/deploy_mineru_image.sh --help
   ```

## Layout

| Path | Role |
|------|------|
| `docker/Dockerfile` | Runtime image: `vllm/vllm-openai` base + `mineru[core]` + `/etc/mineru/mineru.json` pointing at `/models/pipeline` and `/models/vlm` |
| `scripts/download_mineru_models.sh` | Fetch weights and symlink `mineru-models/pipeline`, `mineru-models/vlm` |
| `scripts/deploy_mineru_image.sh` | `docker run` with volume mounts for models and host data dir |

API URL example after deploy: `http://127.0.0.1:8000` (default host port `8000`).
