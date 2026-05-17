#!/usr/bin/env python3
import argparse
import importlib.util
import pathlib
import subprocess
import sys


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--comfyui-dir", default="/opt/ComfyUI")
    args = parser.parse_args()

    comfyui_dir = pathlib.Path(args.comfyui_dir)
    print("== Runtime check ==")
    print(f"python: {sys.executable}")
    print(f"comfyui_dir: {comfyui_dir}")

    if not (comfyui_dir / "main.py").exists():
        print("ERROR: ComfyUI main.py was not found.", file=sys.stderr)
        return 2

    try:
        import torch
    except Exception as exc:
        print(f"ERROR: torch import failed: {exc}", file=sys.stderr)
        return 2

    print(f"torch: {torch.__version__}")
    print(f"torch_cuda: {torch.version.cuda}")
    print(f"cuda_available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"gpu: {torch.cuda.get_device_name(0)}")
    else:
        print("WARNING: CUDA is not visible inside the container.", file=sys.stderr)

    for module in ("safetensors", "huggingface_hub"):
        spec = importlib.util.find_spec(module)
        print(f"{module}: {'ok' if spec else 'missing'}")

    result = subprocess.run(
        [sys.executable, "-m", "pip", "check"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    print(result.stdout.strip() or "pip check: ok")
    if result.returncode != 0:
        print("WARNING: pip check reported dependency conflicts; continuing startup.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
