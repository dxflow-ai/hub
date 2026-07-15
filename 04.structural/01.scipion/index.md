---
title: Scipion
description: Integrated image processing framework for cryo-electron microscopy
navigation:
    icon: i-diphyx:scipion
---

Scipion is a workflow-based image processing framework for obtaining 3D models of macromolecular complexes from cryo-EM data, backed by remote compute. It integrates packages like RELION, Xmipp, EMAN2, and CTFfind behind a unified GUI, streamed here in a remote desktop session on the [Ubuntu Desktop](/hub/desktop/ubuntu) image.

## Configuration

```yaml
name: scipion
tags:
    - structural
steps:
    - name: app
      platform: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/scipion:latest
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
          cpu: "16"
          memory: 64G
          gpu: nvidia
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
app.cpu = 16
app.memory = 64G
app.gpu = nvidia
```

```json
{
    "arch": ["amd64"],
    "image": "ghcr.io/dxflow-ai/scipion:latest",
    "version": "3.4",
    "minimum": {
        "cpu": 8,
        "memory": "32G",
        "storage": "100G"
    }
}
```

## Usage

### 1. Deploy

```bash
dxflow workflow create --identity scipion scipion.yml

# Start with defaults, or tune per run with --override
dxflow workflow start scipion
dxflow workflow start scipion \
    --override env.app.VNC_PASSWORD=my-strong-pass
```

### 2. Open the app

Open your browser at `http://localhost:6082/vnc.html` and enter the password you set in `VNC_PASSWORD`. The Scipion project manager opens on the desktop. Port `5901` is also exposed for connecting a native VNC client.

### 3. Persist data

Mount your movies and datasets under `/volume` — the Scipion user data directory is linked there, so projects and results survive restarts.

## Notes

- Set a strong `VNC_PASSWORD`; if unset, the desktop falls back to the password `anonymous`.
- Scipion is GPU- and compute-heavy: attach an NVIDIA GPU and give the step ample CPU, memory, and fast storage. The typical pipeline runs import → motion correction → CTF estimation → particle picking → 2D/3D classification → refinement → post-processing.
- The image installs the Scipion core; some plugins (e.g. Xmipp, RELION, MotionCor2) are installed on demand from the plugin manager and may need additional download and build time.
- The panel is kept and the taskbar hidden by default so Scipion's multiple windows are easy to manage. Set `TASKBAR=show` or `PANEL=hide` to change that.
- Audio: off by default. Set `AUDIO=on` to stream desktop sound; tune with `AUDIO_CHANNELS` (1 or 2) and `AUDIO_RATE` (8000/16000/22050/32000/44100). The audio port is `AUDIO_PORT` (default `6100`) — the client follows it, so to run two sessions on one host give each its own port by setting `AUDIO_PORT` and the matching `audio` port mapping together.
