# dev-tools

Shell tools shared by the development images, installed from conda-forge with `pixi global`. The image is built `FROM scratch` and holds only `/opt/dev-tools`, so other images can simply copy it:

```dockerfile
ARG DEV_TOOLS=tyxw-dev-tools:20260925
FROM ${DEV_TOOLS} AS dev-tools
...
COPY --from=dev-tools /opt/dev-tools /opt/dev-tools
ENV PATH=/opt/dev-tools/bin:$PATH LANG=C.UTF-8
```

The path `/opt/dev-tools` is fixed, since Pixi writes absolute paths into the environment.

## Files

- `dev-tools.Dockerfile`: lists the tools to install, runs `pixi global install` with `PIXI_HOME=/opt/dev-tools`, and links the executables pixi exposes into `/opt/dev-tools/bin`.

## Layout

- `/opt/dev-tools/envs/dev-tools`: the pixi environment, with the tools, their libraries, man pages and shell completions.
- `/opt/dev-tools/bin`: links to just the tools. Only this directory goes on `PATH`, so the environment's other executables don't shadow the image's own.
- `/opt/dev-tools/completions`: the tools' shell completions, collected by pixi.
- `/opt/dev-tools/manifests/pixi-global.toml`: the global manifest written by the install, listing the packages and the executables exposed for each.
- `/opt/dev-tools/.pixi`: the real pixi environments.

## Build

Run from this directory:

```sh
docker buildx build -f dev-tools.Dockerfile -t tyxw-dev-tools:$(date +%Y%m%d) --load .
```

Then rebuild the images that use it, passing the new tag with `--build-arg DEV_TOOLS=tyxw-dev-tools:<date>` or updating their default.

## Adding a tool

Add it to the `pixi global install` list in `dev-tools.Dockerfile` and rebuild. Pixi exposes the executables of each listed package, but not those of its dependencies, and the Dockerfile links whatever pixi exposed. To see what a build exposed, read its manifest at `/opt/dev-tools/manifests/pixi-global.toml`.

The dev-tools image itself has no shell, so read the manifest from an image that copies it (as above), or with `docker create` and `docker cp`.

Pixi's own `bin` entries are trampolines that add the environment's whole `bin` directory to `PATH` for the tool and every process it starts, such as a fish or tmux session. The Dockerfile replaces them with plain symlinks to avoid this.

Avoid pure Python tools, as they will pull in a separate installation of Python.

## Shell completions

conda-forge's fish looks for extra completions under the path it was built at, not the environment, so the Dockerfile links `etc/fish/completions` (which fish does search) to `/opt/dev-tools/completions/fish`, where pixi collects the tools' fish completions.

Pixi only collects completion files that packages install. For a tool that can print its own completions but whose package doesn't ship them (currently bat, fd, rg and starship), the Dockerfile writes them into `/opt/dev-tools/completions/fish`. 
