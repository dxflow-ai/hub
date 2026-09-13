---
title: Ollama
description: Run open large language models locally
navigation:
    icon: i-diphyx:ollama
---

Ollama runs open large language models locally, backed by remote compute. This image bundles the Ollama server with a built-in web chat interface — open the page, pick a model, and start chatting. The Ollama HTTP API is served from the same port for your own apps.

## Usage

### 1. Deploy

```bash
dxflow workflow create --identity ollama hub://ollama

# Start with defaults, or tune per run with --override
dxflow workflow start ollama
dxflow workflow start ollama \
    --override env.app.PASSWORD=my-strong-pass \
    --override env.app.STARTUP_MODEL=qwen2.5:1.5b

# Publish the web port on an HTTPS link
dxflow workflow start ollama --link
```

### 2. Open the interface

Open your browser at `http://localhost:8080` and sign in as `dxflow` with the password you set in `PASSWORD`. The chat UI lists the installed models — pick one and start a conversation. The streaming response renders as it is generated. A start given `--link` publishes port `8080` at an HTTPS URL printed on the start line, serving the chat UI and the API from anywhere.

### 3. Use the API

The Ollama HTTP API is proxied under the same port at `/api`, behind the same credential, so your own tools can call it:

```bash
curl -u dxflow:my-strong-pass http://localhost:8080/api/chat -d '{
  "model": "smollm2:135m",
  "messages": [{ "role": "user", "content": "Hello!" }]
}'
```

## Configuration

Attach a GPU with `resources.gpu: nvidia` so Ollama offloads the model to it, or remove the line to run on CPU.

```yaml
name: ollama
tags:
    - ai
steps:
    - name: app
      runtime: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/ollama:latest
      volumes:
          - name: volume
            host: ./volume
            container: /volume
      ports:
          - name: web
            host: "8080"
            container: "8080"
      env:
          - PASSWORD=dxflow
          - STARTUP_MODEL=smollm2:135m
      resources:
          cpu: "4"
          memory: 8G
          gpu: nvidia
      link: web
```

```ini
[volume]
app.volume = ./volume

[port]
app.web = 8080

[env]
app.PASSWORD = dxflow
app.STARTUP_MODEL = smollm2:135m

[resource]
app.cpu = 4
app.memory = 8G
app.gpu = nvidia
```

```json
{
    "arch": ["amd64", "arm64"],
    "image": "ghcr.io/dxflow-ai/ollama:latest",
    "version": "0.34.0",
    "size": {
        "amd64": "3.6G",
        "arm64": "2.8G"
    },
    "minimum": {
        "cpu": 4,
        "memory": "8G",
        "storage": "50G"
    }
}
```

## Notes

- `STARTUP_MODEL` is pulled on startup and selected in the UI (default `smollm2:135m`, preloaded into the image). Pull more models any time from a terminal with `ollama pull <name>`.
- The web interface is a React app (served by nginx) that reverse-proxies to the local Ollama server on `11434` — the UI calls it under `/ollama/api/*`, and the standard API is also exposed directly at `/api/*`, so the browser and the API share port `8080`.
- **GPU vs CPU**: with a GPU attached, Ollama detects it and loads as many layers into VRAM as fit — check `nvidia-smi` while a model answers. Without one it runs on CPU automatically, which suits the small models; for 7B and up, keep the card and give the step more memory.
- Set a strong `PASSWORD`; it defaults to `dxflow`, which every reader of this page knows. nginx checks it as HTTP basic auth for the user `dxflow` across the whole port, so the UI and the API share one credential.
