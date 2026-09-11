---
title: Nginx
description: Publish workflow artifacts as web resources, and edit the nginx configuration live
navigation:
    icon: i-diphyx:nginx
---

Nginx here does two jobs, and both come from the same fact: it is pointed at the engine volume, so what it serves and what configures it are artifacts.

**It turns what other workflows produce into web resources.** A run writes its outputs to `./volume` and they stay there — reachable through `dxflow artifact download`, a command at a time, by whoever has the CLI. Point this at the same directory and each of those files has a URL. A report opens in a browser, a `.csv` is fetched by a notebook, a trajectory streams in byte ranges instead of arriving whole, and a colleague with a link needs no dxflow account to read any of it.

**It is a live nginx configuration session.** The config is not baked into the image or edited on a host you would have to shell into: `conf.d/` and `server.d/` sit on the volume, and the step watches them. Write a `location`, and a few seconds later it is serving. Write a broken one and the running server carries on — `nginx -t` is run against every candidate first, and the result lands in `state/status.log` next to the file you just edited. `state/effective.conf` holds the configuration as nginx actually resolved it, so "what is loaded right now" is a file rather than a guess.

**Key features:**

- Every artifact gets a URL — directory listings, byte ranges, resumable downloads
- Text output a run leaves behind opens in the browser instead of downloading
- `CORS=on` lets a notebook or dashboard fetch a result set cross-origin
- Configuration on the volume, reloaded within seconds — no restart, no redeploy
- A rejected configuration is reported and dropped; the running server keeps serving
- `state/status.log` and `state/effective.conf` report back where the editing happens
- Two spare published ports, for the server blocks a session goes on to write

## Usage

### 1. Deploy

```bash
dxflow workflow create --identity web hub://nginx

# Serve everything, or just the directory a run wrote
dxflow workflow start web
dxflow workflow start web --override env.app.SITE_DIR=output

# Publish it on an HTTPS link
dxflow workflow start web --link
```

### 2. Read the artifacts

Open `http://localhost:8080` and sign in as `dxflow` with `PASSWORD`. The listing is the volume, or the path `SITE_DIR` names. From there it is an ordinary web server, which is the point:

```bash
# One result, resuming if the connection drops
curl -u dxflow:dxflow -C - -O http://localhost:8080/output/trajectory.xtc

# A whole run directory
wget -r -np -nH --user=dxflow --password=dxflow http://localhost:8080/output/

# The first megabyte of a large file, without fetching the rest
curl -u dxflow:dxflow -r 0-1048575 http://localhost:8080/output/frames.h5 -o head.bin
```

A run's `.log`, `.csv`, `.yaml`, or solver input opens in the browser rather than downloading — the stock MIME table has no entry for those, and this entry gives them one. To let a page served from somewhere else read them, start with `CORS=on`:

```bash
dxflow workflow start web \
    --override env.app.SITE_DIR=output \
    --override env.app.CORS=on \
    --override env.app.PASSWORD= \
    --link
```

```js
// ... and from a notebook or a dashboard on another origin
const rows = await fetch("https://<link>/metrics.csv").then((r) => r.text())
```

### 3. Configure it, while it runs

The first start leaves a `nginx/` folder on the volume:

| Path                        | What it is                                                            |
| --------------------------- | --------------------------------------------------------------------- |
| `nginx/conf.d/*.conf`       | read at the `http` level — whole `server` blocks, `upstream`s, `map`s |
| `nginx/server.d/*.conf`     | read inside the site server on `:8080` — `location`s, routes          |
| `nginx/nginx.conf`          | read instead of the generated file entirely, if you put one there     |
| `nginx/example.conf.sample` | worked examples to copy from; never read by nginx                     |
| `nginx/state/status.log`    | one line per check: reloaded, or rejected and why                      |
| `nginx/state/effective.conf` | the configuration as nginx resolved it, every include expanded        |

Write one and upload it — the server has it a few seconds later:

```bash
cat > report.conf <<'EOF'
location /report/ {
    auth_basic off;
    alias /volume/runs/latest/report/;
    index index.html;
}
EOF

dxflow artifact upload report.conf nginx/server.d/
dxflow artifact download nginx/state/status.log -    # 2026-09-11T20:45:03Z  reloaded
```

If nginx will not accept it, nothing changes and both the log and `status.log` say why:

```
2026-09-11T20:46:12Z  rejected: nginx: [emerg] unknown directive "proxy_passs" in /volume/nginx/server.d/api.conf:2
```

Run [FileGator](/hub/infrastructure/filegator) over the same volume and the whole loop is a browser: edit the `.conf` in one tab, watch `state/status.log` in the same file listing, reload the site in another.

## Configuration

```yaml
name: nginx
tags:
    - infrastructure
steps:
    - name: app
      runtime: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/nginx:latest
      volumes:
          - name: volume
            host: ./volume
            container: /volume
      ports:
          - name: web
            host: "8080"
            container: "8080"
          - name: alt
            host: "8081"
            container: "8081"
          - name: spare
            host: "8082"
            container: "8082"
      env:
          - SITE_DIR=
          - CONFIG_DIR=nginx
          - PASSWORD=dxflow
          - AUTOINDEX=on
          - CORS=off
          - GZIP=on
          - WORKER_PROCESSES=auto
          - WORKER_USER=nginx
          - RELOAD_INTERVAL=5
      resources:
          cpu: "2"
          memory: 1G
      link: web
```

