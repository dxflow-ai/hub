# dxflow hub

Ready-to-run application and workflow templates for dxflow — browse them at [dxflow.ai/hub](https://dxflow.ai/hub).

Each template is a pre-configured app you can launch on dxflow in a few clicks, spanning genomics, molecular dynamics, structural biology, data science, fluid dynamics, and more.

## Structure

Workflows live in numbered category folders; each workflow is a numbered folder inside one:

```
NN.<category>/          # a numbered category folder
  00.index.md           # category landing page
  NN.<key>/             # a numbered workflow folder — <key> is the handle the scripts take,
                        #   and the name it publishes as: dxflow workflow create hub://<key>
    index.md            # required: docs + workflow definition (## Configuration blocks)
    build/              # required to publish — the image sources:
      Dockerfile        #   image recipe (or a podman/singularity/apptainer equivalent)
      entrypoint.sh     #   required: the configurable, env-driven entrypoint
    verify/             # required to publish — end-to-end test fixtures:
      input/            #   optional: files uploaded to the input volume before start
      check.sh          #   required: the success check (see scripts/verify.sh for its helpers)
      config.sh         #   optional: sourced settings — input/output dirs, timeout
    version/            # where its version comes from:
      resolve.sh        #   the upstream lookup (see scripts/version.sh for its helpers)
```

A workflow is published/released only once it has both `build/` and `verify/` (its image is built and end-to-end tested first). Every workflow ships its own image built from `build/` — even one that just re-publishes an upstream image — so it lands in our registry (`ghcr.io/dxflow-ai`) with a configurable, env-driven `entrypoint.sh`. The recipe is a `Dockerfile` for docker/podman, or the equivalent definition for singularity/apptainer. Entries with just an `index.md` are drafts — not built, verified, or published yet.

The engine reads this repository live from GitHub (`main` branch): `dxflow workflow create hub://<key>` locates `NN.<category>/NN.<key>/index.md`, extracts its `## Configuration` yaml block, and deploys it. `dxflow workflow hub search <query>` and `dxflow workflow hub inspect <key>` browse the same content, so a merged entry is deployable by name right away. The `## Configuration` section is what makes an entry deployable — a draft, which has yet to gain one, carries a `## Coming soon` section instead and stays out of hub search results.

A published entry lays its sections out as: intro → `## Usage` → `## Configuration` → any reference sections (output files, notes, references).

`index.md` holds a `## Configuration` section with three fenced blocks: **`yaml`** (the workflow definition `dxflow workflow create` and `verify.sh` run), **`ini`** (override defaults), and **`json`** (metadata: `arch` list, the `image` this folder builds/publishes, image `version`, `minimum` resources). The yaml may reference more images than `json.image` — the extras are reused from other tools; build/publish only handle this folder's own `image`, while verify checks every step image is present.

A step's relative `host` path is resolved by the engine against its own directory (`~/.dxflow`), so every entry mounts `./volume` — the engine volume, the root of what `dxflow artifact` and the console's **Artifacts** show — or a directory inside it (`./volume/input`). A host path that does not start with `./volume` lands outside the volume, where an upload cannot reach it.

When adding a tool, copy an existing published workflow (one that already has `build/` and `verify/`) as a reference.

## Versions

An entry carries its version twice: as the pin its `build/Dockerfile` builds from, and as the `version` in its `index.md` json block — the tag it publishes as. `version.sh` keeps both in step with what upstream ships today:

```bash
make version ARGS=fastqc                # what one entry is behind on
make version ARGS=--all                 # ... every entry
make version ARGS="fastqc --apply"      # write the updates
```

The GitHub lookups go out anonymously unless the environment carries a token, and anonymous is 60 an hour for the whole host — enough for a sweep or two, and a 403 once it runs out. A signed-in `gh` is borrowed automatically; otherwise set `GITHUB_TOKEN` yourself, as Actions does.

It reports by default and writes only with `--apply`, which leaves a diff to read and an entry ready to `make build`, `make verify`, and `make publish`. It publishes nothing itself: a bump is a rebuild, and a rebuild is verified first.

Where a version comes from is the entry's own business, so each entry answers for itself in `version/resolve.sh` — sourced with the lookups in `.github/scripts/upstream.sh` in scope (`docker_tag`, `github_release`, `gitlab_tag`, `xbps_version`, `conda_version`, `pypi_version`, `apt_version`, `listing`, …), printing one `NAME=VERSION` line per pin it tracks:

```sh
echo "VERSION=$(docker_tag staphb/fastqc '^[0-9]+\.[0-9]+\.[0-9]+$')"
echo "NOVNC=$(github_release novnc/noVNC)"
```

`VERSION` is always the entry's own version — the one the json records and the image publishes as — and it lands in `ARG VERSION`. Every other pin lands in `ARG <NAME>_VERSION`, named for what it pins rather than the part it plays: `NOVNC_VERSION`, `CUDA_VERSION`, `VOID_VERSION`, never a `BASE_VERSION`. An entry that is little more than the thing it builds on records that as its own: the Void desktop's version is the dated snapshot it starts from. A Dockerfile keeps its pins in one block at the top, and a stage that uses one re-declares it bare — an `ARG` above `FROM` only reaches the `FROM` lines:

```dockerfile
# Version pins — refresh them with .github/scripts/version.sh
ARG VERSION=3.4.2

FROM ghcr.io/dxflow-ai/ubuntu:latest
...
ARG VERSION
```

The pattern a check passes to a lookup is the entry's pinning policy, so a base can follow its patches without being dragged onto a new major (`'^12\.[0-9]+\.[0-9]+-devel-ubuntu22\.04$'` keeps GROMACS on CUDA 12 and jammy).

An entry that installs from a package repository asks for a version there too, rather than taking whatever the repository is serving that day: `xbps-install -Sy "firefox-${PACKAGE_VERSION}"`, `code=${PACKAGE_VERSION}`, `jupyterlab=${VERSION}`, `install.sh --version="${VERSION}"`. So `PACKAGE_VERSION` is the version as a repository spells it, which is not always what the entry publishes as — xbps carries a packaging revision (`155.0_1`), the Microsoft apt index a build timestamp (`1.137.0-1788902055`). The check prints both, and the clean one is what reaches the json.

A rolling repository keeps only what it serves now, so a pinned `xbps-install` stops building the day upstream moves on. That is the point: the build fails rather than publishing a `firefox:155.0` that holds 156.0, and the fix is `make version ARGS="firefox --apply"` and a rebuild.

A pin with no matching `ARG` is reported but not written — the xbps entries pin through `PACKAGE_VERSION` and keep no `ARG VERSION` for the clean one, and Scipion's installer takes the current release with nothing to pin at all.

## Publishing

Publishing runs on GitHub Actions. Dispatch it from a workstation with `make publish`, which picks an entry, shows what a rebuild of it reaches, and hands it to Actions:

```bash
make publish                    # pick a workflow from the list, then dispatch
make publish ARGS=fastqc        # dispatch that one
```

It needs `gh` signed in, and it dispatches the branch you are on — so push before you publish; the runners check out the pushed ref, not your working copy. The same run starts from the Actions tab by picking a workflow from the dropdown. It fans out one runner per key and target arch — `ubuntu-latest` for amd64, `ubuntu-24.04-arm` for arm64 — so each image is built and verified on the hardware it ships for, then joins the arches into one `:latest` + `:<version>` manifest on `ghcr.io/dxflow-ai`. An arch only reaches the registry untagged until every arch has passed, so a failed check leaves the published tags as they were. A draft is rejected up front, before a runner starts.

Some entries are the base of others — a Dockerfile that starts `FROM ghcr.io/dxflow-ai/<key>`. Publishing one of those rebuilds everything standing on it: the run is split into waves, and a wave starts only once the wave it builds on has published, so a dependent always pulls the base that was just tagged. Picking `ubuntu` therefore publishes ubuntu, then pymol, scipion, paraview, visit, and vscode; picking a leaf is a single wave. Untick **dependents** to publish the base alone. Two waves cover the hub as it stands; if an entry ever gains a base that is itself built on one, `select.sh` refuses the run rather than half-publishing it, and the fix is a third wave job.

The steps a run performs are the scripts in `.github/scripts/`, each taking `<key>` as `$WORKFLOW` or as its first argument. They run on a Linux host with Docker ≥ 23, in or out of Actions, and the Makefile wraps the ones worth driving by hand (`make build ARGS=fastqc`):

```bash
./.github/scripts/version.sh <key>    # report what upstream ships (--apply to write)
./.github/scripts/prepare.sh          # buildx builder + the dxflow CLI
./.github/scripts/build.sh <key>      # build this arch and load it into local docker
./.github/scripts/boot.sh             # boot an engine rooted in its volume dir
./.github/scripts/verify.sh <key>     # end-to-end test the loaded image through that engine
./.github/scripts/push.sh <key>       # push this arch untagged and record its digest
./.github/scripts/publish.sh <key>    # join the digests into the tagged manifest
./.github/scripts/run.sh <key>        # deploy and leave running, to drive it by hand
./.github/scripts/options.sh          # refresh the dropdown after adding an entry
```

A `workflow_dispatch` choice has to be a literal list, so the dropdown is generated: run `make options` whenever an entry gains its `build/` and `verify/` folders, and commit the result alongside.

Run `build` before `verify` — verify uses the locally-loaded image (the engine's `pull: missing` finds it, no registry pull) and fetches any step image belonging to another tool. `push` and `publish` need `docker login` to the registry first.

`verify.sh` deploys and starts the real workflow, uploads `verify/input/`, then runs the tool's `verify/check.sh` — which asserts success using the helpers verify provides: `wait_exit` + `expect_output`/`expect_file` for a batch tool that produces files, or `wait_running` + `expect_http`/`expect_port` for a long-running service (desktop, IDE, notebook). The engine it drives has to run with its **working directory set to its volume dir**, since it passes relative volume paths straight to `docker run -v` — which is what `boot.sh` sets up.

## Contributing

Have a tool or workflow others would find useful? Add it as a Markdown entry in the matching domain and open a pull request — community templates are welcome.

## Issues

Spotted a problem with a template or want to request one? Open it in the [community issue tracker](https://github.com/dxflow-ai/community/issues).
