# RunPod Community Cloud ComfyUI image

This project builds a RunPod-friendly ComfyUI Docker image for Community Cloud:

- ComfyUI and PyTorch come from the official RunPod ComfyUI image.
- Large checkpoints and LoRAs are downloaded at Pod startup from a manifest.
- Network Volume is optional, so GPU selection is not tied to a single volume region.
- `/workspace/comfyui` is used for runtime models, inputs, and outputs by default.

## File map

- `Dockerfile`: thin wrapper over `runpod/comfyui:latest`.
- `config/models.example.json`: model manifest template.
- `scripts/start.sh`: RunPod entrypoint.
- `scripts/download_models.py`: resumable-ish model downloader with optional sha256 checks.
- `scripts/check_env.py`: torch/CUDA/pip sanity check.
- `runpod-template.env.example`: environment variables for the RunPod template.

## Build and push

Replace the image name with your Docker Hub or GHCR repo.

### Recommended: GitHub Actions to GHCR

Push this directory to a GitHub repository. The included workflow publishes:

```text
ghcr.io/YOUR_GITHUB_USER/comfyui-runpod:cuda12.8
ghcr.io/YOUR_GITHUB_USER/comfyui-runpod:GIT_COMMIT_SHA
```

After the first run, open the package in GitHub and change visibility to
public, unless you want to configure private registry credentials in RunPod.

### Manual Docker push

```bash
docker build --platform linux/amd64 -t docker.io/YOUR_USER/comfyui-runpod:cuda12.8 .
docker push docker.io/YOUR_USER/comfyui-runpod:cuda12.8
```

To use the Blackwell-compatible official base image:

```bash
docker build --platform linux/amd64 \
  --build-arg BASE_IMAGE=runpod/comfyui:cuda12.8 \
  -t docker.io/YOUR_USER/comfyui-runpod:cuda12.8 .
```

## RunPod template settings

- Image: `docker.io/YOUR_USER/comfyui-runpod:cuda12.8`
- Ports: `8188/http`
- Container disk: `40 GB` or more
- Volume disk: size for the models you will download during this Pod lease
- Network Volume: leave empty when you want maximum Community Cloud GPU availability

Use `runpod-template.env.example` as the environment variable checklist.

## Model manifest

The startup script reads a manifest from one of these sources:

1. `MODEL_MANIFEST_JSON`: compact JSON pasted into a RunPod env var.
2. `MODEL_MANIFEST_URL`: raw JSON URL from S3, Cloudflare R2, Backblaze B2, GitHub raw, etc.
3. `/workspace/config/models.json`: a file already present in the Pod.

Minimal manifest:

```json
{
  "models": [
    {
      "name": "base checkpoint",
      "enabled": true,
      "url": "https://example.com/model.safetensors",
      "path": "models/checkpoints/model.safetensors",
      "sha256": ""
    },
    {
      "name": "my LoRA",
      "enabled": true,
      "url": "${LORA_URL}",
      "path": "models/loras/my_lora.safetensors",
      "sha256": ""
    }
  ]
}
```

Relative `path` values are written under `/workspace/comfyui`.

## Dependency check

Set `RUN_DEP_CHECK=1` in the template. On startup it prints:

- Python path
- torch version
- CUDA version
- visible GPU name
- `pip check` result

The startup command also enables CORS with `COMFYUI_CORS_ORIGIN=*` by default
so ComfyUI can work behind the RunPod HTTP proxy.

Then open the RunPod HTTP service on port `8188`.

## Operating model

Best balance for Community Cloud:

```text
Docker image: ComfyUI + dependencies + custom nodes
External object storage: checkpoints + LoRAs + VAEs
RunPod /workspace: runtime cache for the current Pod lease
Network Volume: optional, mainly for outputs/backups, not required for startup
```
