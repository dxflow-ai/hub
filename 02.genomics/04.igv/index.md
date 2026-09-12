---
title: IGV
description: Integrative Genomics Viewer for alignments and annotations
navigation:
    icon: i-diphyx:igv
---

IGV is the Integrative Genomics Viewer — it renders alignments, variants, coverage, and annotation tracks against a reference genome, streamed here in a remote desktop session and backed by remote compute. It builds on the [Ubuntu Desktop](/hub/desktop/ubuntu) image — IGV launches maximized with the window decorations and taskbar hidden, so the track view fills the screen.

## Usage

### 1. Deploy

```bash
dxflow workflow create --identity igv hub://igv

# Start with defaults, or tune per run with --override
dxflow workflow start igv
dxflow workflow start igv \
    --override env.app.VNC_PASSWORD=my-strong-pass \
    --override env.app.TASKBAR=show

# Publish the web port on an HTTPS link
dxflow workflow start igv --link
```

### 2. Open the app

Open your browser at `http://localhost:6082/vnc.html` and enter the password you set in `VNC_PASSWORD`. IGV is already running and maximized. Port `5901` is also exposed for connecting a native VNC client. A start given `--link` publishes port `6082` at an HTTPS URL printed on the start line — open it at `/vnc.html` to reach IGV from anywhere.

### 3. Persist data

Anything under `/volume` persists across restarts — save your work there to keep it.

## Configuration

```yaml
name: igv
tags:
    - genomics
steps:
    - name: app
      runtime: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/igv:latest
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
          - AUDIO=off
          - AUDIO_PORT=6100
          - AUDIO_CHANNELS=1
          - AUDIO_RATE=22050
      resources:
          cpu: "4"
          memory: 8G
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
    "arch": ["amd64", "arm64"],
    "image": "ghcr.io/dxflow-ai/igv:latest",
    "version": "2.18.5",
    "minimum": {
        "cpu": 2,
        "memory": "4G",
        "storage": "20G"
    }
}
```

## Notes

- Set a strong `VNC_PASSWORD`; it defaults to `dxflow`, which every reader of this page knows.
- The panel and taskbar are hidden by default so the track view fills the screen. Set `PANEL=show` or `TASKBAR=show` to bring back the window decorations and taskbar.
- Audio: off by default. Set `AUDIO=on` to stream desktop sound; tune with `AUDIO_CHANNELS` (1 or 2) and `AUDIO_RATE` (8000/16000/22050/32000/44100). The audio port is `AUDIO_PORT` (default `6100`) — the client follows it, so to run two sessions on one host give each its own port by setting `AUDIO_PORT` and the matching `audio` port mapping together.
- Reference genomes are downloaded on first use, so the session needs outbound network — or load a local `.genome`/FASTA from `/volume`.
- This is the first interactive entry in the genomics category; the others are headless. Void packages none of the genomics stack, so it builds on the Ubuntu desktop.
