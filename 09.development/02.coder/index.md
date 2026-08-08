---
title: Coder
description: Self-hosted cloud development environments
navigation:
    icon: i-diphyx:coder
---

Coder runs [code-server](https://github.com/coder/code-server) — Visual Studio Code served straight to the browser, backed by remote compute. No desktop or VNC: the editor is the web page, reached over a single HTTP port.

## Usage

### 1. Deploy

```bash
dxflow workflow create --identity coder hub://coder

# Start with defaults, or tune per run with --override
dxflow workflow start coder
dxflow workflow start coder \
    --override env.app.PASSWORD=my-strong-pass \
    --override env.app.WORKING_DIR=projects/my-app

# Publish the web port on an HTTPS link
dxflow workflow start coder --link
```

### 2. Open the editor

Open your browser at `http://localhost:8080` and sign in with the password you set in `PASSWORD`. code-server opens on the working directory. A start given `--link` publishes port `8080` at an HTTPS URL printed on the start line, opening code-server from anywhere.

### 3. Persist data

The editor opens under `/volume`, so your code, settings, and extensions survive restarts — mount a local directory there to keep your work.

## Configuration

```yaml
name: coder
tags:
    - development
steps:
    - name: app
      runtime: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/coder:latest
      volumes:
          - name: volume
            host: ./volume
            container: /volume
      ports:
          - name: web
            host: "8080"
            container: "8080"
      env:
          - PASSWORD=dxflow
          - WORKING_DIR=/
      resources:
          cpu: "2"
          memory: 4G
      link: web
```

```ini
[volume]
app.volume = ./volume

[port]
app.web = 8080

[env]
app.PASSWORD = dxflow
app.WORKING_DIR = /

[resource]
app.cpu = 2
app.memory = 4G
```

```json
{
    "arch": ["amd64", "arm64"],
    "image": "ghcr.io/dxflow-ai/coder:latest",
    "version": "4.96",
    "minimum": {
        "cpu": 2,
        "memory": "2G",
        "storage": "20G"
    }
}
```

## Notes

- `WORKING_DIR` is resolved under `/volume` (default `/` opens `/volume`). Set it to a subpath like `projects/my-app` to open straight into a project.
- Set a strong `PASSWORD`; it defaults to `dxflow`, which every reader of this page knows. code-server asks for it on a sign-in page, so the password is the only way in.
- The shell is `zsh`, and `python3` and `git` are preinstalled for use from the integrated terminal.