```ini
[volume]
app.volume = ./volume

[port]
app.web = 8080
app.alt = 8081
app.spare = 8082

[env]
app.SITE_DIR =
app.CONFIG_DIR = nginx
app.PASSWORD = dxflow
app.AUTOINDEX = on
app.CORS = off
app.GZIP = on
app.WORKER_PROCESSES = auto
app.WORKER_USER = nginx
app.RELOAD_INTERVAL = 5

[resource]
app.cpu = 2
app.memory = 1G
```

```json
{
    "arch": ["amd64", "arm64"],
    "image": "ghcr.io/dxflow-ai/nginx:latest",
    "version": "1.30.4",
    "minimum": {
        "cpu": 1,
        "memory": "1G",
        "storage": "10G"
    }
}
```

## Options

### Step environment

| Variable           | Description                                                              | Default |
| ------------------ | ------------------------------------------------------------------------ | ------- |
| `SITE_DIR`         | Path under `/volume` to publish; empty is the whole volume               | empty   |
| `CONFIG_DIR`       | Path under `/volume` holding the configuration and its state             | `nginx` |
| `PASSWORD`         | Password for user `dxflow`; empty leaves the site open                   | `dxflow` |
| `AUTOINDEX`        | `on` lists a directory that has no index file, `off` returns 404          | `on`    |
| `CORS`             | `on` allows cross-origin reads, range headers included                   | `off`   |
| `GZIP`             | Compress text responses — logs, csv, json, xml                           | `on`    |
| `WORKER_PROCESSES` | A number, or `auto` for one per cpu the step was actually given          | `auto`  |
| `WORKER_USER`      | User the workers read as — `nginx`, or `root` for artifacts only it can read | `nginx` |
| `RELOAD_INTERVAL`  | Seconds between configuration checks; `0` stops watching                 | `5`     |

Everything else is a directive, not a variable: `client_max_body_size`, `expires`, `limit_req`, a `server_name` for name-based hosting, TLS — write them into `conf.d/` or `server.d/` and they take effect on the next check. The environment covers only what the artifact site needs before any configuration exists.

### Ports

| Port   | Serves                                                                   |
| ------ | ------------------------------------------------------------------------ |
| `8080` | the artifact site this entry renders — the port `--link` publishes       |
| `8081` | nothing, until a `server { listen 8081; ... }` in `conf.d/` claims it     |
| `8082` | the same, for the next one                                               |

A published port cannot be added to a running workflow, only repointed — so the spares are there for the server blocks a configuration session goes on to write.

## Notes

- **The reload is a poll, not an event.** Every `RELOAD_INTERVAL` seconds the digest of `conf.d/`, `server.d/`, and `nginx.conf` is compared with the last one. Polling rather than inotify, because the volume may be a network mount where inotify sees nothing; content rather than timestamps, so a rewrite inside one second counts and a `touch` that changes nothing does not. `state/` is outside the watch, so reporting a reload cannot cause the next one.
- **A rejected configuration never reaches disk.** The candidate is tested at a temporary path and copied over `/etc/nginx/nginx.conf` only once `nginx -t` accepts it, so what is installed always loads — a restart in the middle of a broken edit still comes up. A broken `nginx.conf` of your own on the volume falls back to the rendered default and says so, rather than leaving the step dead.
- **`nginx -s reload` is graceful.** Requests already in flight finish on the old workers, so a reload during a multi-gigabyte download does not cut it off.
- **`WORKER_PROCESSES=auto` counts the cpu the step was given**, read from the cgroup — not the host's core count, which is what nginx's own `auto` would find and which would put 64 workers on a two-core limit.
- **`WORKER_USER=nginx` is enough to read what other steps wrote**, since a step's outputs land world-readable under a normal umask. An artifact written `0600` is the exception, and `WORKER_USER=root` is the answer to it. A configuration supplied as your own `nginx.conf` carries its own `user` directive and this no longer applies.
- **`CORS=on` and `PASSWORD` do not mix.** `Access-Control-Allow-Origin: *` is refused by browsers for a credentialed request, so a cross-origin `fetch` of a password-guarded path fails whatever the header says. Either leave `PASSWORD` empty for a public dataset, or put `auth_basic off;` on the one location being fetched.
- **Set a strong `PASSWORD`** when the site is not meant to be public; it defaults to `dxflow`, which every reader of this page knows.
- **The whole volume is published by default**, `workflow.json` and the other workflows' directories included. Set `SITE_DIR` to the directory that is meant to be read, and keep `CONFIG_DIR` outside it — the configuration is not something a reader of the site needs to see.
- **Nothing here writes to the volume except `state/`.** nginx serves; it does not accept uploads unless a configuration you add tells it to. To put files on the volume in the first place, [FileGator](/hub/infrastructure/filegator) is the entry over the same directory, and [S3 Sync](/hub/infrastructure/s3) is the step for a bucket.

## References

- **Documentation**: [nginx docs](https://nginx.org/en/docs/) · [Beginner's guide](https://nginx.org/en/docs/beginners_guide.html)
- **Directives**: [`http` core](https://nginx.org/en/docs/http/ngx_http_core_module.html) · [`autoindex`](https://nginx.org/en/docs/http/ngx_http_autoindex_module.html) · [`auth_basic`](https://nginx.org/en/docs/http/ngx_http_auth_basic_module.html) · [`gzip`](https://nginx.org/en/docs/http/ngx_http_gzip_module.html) · [`proxy_pass`](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)
- **Source**: [nginx/nginx](https://github.com/nginx/nginx)
