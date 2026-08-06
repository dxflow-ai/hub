---
title: RStudio Server
description: Browser-based IDE for R statistical computing and graphics
navigation:
    icon: i-diphyx:rstudio
---

RStudio Server provides a browser-based development environment for R — with an editor, console, plots, and package management — backed by remote compute. It's served straight to the browser, no desktop or VNC.

## Usage

### 1. Deploy

```bash
dxflow workflow create --identity rstudio hub://rstudio

# Start with defaults, or tune per run with --override
dxflow workflow start rstudio
dxflow workflow start rstudio \
    --override env.app.PASSWORD=my-strong-pass
```

### 2. Open the IDE

Open your browser at `http://localhost:8787` and sign in as `USER` (default `dxflow`) with the password you set in `PASSWORD`.

### 3. Persist data

The R user's home directory lives under `/volume`, so your projects, history, and installed packages survive restarts — mount a local directory there to keep them.

## Configuration

```yaml
name: rstudio
tags:
    - analytics
steps:
    - name: app
      runtime: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/rstudio:latest
      volumes:
          - name: volume
            host: ./volume
            container: /volume
      ports:
          - name: web
            host: "8787"
            container: "8787"
      env:
          - USER=dxflow
          - PASSWORD=dxflow
      resources:
          cpu: "4"
          memory: 8G
      link: web
```

```ini
[volume]
app.volume = ./volume

[port]
app.web = 8787

[env]
app.USER = dxflow
app.PASSWORD = dxflow

[resource]
app.cpu = 4
app.memory = 8G
```

```json
{
    "arch": ["amd64"],
    "image": "ghcr.io/dxflow-ai/rstudio:latest",
    "version": "1.4",
    "minimum": {
        "cpu": 4,
        "memory": "8G",
        "storage": "50G"
    }
}
```

## Notes

- Set a strong `PASSWORD`; it defaults to `dxflow`, which every reader of this page knows. RStudio authenticates it through PAM against the `USER` account, so the sign-in page is the only way in.
- The home directory is `/volume/$USER` (default user `dxflow`) — install R packages with `install.packages()` and they persist there.
