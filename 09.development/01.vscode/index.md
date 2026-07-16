---
title: VS Code Server
description: Visual Studio Code in the browser, backed by remote compute
navigation:
    icon: i-diphyx:vscode
---

Visual Studio Code, streamed here in a remote desktop session and backed by remote compute. It builds on the [Ubuntu Desktop](/hub/desktop/ubuntu) image — VS Code launches maximized with the window decorations and taskbar hidden, and ships with Miniconda for Python environments.

## Configuration

```yaml
name: vscode
tags:
    - development
steps:
    - name: app
      platform: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/vscode:latest
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
app.PANEL = hide
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
    "arch": ["amd64", "arm64"],
    "image": "ghcr.io/dxflow-ai/vscode:latest",
    "version": "1.91",
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
dxflow workflow create --identity vscode vscode.yml

# Start with defaults, or tune per run with --override
dxflow workflow start vscode
dxflow workflow start vscode \
    --override env.app.VNC_PASSWORD=my-strong-pass \
    --override env.app.TASKBAR=show
```

### 2. Open the editor

Open your browser at `http://localhost:6082/vnc.html` and enter the password you set in `VNC_PASSWORD`. VS Code is already running and maximized. Port `5901` is also exposed for connecting a native VNC client.

### 3. Persist data

The editor profile and extensions live under `/volume`, so settings, extensions, and workspaces survive restarts — mount a local directory there to keep your work.

## Notes

- Set a strong `VNC_PASSWORD`; if unset, the desktop falls back to the password `anonymous`.
- VS Code runs with `--no-sandbox` because it runs as root inside the container. Keep the session private and protected by `VNC_PASSWORD`.
- Miniconda is installed at `/opt/miniconda` and on the `PATH` — use `conda` to manage Python environments from the integrated terminal.
- GitHub Copilot is installed on first launch into the persisted extensions directory.
- The panel and taskbar are hidden by default so the editor fills the screen. Set `PANEL=show` or `TASKBAR=show` to bring back the window decorations and taskbar.
- Audio: off by default. Set `AUDIO=on` to stream desktop sound; tune with `AUDIO_CHANNELS` (1 or 2) and `AUDIO_RATE` (8000/16000/22050/32000/44100). The audio port is `AUDIO_PORT` (default `6100`) — the client follows it, so to run two sessions on one host give each its own port by setting `AUDIO_PORT` and the matching `audio` port mapping together.
