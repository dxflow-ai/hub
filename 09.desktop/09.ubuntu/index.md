---
title: Ubuntu Desktop
description: Full Ubuntu Linux desktop accessible from your browser
navigation:
    icon: i-diphyx:ubuntu
---

A complete Ubuntu Linux desktop environment, accessible from your browser and backed by remote compute. The desktop (Openbox, a taskbar, a terminal, and a file manager) runs over TurboVNC and is served in the browser through noVNC.

This image is also the base other desktop and GUI workflows build on.

## Configuration

```yaml
name: ubuntu
tags:
  - desktop
steps:
  - name: ubuntu
    platform: docker
    mode: parallel
    image: ghcr.io/dxflow-ai/ubuntu:latest
    env:
      - VNC_PASSWORD=changeme
    ports:
      - host: "6082"
        container: "6082"
      - host: "5901"
        container: "5901"
    volumes:
      - host: ./volume
        container: /volume
    resources:
      cpu: "2"
      memory: 4G
```

## Usage

### 1. Deploy

```bash
dxflow workflow create --identity ubuntu ubuntu.yml
dxflow workflow start ubuntu
```

### 2. Open the desktop

Open your browser at `http://localhost:6082/vnc.html` and enter the password you set in `VNC_PASSWORD`. Port `5901` is also exposed for connecting a native VNC client.

### 3. Persist data

Anything under `/volume` persists across restarts — mount a local directory there to keep your files and app state.

## Notes

- Set a strong `VNC_PASSWORD`; if unset, the desktop falls back to the password `anonymous`.
- Display options: `WALLPAPER`, `PANEL`, and `TASKBAR` (each `show` or `hide`) toggle the wallpaper, window decorations, and taskbar.

