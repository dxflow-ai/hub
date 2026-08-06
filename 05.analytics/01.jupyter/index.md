---
title: Jupyter Lab
description: Interactive development environment for notebooks, code, and data
navigation:
    icon: i-diphyx:jupyter
---

JupyterLab is a web-based interactive development environment for notebooks, code, and data, backed by remote compute. This image bundles JupyterLab on top of Miniconda, served straight to the browser — no desktop or VNC.

## Usage

### 1. Deploy

```bash
dxflow workflow create --identity jupyter hub://jupyter

# Start with defaults, or tune per run with --override
dxflow workflow start jupyter
dxflow workflow start jupyter \
    --override env.app.PASSWORD=my-strong-pass \
    --override env.app.WORKING_DIR=projects/analysis
```

### 2. Open the notebook

Open your browser at `http://localhost:8888` and sign in with the password you set in `PASSWORD`. JupyterLab opens on the working directory.

### 3. Persist data

Notebooks and data live under `/volume`, so your work survives restarts — mount a local directory there to keep it.

## Configuration

```yaml
name: jupyter
tags:
    - analytics
steps:
    - name: app
      runtime: docker
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
          - PASSWORD=dxflow
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
app.PASSWORD = dxflow
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

## Notes

- `WORKING_DIR` is resolved under `/volume` (empty opens `/volume`). Set it to a subpath like `projects/analysis` to open straight into a project.
- Set a strong `PASSWORD`; it defaults to `dxflow`, which every reader of this page knows. JupyterLab asks for it on a sign-in page and the token is disabled, so the password is the only way in.
- Miniconda is at `/opt/miniconda` and on the `PATH` — use `conda` and `pip` from a notebook terminal to add libraries such as `numpy`, `pandas`, `scikit-learn`, or extensions like `jupyterlab-git`.
