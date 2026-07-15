---
title: ParaView
description: Parallel scientific visualization for large datasets
navigation:
    icon: i-diphyx:paraview
---

ParaView is an open-source, parallel visualization application for exploring and rendering large scientific datasets, streamed here in a remote desktop session and backed by remote compute. It builds on the [Ubuntu Desktop](/hub/desktop/ubuntu) image — ParaView launches maximized with the window decorations and taskbar hidden, so the app fills the screen.

## Configuration

```yaml
name: paraview
tags:
    - visualization
steps:
    - name: app
      platform: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/paraview:latest
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
          - PANEL=hide
          - TASKBAR=hide
          - AUDIO=off
          - AUDIO_PORT=6100
          - AUDIO_CHANNELS=1
          - AUDIO_RATE=22050
      resources:
          cpu: "4"
          memory: 8G
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
app.PANEL = hide
app.TASKBAR = hide
app.AUDIO = off
app.AUDIO_PORT = 6100
app.AUDIO_CHANNELS = 1
app.AUDIO_RATE = 22050

[resource]
app.cpu = 4
app.memory = 8G
```

```json
{
    "arch": ["amd64"],
    "image": "ghcr.io/dxflow-ai/paraview:latest",
    "version": "5.13",
    "minimum": {
        "cpu": 2,
        "memory": "4G",
        "storage": "20G"
    }
}
```

## Usage

### 1. Deploy

```bash
dxflow workflow create --identity paraview paraview.yml

# Start with defaults, or tune per run with --override
dxflow workflow start paraview
dxflow workflow start paraview \
    --override env.app.VNC_PASSWORD=my-strong-pass \
    --override env.app.TASKBAR=show
```

### 2. Open the app

Open your browser at `http://localhost:6082/vnc.html` and enter the password you set in `VNC_PASSWORD`. ParaView is already running and maximized. Port `5901` is also exposed for connecting a native VNC client.

### 3. Persist data

Mount your datasets under `/volume` and save your work there — anything under `/volume` persists across restarts.

## Notes

- Set a strong `VNC_PASSWORD`; if unset, the desktop falls back to the password `anonymous`.
- The panel and taskbar are hidden by default so ParaView fills the screen. Set `PANEL=show` or `TASKBAR=show` to bring back the window decorations and taskbar.
- Rendering is CPU-based (software OpenGL) unless a GPU is attached; give the step more CPU and memory for large datasets, and attach a GPU for interactive rendering of heavy scenes.
- Audio: off by default. Set `AUDIO=on` to stream desktop sound; tune with `AUDIO_CHANNELS` (1 or 2) and `AUDIO_RATE` (8000/16000/22050/32000/44100). The audio port is `AUDIO_PORT` (default `6100`) — the client follows it, so to run two sessions on one host give each its own port by setting `AUDIO_PORT` and the matching `audio` port mapping together.
