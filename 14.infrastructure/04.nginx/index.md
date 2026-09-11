---
title: Nginx
description: Web server and reverse proxy over the engine volume, reloading itself when its configuration changes
navigation:
    icon: i-diphyx:nginx
---

Nginx is a web server, reverse proxy, and load balancer. This entry runs it over the engine volume: what it serves is the directory `dxflow artifact` and the console's **Artifacts** show, and what configures it is a folder on that same volume — so a configuration change is a file change, and the server picks it up on its own.

That is the difference from running nginx anywhere else. Its configuration is normally something you edit on the host and restart the service for; here it is an artifact. Drop a `.conf` in with `dxflow artifact upload`, or edit it in a browser through [FileGator](/hub/infrastructure/filegator), and within a few seconds the running server has it. A file nginx rejects never reaches the server at all — it is reported in the workflow log and the configuration that was working stays loaded.

The other half of what it is for is the volume itself. A result set that takes a `dxflow artifact download` per file is a directory listing and a `wget -r` away once something is serving it over HTTP, with range requests, so an interrupted transfer resumes and a data loader can read a single file out of a large one. A run that writes an HTML report has somewhere to publish it. And a service that has no link of its own can be given one, by proxying it behind the link this workflow already has.

**Key features:**

- Configuration on the volume, reloaded within seconds of changing — no restart, no redeploy
- A rejected configuration is logged and dropped; the running server keeps serving
- Directory listings over the volume, with range requests and resumable downloads
- Basic auth on by default, and off per location where a share should be open
- Reverse proxy, upstream load balancing, redirects — anything nginx does, by config
- A spare published port for a second site alongside the artifact server

## Usage

### 1. Deploy

```bash
dxflow workflow create --identity web hub://nginx

# Start with defaults, or tune per run with --override
dxflow workflow start web
dxflow workflow start web \
    --override env.app.PASSWORD=my-strong-pass \
    --override env.app.ROOT_DIR=output

# Publish the web port on an HTTPS link
dxflow workflow start web --link
```

### 2. Browse what it serves

Open `http://localhost:8080` and sign in with `USERNAME` and `PASSWORD`. The listing is the engine volume, or the path inside it that `ROOT_DIR` names. From there it is an ordinary web server:

```bash
# Pull one result, resuming if the connection drops
curl -u dxflow:dxflow -C - -O http://localhost:8080/output/trajectory.xtc

# Or mirror a whole run directory
wget -r -np -nH --user=dxflow --password=dxflow http://localhost:8080/output/
```

### 3. Add configuration, without restarting

The first start leaves a `nginx/` folder on the volume with two directories in it and a commented `example.conf.sample` to work from:

| Path                    | Read where                            | Good for                                  |
| ----------------------- | ------------------------------------- | ----------------------------------------- |
| `nginx/conf.d/*.conf`   | at the `http` level                   | whole `server` blocks, `upstream`s, `map`s |
| `nginx/server.d/*.conf` | inside the default server on `:8080`  | extra `location`s, proxy routes, redirects |
| `nginx/nginx.conf`      | instead of the generated file entirely | taking the whole configuration over        |

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
dxflow workflow logs --live web    # "configuration changed" ... "configuration reloaded"
```

If nginx will not accept it, the log says so and quotes the error, and nothing changes:

```
[entrypoint] configuration changed
[entrypoint] configuration rejected — the running one is kept
  nginx: [emerg] unknown directive "proxy_passs" in /volume/nginx/server.d/api.conf:2
```

### 4. Put something behind the link

A service the container can reach — another machine, a port on the engine host, a backend on the LAN — can be served from a path on this workflow's link, so one HTTPS URL covers the lot:

```bash
cat > api.conf <<'EOF'
location /api/ {
    proxy_pass http://10.0.0.7:9000/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_buffering off;
    proxy_read_timeout 3600s;
}
EOF

