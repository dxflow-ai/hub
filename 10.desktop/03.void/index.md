---
title: Void Desktop
description: Full Void Linux desktop accessible from your browser
navigation:
    icon: i-diphyx:void
---

A complete Void Linux desktop environment, accessible from your browser and backed by remote compute. The desktop (Openbox, a taskbar, a terminal, and a file manager) runs over TurboVNC and is served in the browser through noVNC.

Built on Void Linux — a lightweight, independent rolling-release distribution with the `xbps` package manager.

## Usage

### 1. Deploy

```bash
dxflow workflow create --identity void hub://void

# Start with defaults, or tune per run with --override
dxflow workflow start void
dxflow workflow start void \
    --override env.app.VNC_PASSWORD=my-strong-pass \
    --override env.app.TASKBAR=hide

# Publish the web port on an HTTPS link
dxflow workflow start void --link
```

### 2. Open the desktop

Open your browser at `http://localhost:6082/vnc.html` and enter the password you set in `VNC_PASSWORD`. Port `5901` is also exposed for connecting a native VNC client. A start given `--link` publishes port `6082` at an HTTPS URL printed on the start line — open it at `/vnc.html` to reach the desktop from anywhere.

### 3. Persist data

Anything under `/volume` persists across restarts — mount a local directory there to keep your files and app state.

## Configuration

```yaml
name: void
tags:
    - desktop
steps:
    - name: app
      runtime: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/void:latest
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
          - VNC_PASSWORD=dxflow
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
      link: web
```

```ini
[volume]
app.volume = ./volume

[port]
app.web = 6082
app.vnc = 5901
app.audio = 6100

[env]
app.VNC_PASSWORD = dxflow
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
    "image": "ghcr.io/dxflow-ai/void:latest",
    "version": "rolling",
    "minimum": {
        "cpu": 2,
        "memory": "2G",
        "storage": "20G"
    }
}
```

## Notes

- Set a strong `VNC_PASSWORD`; it defaults to `dxflow`, which every reader of this page knows.
- Display options: `WALLPAPER`, `PANEL`, and `TASKBAR` (each `show` or `hide`) toggle the wallpaper, window decorations, and taskbar.
- Audio: off by default. Set `AUDIO=on` to stream desktop sound to the browser; tune with `AUDIO_CHANNELS` (1 or 2) and `AUDIO_RATE` (8000/16000/22050/32000/44100). The client opens the stream on the page hostname at `AUDIO_PORT` (default `6100`), so to run two desktops on one host give each its own port by setting `AUDIO_PORT` and the matching `audio` port mapping together. `AUDIO_URL` names the address instead, which is what a deployment publishing the stream elsewhere hands the client.
- Browsers keep sound muted until the page sees a gesture, so audio begins at the first click or keystroke in the desktop.
