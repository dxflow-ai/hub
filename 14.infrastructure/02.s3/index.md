---
title: S3 Sync
description: Sync data between S3-compatible object storage and a workflow volume
navigation:
    icon: i-hugeicons:cloud-sync
---

S3 Sync moves a dataset between object storage and a dxflow volume, in either direction: point it at a bucket to pull inputs in before a run, or at a volume to push results out after one. It wraps the AWS CLI v2, so it talks to Amazon S3 and to anything that speaks the same API — MinIO, Ceph RadosGW, Cloudflare R2, Wasabi, Backblaze B2 — by setting an endpoint.

The direction is whichever side carries the `s3://` uri: `SOURCE=s3://…` with a local `TARGET` pulls down, a local `SOURCE` with `TARGET=s3://…` pushes up. It transfers through `./volume` — the engine-volume directory the rest of the hub mounts — so what it fetches is already where Jupyter, GROMACS, or OpenFOAM look for it, and what they leave behind is what it pushes back. It is a single step that runs to completion and exits, so it stands alone as a workflow and drops into a larger one as its first or last step.

**Key features:**

- Sync a bucket prefix down to a volume, or a volume up to a bucket
- Amazon S3 or any S3-compatible endpoint, with path-style addressing
- Anonymous reads of public buckets when no credentials are given
- `copy` mode for a single object, `--delete` for a true mirror
- Credentials passed at start, never stored in the workflow definition

## Usage

### 1. Deploy

```bash
# Deploy the S3 Sync workflow
dxflow workflow create --identity s3-fetch hub://s3
```

### 2. Start (with optional tuning)

