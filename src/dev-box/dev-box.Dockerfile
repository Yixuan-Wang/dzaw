# syntax=docker/dockerfile:1

# Shell tools image built from ../dev-tools. Override with --build-arg DEV_TOOLS=...
ARG DEV_TOOLS=tyxw-dev-tools:20261007
FROM ${DEV_TOOLS} AS dev-tools

# Shared base: CUDA toolchain, system Python 3.12, and uv.
FROM nvidia/cuda:13.0.3-cudnn-devel-ubuntu24.04 AS base

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y curl ffmpeg python3.12 python3.12-dev python3 python-is-python3 \
        cmake gdb ninja-build strace \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:0.12.17 /uv /uvx /bin/
ENV UV_LINK_MODE=copy

# Lock stage: resolve requirements.in on the same platform as the image.
# Existing pins in requirements.txt are kept unless they must change.
FROM base AS lock
WORKDIR /lock
COPY requirements.in requirements.tx[t] ./
RUN uv pip compile requirements.in --python python3.12 --torch-backend=cu130 -o requirements.txt

# Export stage: holds only the lockfile, for --output to the host.
FROM scratch AS lockfile
COPY --from=lock /lock/requirements.txt /

# Image stage
FROM base AS dev-box
COPY requirements.txt /tmp/requirements.txt
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system --break-system-packages --compile-bytecode --python python3.12 \
        --torch-backend=cu130 -r /tmp/requirements.txt

COPY --from=dev-tools /opt/dev-tools /opt/dev-tools
ENV PATH=/opt/dev-tools/bin:$PATH LANG=C.UTF-8

CMD ["python3.12"]
