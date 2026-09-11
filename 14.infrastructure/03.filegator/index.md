---
title: FileGator
description: Web file manager for the engine volume — upload, unpack, edit, and share artifacts from a browser
navigation:
    icon: i-diphyx:filegator
---

FileGator is a multi-user web file manager, served straight to the browser — no desktop or VNC. This entry points it at the engine volume, so the directory it browses is the same one `dxflow artifact` and the console's **Artifacts** show, and the same one every other hub workflow mounts as `/volume`.

That is what it is for here. A run's inputs and outputs otherwise move through the CLI one command at a time: a dataset arrives as a single `dxflow artifact upload`, a result leaves as a `download`, and unpacking a 40 GB archive means pulling it to a laptop and pushing it back. FileGator does that work where the data already is — it uploads in resumable chunks, unzips on the engine, moves a finished run into the next workflow's input directory, and edits the parameter file in place on the way. Started with `--link`, all of it works from anywhere, for someone who has no dxflow account at all.

**Key features:**

- Chunked, resumable uploads — a dropped connection continues instead of restarting
- Zip and unzip server-side: unpack a reference dataset without it crossing the network twice
- Copy, move, and rename across workflow directories — stage one run's output as the next run's input
- Edit run configuration in place — a solver dictionary, a parameter file, a job script
- Batch download a directory as one archive, or stream a single large file
- Accounts with a home directory and permissions of their own, added from the admin UI
- An optional anonymous guest — a read-only share, or a write-only drop box, on one link

## Usage

### 1. Deploy

```bash
dxflow workflow create --identity files hub://filegator

# Start with defaults, or tune per run with --override
dxflow workflow start files
dxflow workflow start files \
    --override env.app.PASSWORD=my-strong-pass \
    --override env.app.ROOT_DIR=projects

# Publish the web port on an HTTPS link
dxflow workflow start files --link
```

### 2. Sign in

Open `http://localhost:8080` and sign in as `admin` with the password you set in `PASSWORD`. The listing opens on the engine volume — the workflow directories, the run outputs, everything **Artifacts** shows. A start given `--link` publishes port `8080` at an HTTPS URL printed on the start line, which reaches the same listing from anywhere.

### 3. Move data

Drag a file onto the listing to upload it, in chunks the transfer resumes from. Select a `.zip` and **Unzip** it where it sits. Select a directory and **Download** it as one archive. Copy a finished run into the directory the next workflow reads, and start that workflow — nothing leaves the engine.

### 4. Share it

Add an account per collaborator from **Users** in the admin menu, each with a home directory of its own (`/input`, `/projects/alice`) and only the permissions it needs. For a link that needs no account at all, start with `GUEST_PERMISSIONS` set:

```bash
# A read-only share of one directory
dxflow workflow start files \
    --override env.app.ROOT_DIR=output \
    --override env.app.GUEST_PERMISSIONS='read|download|batchdownload' \
    --link

# A drop box — uploads without read, so nothing already there is listed
dxflow workflow start files \
    --override env.app.ROOT_DIR=input \
    --override env.app.GUEST_PERMISSIONS=upload \
    --link
```

## Configuration

```yaml
name: filegator
tags:
    - infrastructure
steps:
    - name: app
      runtime: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/filegator:latest
      volumes:
          - name: volume
            host: ./volume
            container: /volume
          - name: private
            host: ./volume/.filegator
            container: /data
      ports:
          - name: web
            host: "8080"
            container: "8080"
      env:
          - USERNAME=admin
          - PASSWORD=dxflow
          - ROOT_DIR=
          - GUEST_PERMISSIONS=
          - UPLOAD_MAX_SIZE=10240
          - UPLOAD_CHUNK_SIZE=8
          - OVERWRITE_ON_UPLOAD=false
          - APP_NAME=dxflow Artifacts
          - TIMEZONE=UTC
          - RUN_AS=root
      resources:
          cpu: "2"
          memory: 2G
      link: web
```

```ini
[volume]
app.volume = ./volume
app.private = ./volume/.filegator

[port]
app.web = 8080

[env]
app.USERNAME = admin
app.PASSWORD = dxflow
app.ROOT_DIR =
app.GUEST_PERMISSIONS =
app.UPLOAD_MAX_SIZE = 10240
app.UPLOAD_CHUNK_SIZE = 8
app.OVERWRITE_ON_UPLOAD = false
app.APP_NAME = dxflow Artifacts
app.TIMEZONE = UTC
app.RUN_AS = root

[resource]
app.cpu = 2
app.memory = 2G
```

```json
{
    "arch": ["amd64", "arm64"],
    "image": "ghcr.io/dxflow-ai/filegator:latest",
    "version": "7.16.2",
    "minimum": {
        "cpu": 1,
        "memory": "2G",
        "storage": "50G"
    }
}
```

## Options

### Step environment

