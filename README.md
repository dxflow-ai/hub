# dxflow hub

Ready-to-run application and workflow templates for dxflow — browse them at [dxflow.ai/hub](https://dxflow.ai/hub).

Each template is a pre-configured app you can launch on dxflow in a few clicks, spanning genomics, molecular dynamics, structural biology, data science, fluid dynamics, and more.

## Structure

Workflows live in numbered category folders; each workflow is a numbered folder inside one:

```
NN.<category>/          # a numbered category folder
  00.index.md           # category landing page
  NN.<key>/             # a numbered workflow folder — <key> is the handle the scripts take
    index.md            # required: docs + workflow definition (## Configuration blocks)
    build/              # required to publish — the image sources:
      Dockerfile        #   image recipe (or a podman/singularity/apptainer equivalent)
      entrypoint.sh     #   required: the configurable, env-driven entrypoint
    verify/             # required to publish — end-to-end test fixtures:
      input/            #   optional: files uploaded to the input volume before start
      check.sh          #   required: the success check (see verify.sh for its helpers)
      config.sh         #   optional: sourced settings — input/output dirs, timeout
```

A workflow is published/released only once it has both `build/` and `verify/` (its image is built and end-to-end tested first). Every workflow ships its own image built from `build/` — even one that just re-publishes an upstream image — so it lands in our registry (`ghcr.io/dxflow-ai`) with a configurable, env-driven `entrypoint.sh`. The recipe is a `Dockerfile` for docker/podman, or the equivalent definition for singularity/apptainer. Entries with just an `index.md` are drafts — not built, verified, or published yet.

`index.md` holds a `## Configuration` section with three fenced blocks: **`yaml`** (the workflow definition `dxflow workflow create` and `verify.sh` run), **`ini`** (override defaults), and **`json`** (metadata: `arch` list, the `image` this folder builds/publishes, image `version`, `minimum` resources). The yaml may reference more images than `json.image` — the extras are reused from other tools; build/publish only handle this folder's own `image`, while verify checks every step image is present.

When adding a tool, copy an existing published workflow (one that already has `build/` and `verify/`) as a reference.

## Scripts

`<key>` is the folder name after the `NN.` prefix. Runs on a Linux host, not macOS.

```bash
./prepare.sh                    # one-time host setup: docker+buildx, builder, QEMU, dxflow CLI
./build.sh <key>                # build this arch and load it into local docker (for verify)
./verify.sh <key>               # end-to-end test the loaded image through a live dxflow engine
./publish.sh <key>              # build all arches (from json "arch") and push a multi-arch image
```

Run `build` before `verify` — verify uses the locally-loaded image (the engine's `pull: missing` finds it, no registry pull). `publish` builds and pushes both arches as one `:latest` + `:<version>` manifest, and needs `docker login` to the registry first.

`verify.sh` needs the `dxflow` CLI, `docker`, and a reachable engine. It builds the image, deploys and starts the real workflow, uploads `verify/input/`, then runs the tool's `verify/check.sh` — which asserts success using helpers verify.sh provides: `wait_exit` + `expect_output`/`expect_file` for a batch tool that produces files, or `wait_running` + `expect_http`/`expect_port` for a long-running service (desktop, IDE, notebook). The engine must be started with its **working directory set to its volume dir** (it passes relative volume paths straight to `docker run -v`), and needs Docker ≥ 23.

## Contributing

Have a tool or workflow others would find useful? Add it as a Markdown entry in the matching domain and open a pull request — community templates are welcome.

## Issues

Spotted a problem with a template or want to request one? Open it in the [community issue tracker](https://github.com/dxflow-ai/community/issues).
