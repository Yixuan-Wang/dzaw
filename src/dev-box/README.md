# dev-box

Personal ML development image: CUDA 13.0 + cuDNN (devel), Ubuntu 24.04, system Python 3.12, and the packages in `requirements.in` installed with uv.

## Files

- `requirements.in`: top-level dependencies. Edit this file.
- `requirements.txt`: the lockfile generated from `requirements.in`. Don't edit it by hand, and commit it.
- `dev-box.Dockerfile`: multistage build with `base`, `lock`, `lockfile` and `dev-box` stages.

## Build

Run all commands from this directory.

### 1. Lock (only after editing `requirements.in`)

```sh
docker buildx build -f dev-box.Dockerfile --target lockfile --output type=local,dest=. .
```

This resolves `requirements.in` inside the image's platform (Python 3.12, CUDA 13.0 torch wheels) and writes `requirements.txt` here. Existing pins are kept unless they must change. To force a fresh resolve, add `--no-cache-filter lock`.

### 2. Build the image

```sh
docker buildx build -f dev-box.Dockerfile --target dev-box -t tyxw-dev-box:$(date +%Y%m%d) --load .
```

This installs exactly what `requirements.txt` pins and does not re-lock.

## Run

Requires the NVIDIA Container Toolkit on the host.

```sh
docker run --rm -it --gpus all tyxw-dev-box:20260925
```

Quick GPU check:

```sh
docker run --rm --gpus all tyxw-dev-box:20260925 \
    python -c "import torch; print(torch.__version__, torch.cuda.is_available())"
```

## Apptainer

Convert the Docker image from the local Docker daemon into a SIF in the project's `dist/` directory. There's no need to push it to a registry first.

```sh
apptainer build ../../dist/tyxw-dev-box_20260925.sif docker-daemon://tyxw-dev-box:20260925
```

On a machine without Docker, export the image with `docker save tyxw-dev-box:20260925 -o dev-box.tar`, copy the tar over, and build from `docker-archive://dev-box.tar` instead.

Run with `--nv` for GPU access (instead of `--gpus all`):

```sh
apptainer run --nv ../../dist/tyxw-dev-box_20260925.sif                  # python3.12
apptainer run --nv ../../dist/tyxw-dev-box_20260925.sif python train.py  # arguments replace CMD, as in Docker
```

Differences from Docker:

- The image filesystem is read-only and you run as your own user, so `uv pip install --system` doesn't work inside it. Use `uv pip install --user`, or `--writable-tmpfs` for temporary changes. For anything permanent, add it to `requirements.in` and rebuild.
- Your host `$HOME` is mounted, so any packages in `~/.local/lib/python3.12/site-packages` override the image's.
