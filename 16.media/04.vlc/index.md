---
title: VLC
description: Media player for nearly every audio and video format
navigation:
    icon: i-hugeicons:play-circle
---

VLC is a media player that handles nearly every container and codec without extra plugins, streamed here in a remote desktop session and backed by remote compute. It builds on the [Void Desktop](/hub/desktop/void) image — VLC launches maximized with the window decorations and taskbar hidden, so the player fills the screen.

## Usage

### 1. Deploy

```bash
dxflow workflow create --identity vlc hub://vlc

# Start with defaults, or tune per run with --override
dxflow workflow start vlc
dxflow workflow start vlc \
    --override env.app.VNC_PASSWORD=my-strong-pass \
    --override env.app.TASKBAR=show

# Publish the web port on an HTTPS link
dxflow workflow start vlc --link
```

### 2. Open the app

Open your browser at `http://localhost:6082/vnc.html` and enter the password you set in `VNC_PASSWORD`. VLC is already running and maximized. Port `5901` is also exposed for connecting a native VNC client. A start given `--link` publishes port `6082` at an HTTPS URL printed on the start line — open it at `/vnc.html` to reach VLC from anywhere.

### 3. Persist data

Anything under `/volume` persists across restarts — save your work there to keep it.

## Configuration

```yaml
name: vlc
tags:
    - media
steps:
    - name: app
      runtime: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/vlc:latest
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
          - PANEL=hide
          - TASKBAR=hide
          - AUDIO=on
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
app.PANEL = hide
app.TASKBAR = hide
app.AUDIO = on
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
    "image": "ghcr.io/dxflow-ai/vlc:latest",
    "version": "3.0.23",
    "minimum": {
        "cpu": 2,
        "memory": "2G",
        "storage": "20G"
    }
}
```

## Notes

- Set a strong `VNC_PASSWORD`; it defaults to `dxflow`, which every reader of this page knows.
- The panel and taskbar are hidden by default so the player fills the screen. Set `PANEL=show` or `TASKBAR=show` to bring back the window decorations and taskbar.
- Audio: on by default, since this is a media app — desktop sound is streamed to the browser over `AUDIO_PORT` (default `6100`). Tune it with `AUDIO_CHANNELS` (1 or 2) and `AUDIO_RATE` (8000/16000/22050/32000/44100), or set `AUDIO=off` to drop it. To run two sessions on one host, give each its own `AUDIO_PORT` and matching `audio` port mapping.
- VLC refuses to run as root, so this entry runs it as the image's unprivileged `app` user, handing it the desktop's X credentials and PulseAudio socket. Files it reads or writes have to be readable by that user — `/volume` is.
