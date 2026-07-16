---
title: Coder
description: Self-hosted cloud development environments
navigation:
    icon: i-diphyx:coder
---

Coder runs [code-server](https://github.com/coder/code-server) — Visual Studio Code served straight to the browser, backed by remote compute. No desktop or VNC: the editor is the web page, reached over a single HTTP port.

## Configuration

```yaml
name: coder
tags:
    - development
steps:
    - name: app
      platform: docker
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
          - WORKING_DIR=/
      resources:
          cpu: "2"
          memory: 4G
```

```ini
[volume]
app.volume = ./volume

[port]
app.web = 8080

[env]
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

## Usage

### 1. Deploy

```bash
dxflow workflow create --identity coder coder.yml

# Start with defaults, or open a specific working directory
dxflow workflow start coder
dxflow workflow start coder \
    --override env.app.WORKING_DIR=projects/my-app
```

### 2. Open the editor

Open your browser at `http://localhost:8080`. code-server opens on the working directory and needs no password — keep the port private and reach it through the platform's authenticated proxy.

### 3. Persist data

The editor opens under `/volume`, so your code, settings, and extensions survive restarts — mount a local directory there to keep your work.

## Notes

- `WORKING_DIR` is resolved under `/volume` (default `/` opens `/volume`). Set it to a subpath like `projects/my-app` to open straight into a project.
- Authentication is disabled (`--auth=none`); code-server is meant to sit behind the platform's authenticated proxy, so do not expose port `8080` directly to the internet.
- The shell is `zsh`, and `python3` and `git` are preinstalled for use from the integrated terminal.
