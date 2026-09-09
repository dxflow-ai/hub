---
title: S3 Sync
description: Sync data between S3-compatible object storage and a workflow volume
navigation:
    icon: i-hugeicons:cloud-sync
---

S3 Sync moves a dataset between object storage and a dxflow volume, in either direction: point it at a bucket to pull inputs in before a run, or at a volume to push results out after one. It wraps the AWS CLI v2, so it talks to Amazon S3 and to anything that speaks the same API — MinIO, Ceph RadosGW, Cloudflare R2, Wasabi, Backblaze B2 — by setting an endpoint.

The direction is whichever side carries the `s3://` uri: `SOURCE=s3://…` with a local `TARGET` pulls down, a local `SOURCE` with `TARGET=s3://…` pushes up. It is a single step that runs to completion and exits, so it stands alone as a workflow and drops into a larger one as its first or last step.

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
# Start with defaults — pulls a small public NOAA dataset into ./data
dxflow workflow start s3-fetch

# Pull a private prefix down to the volume
dxflow workflow start s3-fetch \
    --override env.job.SOURCE=s3://my-bucket/runs/2026-09/ \
    --override env.job.TARGET=/data \
    --override env.job.REGION=us-west-2 \
    --override env.job.ACCESS_KEY=AKIA... \
    --override env.job.SECRET_KEY=...

# Push results up, skipping the intermediates
dxflow workflow start s3-fetch \
    --override env.job.SOURCE=/data \
    --override env.job.TARGET=s3://my-bucket/results/ \
    --override env.job.ACCESS_KEY=AKIA... \
    --override env.job.SECRET_KEY=... \
    --override 'env.job.EXTRA=--exclude=*.tmp'

# Talk to a MinIO (or Ceph, R2, Wasabi) endpoint instead of AWS
dxflow workflow start s3-fetch \
    --override env.job.ENDPOINT=http://minio.internal:9000 \
    --override env.job.SOURCE=s3://datasets/reference/ \
    --override env.job.TARGET=/data \
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
dxflow artifact list data/

# Or download it to your machine
dxflow artifact download data/ /local/dataset/
```

## Configuration

```yaml
name: s3
tags:
    - infrastructure
steps:
    - name: job
      runtime: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/s3:latest
      volumes:
          - name: data
            host: ./data
            container: /data
      env:
          - SOURCE=s3://noaa-gsod-pds/1929/
          - TARGET=/data
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
job.data = ./data

[env]
job.SOURCE = s3://noaa-gsod-pds/1929/
job.TARGET = /data
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

The defaults point at [`s3://noaa-gsod-pds/1929/`](https://registry.opendata.aws/noaa-gsod/) — 21 small csv files in a public AWS Open Data bucket — so a fresh deploy transfers something real without a credential. Override `SOURCE` and `TARGET` for your own bucket.

## Use as a pipeline step

The step exits when the transfer finishes, which is what a `sequential` step needs: give it the entrypoint as its `command` and it runs to completion before the next step starts. Fetch inputs, compute, push results back — all three sharing one volume:

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
          - name: data
            host: ./data
            container: /data
      env:
          - SOURCE=s3://my-bucket/input/
          - TARGET=/data/input
          - ACCESS_KEY=
          - SECRET_KEY=
    - name: analyze
      runtime: docker
      mode: sequential
      image: ghcr.io/dxflow-ai/fastqc:latest
      volumes:
          - name: data
            host: ./data
            container: /data
      env:
          - INPUT=/data/input/*.fastq.gz
          - THREADS=4
          - EXTRA=
    - name: push
      runtime: docker
      mode: sequential
      image: ghcr.io/dxflow-ai/s3:latest
      command:
          - /opt/dxflow/entrypoint.sh
      volumes:
          - name: data
            host: ./data
            container: /data
      env:
          - SOURCE=/data/output
          - TARGET=s3://my-bucket/results/
          - ACCESS_KEY=
          - SECRET_KEY=
```

Fill the credentials in at start with `--override env.fetch.ACCESS_KEY=…` and `--override env.push.ACCESS_KEY=…`, so the definition stays free of secrets.

## Options

### Step environment

| Variable        | Description                                                        | Default                    |
| --------------- | ------------------------------------------------------------------ | -------------------------- |
| `SOURCE`        | Where the data comes from — an `s3://` uri or a path in the volume | `s3://noaa-gsod-pds/1929/` |
| `TARGET`        | Where it goes — an `s3://` uri or a path in the volume             | `/data`                    |
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
- **Credentials** belong on `dxflow workflow start --override`, not in the definition — the hub entry is public, and an override is scoped to the run.
- **Throughput** scales with the CPU it gets: the CLI transfers 10 objects at a time by default. Raise `resources.cpu` and `resources.memory` for large datasets, and the volume's `storage` to fit what lands.

## References

- **Documentation**: [`aws s3 sync`](https://docs.aws.amazon.com/cli/latest/reference/s3/sync.html) · [`aws s3 cp`](https://docs.aws.amazon.com/cli/latest/reference/s3/cp.html)
- **Filters**: [Use of exclude and include filters](https://docs.aws.amazon.com/cli/latest/reference/s3/#use-of-exclude-and-include-filters)
- **Public datasets**: [Registry of Open Data on AWS](https://registry.opendata.aws/)
- **Compatible services**: [MinIO](https://min.io/docs/minio/linux/index.html) · [Ceph RadosGW](https://docs.ceph.com/en/latest/radosgw/s3/) · [Cloudflare R2](https://developers.cloudflare.com/r2/api/s3/api/)
