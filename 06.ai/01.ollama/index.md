---
title: Ollama
description: Run open large language models locally
navigation:
    icon: i-diphyx:ollama
---

Ollama runs open large language models locally, backed by remote compute. This image bundles the Ollama server with a built-in web chat interface — open the page, pick a model, and start chatting. The Ollama HTTP API is served from the same port for your own apps.

## Configuration

```yaml
name: ollama
tags:
    - ai
steps:
    - name: app
      platform: docker
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
          - STARTUP_MODEL=smollm2:135m
      resources:
          cpu: "4"
          memory: 8G
```

```ini
[volume]
app.volume = ./volume

[port]
app.web = 8080

[env]
app.STARTUP_MODEL = smollm2:135m

[resource]
app.cpu = 4
app.memory = 8G
```

```json
{
    "arch": ["amd64", "arm64"],
    "image": "ghcr.io/dxflow-ai/ollama:latest",
    "version": "0.5",
    "minimum": {
        "cpu": 4,
        "memory": "8G",
        "storage": "50G"
    }
}
```

## Usage

### 1. Deploy

```bash
dxflow workflow create --identity ollama ollama.yml

# Start with the default model, or choose another at start
dxflow workflow start ollama
dxflow workflow start ollama \
    --override env.app.STARTUP_MODEL=qwen2.5:1.5b
```

### 2. Open the interface

Open your browser at `http://localhost:8080`. The chat UI lists the installed models — pick one and start a conversation. The streaming response renders as it is generated.

### 3. Use the API

The Ollama HTTP API is proxied under the same port at `/api`, so your own tools can call it:

```bash
curl http://localhost:8080/api/chat -d '{
  "model": "smollm2:135m",
  "messages": [{ "role": "user", "content": "Hello!" }]
}'
```

## Notes

- `STARTUP_MODEL` is pulled on startup and selected in the UI (default `smollm2:135m`, preloaded into the image). Pull more models any time from a terminal with `ollama pull <name>`.
- The web interface is a React app (served by nginx) that reverse-proxies to the local Ollama server on `11434` — the UI calls it under `/ollama/api/*`, and the standard API is also exposed directly at `/api/*`, so the browser and the API share port `8080`.
- Small models suit CPU-only runs; for larger models (7B+), attach a GPU and give the step more memory.
- Authentication is not built in — keep port `8080` private and reach it through the platform's authenticated proxy.
