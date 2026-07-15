import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig(async () => ({
    base: "/",
    plugins: [react()],
    server: {
        host: "0.0.0.0",
        port: 3333,
        strictPort: true,
        proxy: {
            "/ollama/": {
                target: "http://127.0.0.1:11434/",
                rewrite(path: string) {
                    return path.replace("/ollama/", "/");
                },
            },
        },
    },
}));
