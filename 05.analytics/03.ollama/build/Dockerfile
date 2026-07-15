# Build the web interface
FROM node:22-alpine AS ui

WORKDIR /app

# Install dependencies (pnpm 9 runs esbuild's build script; pnpm 10 blocks it)
COPY app/package.json ./
RUN npm install -g pnpm@9 && pnpm install

# Build the app (vite only; skip tsc typecheck, which a newer TypeScript rejects)
COPY app/ ./
RUN pnpm exec vite build

# Final image
FROM ollama/ollama:0.5.11

LABEL org.opencontainers.image.title="Ollama"
LABEL org.opencontainers.image.description="Run open large language models locally with a web interface"
LABEL org.opencontainers.image.source="https://github.com/dxflow-ai/hub"

ENV DEBIAN_FRONTEND="noninteractive"

# Install the web server for the interface
RUN apt-get update -q && \
    apt-get install -y -q --no-install-recommends nginx curl && \
    rm -rf /var/lib/apt/lists/*

# Preload the default model into the image
RUN nohup ollama serve > /tmp/ollama.log 2>&1 & \
    sleep 5 && \
    ollama pull smollm2:135m && \
    (pkill ollama || true)

# Setup the web interface (nginx serves the built UI and proxies /ollama to the server)
COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=ui /app/dist/ /opt/dxflow/ui/

# Setup scripts
RUN mkdir -p /opt/dxflow
COPY prepare.sh /opt/dxflow/prepare.sh
COPY postpare.sh /opt/dxflow/postpare.sh
COPY entrypoint.sh /opt/dxflow/entrypoint.sh
RUN chmod +x /opt/dxflow/entrypoint.sh

ENV STARTUP_MODEL="smollm2:135m"

EXPOSE 8080

VOLUME [ "/volume" ]

ENTRYPOINT [ "/opt/dxflow/entrypoint.sh" ]
