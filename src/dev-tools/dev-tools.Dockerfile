# syntax=docker/dockerfile:1

# Build stage: install the tools with pixi global, with PIXI_HOME at the final
# path. Pixi writes absolute paths into the environment, so /opt/dev-tools must
# be the same here and in every image that copies it. The global manifest is
# kept at /opt/dev-tools/manifests/pixi-global.toml.
FROM ghcr.io/prefix-dev/pixi:0.81.0-noble AS build
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV PIXI_HOME=/opt/dev-tools
WORKDIR /opt/dev-tools
RUN --mount=type=cache,target=/root/.cache/rattler \
    pixi global install --environment dev-tools \
        bat \
        difftastic \
        direnv \
        fd-find \
        fish \
        fzf \
        gh \
        git \
        htop \
        jq \
        less \
        nvtop \
        ripgrep \
        starship \
        tmux \
        tokei \
        unzip \
        vim \
        zoxide \
        zstd

# Pixi exposes tools through trampolines that put the environment's whole bin
# directory on PATH. Replace them with plain links to the executables pixi
# chose, so the environment's other executables stay off PATH.
RUN --mount=type=cache,target=/root/.cache/rattler \
    pixi global list --json > /tmp/global.json \
    && rm -rf bin && mkdir bin \
    && pixi exec jq -r '.[] | .name as $env | .exposed[] | [$env, .exposed_name, .executable] | @tsv' /tmp/global.json \
    | while IFS=$'\t' read -r env name exe; do \
        test -x envs/$env/bin/$exe && ln -s ../envs/$env/bin/$exe bin/$name || exit 1; \
    done \
    && test -n "$(ls bin)"

# Pixi only collects completion files that packages install. Generate fish
# completions for the tools that print their own but don't ship them.
RUN bin/bat --completion fish > completions/fish/bat.fish \
    && bin/fd --gen-completions fish > completions/fish/fd.fish \
    && bin/rg --generate complete-fish > completions/fish/rg.fish \
    && bin/starship completions fish > completions/fish/starship.fish

# conda-forge's fish looks for vendor completions under its build-time prefix,
# not the environment, but it does search $prefix/etc/fish/completions. Point
# that at the directory where pixi collects the tools' fish completions.
RUN ln -s ../../../../completions/fish envs/dev-tools/etc/fish/completions

# Image stage: holds only /opt/dev-tools, for COPY --from in other images.
FROM scratch AS dev-tools
COPY --from=build /opt/dev-tools /opt/dev-tools
