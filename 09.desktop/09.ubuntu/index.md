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
    - name: app
      platform: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/ubuntu:latest
      volumes:
          - name: volume
            host: ./volume
            container: /volume
      ports:
          - name: web
            host: "6082"
            container: "6082"
          - name: vnc
            host: "5901"
            container: "5901"
          - name: audio
            host: "6100"
            container: "6100"
      env:
          - VNC_PASSWORD=changeme
          - WALLPAPER=show
          - PANEL=show
          - TASKBAR=show
          - AUDIO=off
          - AUDIO_PORT=6100
          - AUDIO_CHANNELS=1
          - AUDIO_RATE=22050
      resources:
          cpu: "2"
          memory: 4G
```

```ini
[volume]
app.volume = ./volume

[port]
app.web = 6082
app.vnc = 5901
app.audio = 6100

[env]
app.VNC_PASSWORD = changeme
app.WALLPAPER = show
app.PANEL = show
app.TASKBAR = show
app.AUDIO = off
app.AUDIO_PORT = 6100
app.AUDIO_CHANNELS = 1
app.AUDIO_RATE = 22050

[resource]
app.cpu = 2
app.memory = 4G
```

```json
{
    "arch": ["amd64", "arm64"],
    "version": "22.04",
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
dxflow workflow create --identity ubuntu ubuntu.yml

# Start with defaults, or tune per run with --override
dxflow workflow start ubuntu
dxflow workflow start ubuntu \
    --override env.app.VNC_PASSWORD=my-strong-pass \
    --override env.app.TASKBAR=hide
```

### 2. Open the desktop

Open your browser at `http://localhost:6082/vnc.html` and enter the password you set in `VNC_PASSWORD`. Port `5901` is also exposed for connecting a native VNC client.

### 3. Persist data

Anything under `/volume` persists across restarts — mount a local directory there to keep your files and app state.

## Notes

- Set a strong `VNC_PASSWORD`; if unset, the desktop falls back to the password `anonymous`.
- Display options: `WALLPAPER`, `PANEL`, and `TASKBAR` (each `show` or `hide`) toggle the wallpaper, window decorations, and taskbar.
- Audio: off by default. Set `AUDIO=on` to stream desktop sound to the browser; tune with `AUDIO_CHANNELS` (1 or 2) and `AUDIO_RATE` (8000/16000/22050/32000/44100). The audio port is `AUDIO_PORT` (default `6100`) — the client follows it, so to run two desktops on one host give each its own port by setting `AUDIO_PORT` and the matching `audio` port mapping together.
