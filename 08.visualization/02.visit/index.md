---
title: VisIt
description: Interactive visualization and analysis of simulation data
navigation:
    icon: i-diphyx:visit
---

VisIt is an interactive tool for visualizing and analyzing large simulation datasets across many mesh and field types, streamed here in a remote desktop session and backed by remote compute. It builds on the [Ubuntu Desktop](/hub/desktop/ubuntu) image — VisIt opens on the desktop with the taskbar hidden but the panel kept, so its multiple windows are easy to move around.

## Configuration

```yaml
name: visit
tags:
    - visualization
steps:
    - name: app
      platform: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/visit:latest
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
app.PANEL = show
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
    "image": "ghcr.io/dxflow-ai/visit:latest",
    "version": "3.4",
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
dxflow workflow create --identity visit visit.yml

# Start with defaults, or tune per run with --override
dxflow workflow start visit
dxflow workflow start visit \
    --override env.app.VNC_PASSWORD=my-strong-pass \
    --override env.app.TASKBAR=show
```

### 2. Open the app

Open your browser at `http://localhost:6082/vnc.html` and enter the password you set in `VNC_PASSWORD`. VisIt is already running — its GUI and viewer windows open on the desktop. Port `5901` is also exposed for connecting a native VNC client.

### 3. Persist data

Mount your simulation data under `/volume` and save your work there — anything under `/volume` persists across restarts.

## Notes

- Set a strong `VNC_PASSWORD`; if unset, the desktop falls back to the password `anonymous`.
- The panel is kept and the taskbar hidden by default so VisIt's multiple windows are easy to manage. Set `TASKBAR=show` to bring back the taskbar, or `PANEL=hide` to drop the window decorations.
- Rendering is CPU-based (software OpenGL) unless a GPU is attached; give the step more CPU and memory for large datasets, and attach a GPU for interactive rendering of heavy scenes.
- Audio: off by default. Set `AUDIO=on` to stream desktop sound; tune with `AUDIO_CHANNELS` (1 or 2) and `AUDIO_RATE` (8000/16000/22050/32000/44100). The audio port is `AUDIO_PORT` (default `6100`) — the client follows it, so to run two sessions on one host give each its own port by setting `AUDIO_PORT` and the matching `audio` port mapping together.