The step reads `SOURCE` and `TARGET` (the two ends of the transfer, one of them an `s3://` uri), `MODE` (`sync` for a prefix, `copy` for a single object), `ENDPOINT` and `REGION` (the service to talk to), `ACCESS_KEY`, `SECRET_KEY` and `SESSION_TOKEN` (leave empty for a public bucket), `DELETE` (mirror, removing what the source no longer has), and `EXTRA` (any additional `aws s3` flags from the [Options](#options) tables, e.g. `--exclude`, `--include`, `--storage-class`, `--dryrun`). Set them per run with `--override` — no need to edit the workflow, and no credential is written to the definition:

```bash
# Start with defaults — pulls a small public NOAA dataset into s3/
dxflow workflow start s3-fetch

# Pull a private prefix down to the volume
dxflow workflow start s3-fetch \
    --override env.job.SOURCE=s3://my-bucket/runs/2026-09/ \
    --override env.job.TARGET=/volume \
    --override env.job.REGION=us-west-2 \
    --override env.job.ACCESS_KEY=AKIA... \
    --override env.job.SECRET_KEY=...

# Push results up, skipping the intermediates
dxflow workflow start s3-fetch \
    --override env.job.SOURCE=/volume \
    --override env.job.TARGET=s3://my-bucket/results/ \
    --override env.job.ACCESS_KEY=AKIA... \
    --override env.job.SECRET_KEY=... \
    --override 'env.job.EXTRA=--exclude=*.tmp'

# Talk to a MinIO (or Ceph, R2, Wasabi) endpoint instead of AWS
dxflow workflow start s3-fetch \
    --override env.job.ENDPOINT=http://minio.internal:9000 \
    --override env.job.SOURCE=s3://datasets/reference/ \
    --override env.job.TARGET=/volume \
    --override env.job.ACCESS_KEY=minioadmin \
    --override env.job.SECRET_KEY=minioadmin
```

### 3. Monitor

```bash
# View logs — the CLI reports each object as it transfers
dxflow workflow logs s3-fetch

# Check status
dxflow workflow list
```

### 4. Use what it fetched

```bash
# List what landed in the volume
dxflow artifact list s3/

# Or download it to your machine
dxflow artifact download s3/ /local/dataset/
```

## Configuration

```yaml
name: s3
tags:
    - infrastructure
steps:
    - name: job
      runtime: docker
      mode: sequential
      image: ghcr.io/dxflow-ai/s3:latest
      command:
          - /opt/dxflow/entrypoint.sh
      volumes:
          - name: volume
            host: ./volume
            container: /volume
      env:
          - SOURCE=s3://noaa-gsod-pds/1929/
          - TARGET=/volume/s3
          - MODE=sync
          - ENDPOINT=
          - REGION=us-east-1
          - ACCESS_KEY=
          - SECRET_KEY=
          - SESSION_TOKEN=
          - DELETE=false
          - EXTRA=
      resources:
          cpu: "2"
          memory: 2G
```

```ini
[volume]
job.volume = ./volume

[env]
job.SOURCE = s3://noaa-gsod-pds/1929/
job.TARGET = /volume/s3
job.MODE = sync
job.ENDPOINT =
job.REGION = us-east-1
job.ACCESS_KEY =
job.SECRET_KEY =
job.SESSION_TOKEN =
job.DELETE = false
job.EXTRA =

[resource]
job.cpu = 2
job.memory = 2G
```

```json
{
    "arch": ["amd64", "arm64"],
    "image": "ghcr.io/dxflow-ai/s3:latest",
    "version": "2.36.41",
    "minimum": {
        "cpu": 1,
        "memory": "1G",
        "storage": "10G"
    }
}
```

The defaults point at [`s3://noaa-gsod-pds/1929/`](https://registry.opendata.aws/noaa-gsod/) — 21 small csv files in a public AWS Open Data bucket — so a fresh deploy transfers something real without a credential. They land in `/volume/s3` rather than the root of the volume, to keep a first run out of the way of what is already there — `s3/` in Artifacts. Override `SOURCE` and `TARGET` for your own bucket.

## Use as a pipeline step

`mode: sequential` is what orders a pipeline — each sequential step gets a phase of its own, and the next phase starts only once it has exited. The engine asks one thing of such a step: it must carry a `command`, because it starts the container detached and runs the command inside it. So the container comes up idle and the transfer is the `command` — `/opt/dxflow/entrypoint.sh`, the image's own entrypoint, invoked a second time inside the running step. The step block above drops into a larger workflow unchanged.

Share one host directory across the steps and the transfer feeds whatever runs next. Give the run a directory of its own under the volume — `run/` in **Artifacts** — so the push at the end sends the run back and nothing else:

```yaml
name: pipeline
tags:
    - infrastructure
steps:
    - name: fetch
      runtime: docker
      mode: sequential
      image: ghcr.io/dxflow-ai/s3:latest
      command:
          - /opt/dxflow/entrypoint.sh
      volumes:
          - name: volume
            host: ./volume/run
            container: /volume
      env:
          - SOURCE=s3://my-bucket/inputs/
          - TARGET=/volume
          - ACCESS_KEY=
          - SECRET_KEY=
    - name: simulate
      runtime: docker
      mode: sequential
      image: ghcr.io/dxflow-ai/gromacs:latest
      command:
          - gmx_mpi
          - mdrun
          - -v
          - -deffnm
          - md
      volumes:
          - name: volume
            host: ./volume/run
            container: /volume
      resources:
          cpu: "8"
          memory: 32G
    - name: push
      runtime: docker
      mode: sequential
      image: ghcr.io/dxflow-ai/s3:latest
      command:
          - /opt/dxflow/entrypoint.sh
      volumes:
          - name: volume
            host: ./volume/run
            container: /volume
      env:
          - SOURCE=/volume
          - TARGET=s3://my-bucket/results/
          - ACCESS_KEY=
          - SECRET_KEY=
          - EXTRA=--exclude=*.log
```

Fill the credentials in at start with `--override env.fetch.ACCESS_KEY=…` and `--override env.push.ACCESS_KEY=…`, so the definition stays free of secrets. To keep the two ends apart, override the host side instead — `--override volume.fetch.volume=./volume/inputs` — and the same step writes somewhere else entirely.

A step that cannot take a command has to stay `parallel`, and a `parallel` step does not open a phase of its own: it starts alongside whatever shares its phase. Sequential steps are what a fetch → compute → push order is built from.

## Options

### Step environment

| Variable        | Description                                                        | Default                    |
| --------------- | ------------------------------------------------------------------ | -------------------------- |
| `SOURCE`        | Where the data comes from — an `s3://` uri or a path in the volume | `s3://noaa-gsod-pds/1929/` |
| `TARGET`        | Where it goes — an `s3://` uri or a path in the volume             | `/volume/s3`               |
| `MODE`          | `sync` for a prefix, `copy` for a single object                    | `sync`                     |
| `ENDPOINT`      | S3-compatible endpoint url; empty talks to AWS                     | empty                      |
| `REGION`        | Bucket region                                                      | `us-east-1`                |
| `ACCESS_KEY`    | Access key id; empty reads the bucket anonymously                  | empty                      |
| `SECRET_KEY`    | Secret access key                                                  | empty                      |
| `SESSION_TOKEN` | Session token, for temporary (STS) credentials                     | empty                      |
| `DELETE`        | Delete what the source no longer has (`sync` only)                 | `false`                    |
| `EXTRA`         | Additional `aws s3` flags                                          | empty                      |

### Useful `EXTRA` flags

| Flag                     | Description                                                  |
| ------------------------ | ------------------------------------------------------------ |
| `--exclude=<pattern>`    | Skip matching keys (repeatable)                              |
| `--include=<pattern>`    | Re-add matching keys after an `--exclude`                    |
| `--dryrun`               | Report the transfer without performing it                    |
| `--size-only`            | Compare size alone, ignoring modification time               |
| `--exact-timestamps`     | Require timestamps to match exactly on a download            |
| `--storage-class=<name>` | Upload to `STANDARD_IA`, `GLACIER_IR`, …                     |
| `--acl=<name>`           | Set a canned acl on upload, e.g. `bucket-owner-full-control` |
| `--sse=<algorithm>`      | Server-side encryption, e.g. `AES256` or `aws:kms`           |
| `--only-show-errors`     | Quieten the per-object log lines                             |

## Notes

- **Direction** is inferred from the uris, not configured: one of `SOURCE`/`TARGET` carries `s3://` and the other is a path in the volume. Two `s3://` uris transfer bucket to bucket (or between two services, if both sit behind one `ENDPOINT`); two local paths are rejected — `aws s3` has no local-to-local transfer.
- **What `sync` transfers**: an object whose size or modification time differs from the destination. It never deletes on its own — set `DELETE=true` for a mirror. `MODE=copy` always transfers, and takes a single object unless `SOURCE` ends in `/`.
- **Public buckets** need no credential; with `ACCESS_KEY` and `SECRET_KEY` both empty the request goes out unsigned (`--no-sign-request`). Setting one without the other is an error, not an unsigned read.
- **Compatible services** are addressed by path automatically once `ENDPOINT` is set, since a MinIO or Ceph host does not answer to `<bucket>.<host>`. Most also ignore the region, so the `us-east-1` default is fine.
- **`EXTRA` is split on whitespace and never expanded by a shell**, so write patterns as `--exclude=*.bam` — one word, unquoted. A pattern with a space in it will not survive.
- **The volume** is the engine's own: `./volume` is the root of **Artifacts**, and the directory every other hub entry mounts, so a fetch lands where the next workflow already reads. `/volume/s3` inside the container is `s3/` in Artifacts; set `TARGET=/volume/input` to drop it straight into another workflow's path. Send a run somewhere else with `--override volume.job.volume=./volume/inputs` — that moves the host side and leaves `/volume` inside the container as it is.
- **The step mounts the whole volume**, which is what lets a fetch land in another workflow's directory — but it also means `SOURCE=/volume` on an upload pushes every workflow's folder, `workflow.json` and logs to the bucket. Point `SOURCE` at a directory inside it.
- **Credentials** belong on `dxflow workflow start --override`, not in the definition — the hub entry is public, and an override is scoped to the run.
- **Throughput** scales with the CPU it gets: the CLI transfers 10 objects at a time by default. Raise `resources.cpu` and `resources.memory` for large datasets, and the volume's `storage` to fit what lands.

## References

- **Documentation**: [`aws s3 sync`](https://docs.aws.amazon.com/cli/latest/reference/s3/sync.html) · [`aws s3 cp`](https://docs.aws.amazon.com/cli/latest/reference/s3/cp.html)
- **Filters**: [Use of exclude and include filters](https://docs.aws.amazon.com/cli/latest/reference/s3/#use-of-exclude-and-include-filters)
- **Public datasets**: [Registry of Open Data on AWS](https://registry.opendata.aws/)
- **Compatible services**: [MinIO](https://min.io/docs/minio/linux/index.html) · [Ceph RadosGW](https://docs.ceph.com/en/latest/radosgw/s3/) · [Cloudflare R2](https://developers.cloudflare.com/r2/api/s3/api/)
