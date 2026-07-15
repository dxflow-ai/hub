---
title: Jupyter Lab
description: Interactive development environment for notebooks, code, and data
navigation:
    icon: i-diphyx:jupyter
---

JupyterLab is a web-based interactive development environment for notebooks, code, and data, backed by remote compute. This image bundles JupyterLab on top of Miniconda, served straight to the browser — no desktop or VNC.

## Configuration

```yaml
name: jupyter
tags:
    - analytics
steps:
    - name: app
      platform: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/jupyter:latest
      volumes:
          - name: volume
            host: ./volume
            container: /volume
      ports:
          - name: web
            host: "8888"
            container: "8888"
      env:
          - WORKING_DIR=
      resources:
          cpu: "4"
          memory: 8G
```

```ini
[volume]
app.volume = ./volume

[port]
app.web = 8888

[env]
app.WORKING_DIR =

[resource]
app.cpu = 4
app.memory = 8G
```

```json
{
    "arch": ["amd64", "arm64"],
    "image": "ghcr.io/dxflow-ai/jupyter:latest",
    "version": "4.2",
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
dxflow workflow create --identity jupyter jupyter.yml

# Start with defaults, or open a specific working directory
dxflow workflow start jupyter
dxflow workflow start jupyter \
    --override env.app.WORKING_DIR=projects/analysis
```

### 2. Open the notebook

Open your browser at `http://localhost:8888`. JupyterLab opens on the working directory and needs no token — keep the port private and reach it through the platform's authenticated proxy.

### 3. Persist data

Notebooks and data live under `/volume`, so your work survives restarts — mount a local directory there to keep it.

## Notes

- `WORKING_DIR` is resolved under `/volume` (empty opens `/volume`). Set it to a subpath like `projects/analysis` to open straight into a project.
- The token is disabled (`--NotebookApp.token=''`); JupyterLab is meant to sit behind the platform's authenticated proxy, so do not expose port `8888` directly to the internet.
- Miniconda is at `/opt/miniconda` and on the `PATH` — use `conda` and `pip` from a notebook terminal to add libraries such as `numpy`, `pandas`, `scikit-learn`, or extensions like `jupyterlab-git`.
