---
title: PyMOL
description: Molecular visualization of structures and trajectories
navigation:
    icon: i-diphyx:pymol
---

PyMOL is a molecular visualization system for rendering and analyzing 3D structures and simulation trajectories, streamed here in a remote desktop session and backed by remote compute. It builds on the [Ubuntu Desktop](/hub/desktop/ubuntu) image — PyMOL opens on the desktop with the taskbar hidden but the panel kept, so its viewer and control windows are easy to arrange.

## Configuration

```yaml
name: pymol
tags:
    - molecular
steps:
    - name: app
      platform: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/pymol:latest
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
          - TASKBAR=hide
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
app.TASKBAR = hide
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
    "arch": ["amd64"],
    "image": "ghcr.io/dxflow-ai/pymol:latest",
    "version": "3.1",
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
dxflow workflow create --identity pymol pymol.yml

# Start with defaults, or tune per run with --override
dxflow workflow start pymol
dxflow workflow start pymol \
    --override env.app.VNC_PASSWORD=my-strong-pass \
    --override env.app.TASKBAR=show
```

### 2. Open the app

Open your browser at `http://localhost:6082/vnc.html` and enter the password you set in `VNC_PASSWORD`. PyMOL is already running — its viewer and control windows open on the desktop. Port `5901` is also exposed for connecting a native VNC client.

### 3. Persist data

Mount your structures and trajectories under `/volume` and save your sessions there — anything under `/volume` persists across restarts.

## Notes

- Set a strong `VNC_PASSWORD`; if unset, the desktop falls back to the password `anonymous`.
- The panel is kept and the taskbar hidden by default so PyMOL's windows are easy to manage. Set `TASKBAR=show` or `PANEL=hide` to change that.
- Rendering is CPU-based (software OpenGL) unless a GPU is attached; attach a GPU for smoother interactive rendering and ray tracing of large structures.
- Audio: off by default. Set `AUDIO=on` to stream desktop sound; tune with `AUDIO_CHANNELS` (1 or 2) and `AUDIO_RATE` (8000/16000/22050/32000/44100). The audio port is `AUDIO_PORT` (default `6100`) — the client follows it, so to run two sessions on one host give each its own port by setting `AUDIO_PORT` and the matching `audio` port mapping together.