dxflow artifact upload api.conf nginx/server.d/
```

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
      env:
          - ROOT_DIR=
          - CONFIG_DIR=nginx
          - USERNAME=dxflow
          - PASSWORD=dxflow
          - AUTOINDEX=on
          - CLIENT_MAX_BODY_SIZE=0
          - SERVER_NAME=_
          - RELOAD_INTERVAL=5
          - WORKER_PROCESSES=auto
          - RUN_AS=root
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

[env]
app.ROOT_DIR =
app.CONFIG_DIR = nginx
app.USERNAME = dxflow
app.PASSWORD = dxflow
app.AUTOINDEX = on
app.CLIENT_MAX_BODY_SIZE = 0
app.SERVER_NAME = _
app.RELOAD_INTERVAL = 5
app.WORKER_PROCESSES = auto
app.RUN_AS = root

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

| Variable               | Description                                                            | Default   |
| ---------------------- | ---------------------------------------------------------------------- | --------- |
| `ROOT_DIR`             | Path under `/volume` to serve; empty is the whole volume                | empty     |
| `CONFIG_DIR`           | Path under `/volume` holding the configuration and the watched folders  | `nginx`   |
| `USERNAME`             | Basic auth user for the default server                                  | `dxflow`  |
| `PASSWORD`             | Its password; empty leaves the default server open                      | `dxflow`  |
| `AUTOINDEX`            | `on` lists a directory that has no index file, `off` returns 404         | `on`      |
| `CLIENT_MAX_BODY_SIZE` | Largest request body, in nginx units; `0` is unlimited                  | `0`       |
| `SERVER_NAME`          | `server_name` of the default server                                     | `_`       |
| `RELOAD_INTERVAL`      | Seconds between configuration checks; `0` stops watching                | `5`       |
| `WORKER_PROCESSES`     | `worker_processes` — a number, or `auto` for one per core               | `auto`    |
| `RUN_AS`               | User the workers run as — `root`, or `nginx` for unprivileged           | `root`    |

### Ports

| Port   | Serves                                                                         |
| ------ | ------------------------------------------------------------------------------ |
| `8080` | the default server this entry renders — the one `--link` publishes             |
| `8081` | nothing, until a `server { listen 8081; ... }` in `conf.d/` claims it           |

A published port cannot be added after the fact, only repointed — so the spare is there for the second site that `conf.d/` makes possible.

## Notes

- **The reload is a poll, not an event.** Every `RELOAD_INTERVAL` seconds the digest of every file under `CONFIG_DIR` is compared with the last one; a difference triggers `nginx -t` and, if it passes, `nginx -s reload`. Polling rather than inotify because the volume may be a network mount, where inotify sees nothing. Content is what is digested, so a rewrite within the same second is caught and a `touch` that changes nothing is not.
- **A rejected configuration never reaches disk.** The candidate is tested at a temporary path and only copied over `/etc/nginx/nginx.conf` once nginx accepts it, so what is installed always loads — a restart in the middle of a broken edit still comes up.
- **A broken `nginx.conf` on the volume does not strand the step**: the first start falls back to the rendered configuration and says so in the log, rather than failing to boot with nothing serving.
- **`nginx -s reload` is graceful.** Requests already in flight finish on the old workers; a reload during a multi-gigabyte download does not cut it off.
- **Set a strong `PASSWORD`**; it defaults to `dxflow`, which every reader of this page knows. Emptying it removes the guard entirely — reasonable for a public static site, and a mistake on a volume holding run data. Per-location `auth_basic off;` is the narrower way to open one path.
- **The whole volume is served by default**, `workflow.json` and the other workflows' directories included. Set `ROOT_DIR` to the directory that is meant to be public, and keep `CONFIG_DIR` outside it — the configuration is not something a reader of the site needs to see.
- **`RUN_AS=root` reads what the other steps wrote.** Every other step runs as root, and an output written `0600` is one an unprivileged worker answers with a 403. Set `RUN_AS=nginx` where an unprivileged server matters more, and it will serve only what is world-readable. A configuration supplied as your own `nginx.conf` carries its own `user` directive, and `RUN_AS` no longer applies.
- **`CLIENT_MAX_BODY_SIZE=0` is unlimited**, which matters when nginx is proxying something that takes uploads. It is the request body it governs, not what is served.
- **This serves the volume; it does not manage it.** For uploading, unpacking, and moving files around, [FileGator](/hub/infrastructure/filegator) is the entry over the same directory — and the easiest way to edit these `.conf` files, since it is a browser away from the volume they live on.

## References

- **Documentation**: [nginx docs](https://nginx.org/en/docs/) · [Beginner's guide](https://nginx.org/en/docs/beginners_guide.html)
- **Directives**: [`http` core](https://nginx.org/en/docs/http/ngx_http_core_module.html) · [`proxy_pass`](https://nginx.org/en/docs/http/ngx_http_proxy_module.html) · [`autoindex`](https://nginx.org/en/docs/http/ngx_http_autoindex_module.html) · [`auth_basic`](https://nginx.org/en/docs/http/ngx_http_auth_basic_module.html)
- **Source**: [nginx/nginx](https://github.com/nginx/nginx)
