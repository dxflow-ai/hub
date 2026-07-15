---
title: RStudio Server
description: Browser-based IDE for R statistical computing and graphics
navigation:
    icon: i-diphyx:rstudio
---

RStudio Server provides a browser-based development environment for R — with an editor, console, plots, and package management — backed by remote compute. It's served straight to the browser, no desktop or VNC.

## Configuration

```yaml
name: rstudio
tags:
    - analytics
steps:
    - name: app
      platform: docker
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
      resources:
          cpu: "4"
          memory: 8G
```

```ini
[volume]
app.volume = ./volume

[port]
app.web = 8787

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

## Usage

### 1. Deploy

```bash
dxflow workflow create --identity rstudio rstudio.yml
dxflow workflow start rstudio
```

### 2. Open the IDE

Open your browser at `http://localhost:8787`. RStudio opens without a login prompt — keep the port private and reach it through the platform's authenticated proxy.

### 3. Persist data

The R user's home directory lives under `/volume`, so your projects, history, and installed packages survive restarts — mount a local directory there to keep them.

## Notes

- Authentication is disabled (`--auth-none=1`); RStudio Server is meant to sit behind the platform's authenticated proxy, so do not expose port `8787` directly to the internet.
- The home directory is `/volume/$USER` (default user `diphyx`) — install R packages with `install.packages()` and they persist there.