| Variable              | Description                                                            | Default            |
| --------------------- | ---------------------------------------------------------------------- | ------------------ |
| `USERNAME`            | The administrator's sign-in name                                       | `admin`            |
| `PASSWORD`            | The administrator's password                                           | `dxflow`           |
| `ROOT_DIR`            | Path under `/volume` to browse; empty is the whole volume              | empty              |
| `GUEST_PERMISSIONS`   | Permissions for anonymous visitors; empty requires a sign-in           | empty              |
| `UPLOAD_MAX_SIZE`     | Largest single upload, in MB                                           | `10240` (10 GB)    |
| `UPLOAD_CHUNK_SIZE`   | Size of one upload chunk, in MB                                        | `8`                |
| `OVERWRITE_ON_UPLOAD` | Replace a file of the same name instead of adding a numbered copy      | `false`            |
| `APP_NAME`            | Title shown in the browser                                             | `dxflow Artifacts` |
| `TIMEZONE`            | Timezone the listed timestamps are rendered in                         | `UTC`              |
| `RUN_AS`              | User nginx and php-fpm run as — `root`, or `www-data` for unprivileged | `root`             |

### Permissions

`GUEST_PERMISSIONS`, and the permissions of an account added from the admin UI, are chosen from these and joined with `|`:

| Permission      | Grants                                          |
| --------------- | ----------------------------------------------- |
| `read`          | List directories and open files                 |
| `write`         | Create, rename, move, copy, and delete          |
| `upload`        | Add files                                       |
| `download`      | Retrieve a single file                          |
| `batchdownload` | Retrieve a selection as one archive             |
| `zip`           | Zip a selection, and unzip an archive in place  |
| `chmod`         | Change the mode of a file or directory          |

## Use with another workflow

The volume is shared, so nothing needs wiring: `./volume/input` is `/volume/input` here and `input/` in **Artifacts**, and it is the directory another entry mounts under whatever name it likes. Run FileGator alongside a long job and the outputs appear in the listing as they are written.

Where the two should not see the same thing, `ROOT_DIR` narrows this one:

```bash
# The collaborators' entry point: only the input directory, and only uploads
dxflow workflow create --identity dropbox hub://filegator
dxflow workflow start dropbox \
    --override env.app.ROOT_DIR=input \
    --override env.app.GUEST_PERMISSIONS=upload \
    --override port.app.web=8081 \
    --link
```

Two FileGator workflows can run at once on different ports — one narrowed and shared, one on the whole volume for yourself.

## Notes

- **Set a strong `PASSWORD`**; it defaults to `dxflow`, which every reader of this page knows. Set it before the first start rather than after: a start with the default publishes a writable file manager over the whole volume.
- **`GUEST_PERMISSIONS` is anonymous access** — whatever it holds is granted to anyone who reaches the port, with no sign-in. Empty is the default for that reason. Listing a directory takes `read` and adding a file takes `upload`, and the two are granted apart: `read|download` is a share, `upload` on its own is a drop box that lists nothing back.
- **The whole volume is browsable by default**, including `workflow.json` and the other workflows' directories — the same reach that lets a run be staged for the next workflow lets it be deleted. Set `ROOT_DIR` to the directory that run belongs in, and hand collaborators an account with a home directory rather than the root.
- **Accounts are reconciled from the environment on every start**: the administrator's name and password, and the guest's permissions, come from the step's env. Every other account is left as it is, so one added from the admin UI survives a restart.
- **Private state lives on the volume** — accounts, sessions, logs, and upload chunks, under `.filegator/` — so a restart keeps them. It is hidden from the listing, and mounted as a volume of its own, so `--override volume.app.private=./volume/state` moves it.
- **`RUN_AS=root` is what makes it useful on a shared volume.** Every other step runs as root and leaves root-owned files behind; nginx and php-fpm running as `www-data` could list them and not rename or delete one. Set `RUN_AS=www-data` where an unprivileged server matters more than that reach, and it will only manage what it created.
- **Uploads arrive in chunks**, so `UPLOAD_MAX_SIZE` is the only ceiling that matters — PHP's per-request limits are sized from `UPLOAD_CHUNK_SIZE` at start. Raise the chunk on a fast link, lower it on a flaky one; a resumed transfer restarts at the last whole chunk.
- **Zip and unzip run on the engine**, reading and writing under the volume, so an archive needs room for both itself and its contents. Size the volume's `storage` for the largest dataset that will be unpacked, not for the largest file.
- **This is not a transfer tool for a bucket** — for moving a dataset between object storage and the volume without a browser in the loop, [S3 Sync](/hub/infrastructure/s3) is the step that belongs in a pipeline.

## References

- **Documentation**: [FileGator docs](https://docs.filegator.io/)
- **Configuration**: [Basic settings](https://docs.filegator.io/configuration/basic.html) · [Auth adapters](https://docs.filegator.io/configuration/auth.html) · [Security](https://docs.filegator.io/configuration/security.html)
- **Source**: [filegator/filegator](https://github.com/filegator/filegator)
