---
title: Gatehouse
description: Accounts, groups and per-model permissions in front of local large language models
navigation:
    icon: i-hugeicons:user-shield-01
---

Gatehouse is the door your team reaches the GPU through. It runs [Open WebUI](https://docs.openwebui.com/) over a model server, and everything arrives on one port that asks who is asking: an administrator creates accounts, sorts them into groups, and decides which model each group may call. Everyone else signs in and gets both ways through at once — the chat interface in the browser, and a personal API key for their own tools, answering to the same permissions and recorded in the same audit log.

The model server is bundled, so a single step is a working deployment. Point it at model servers running elsewhere instead and the step becomes the gate alone, in front of as many GPU machines as you have.

**Key features:**

- Accounts with roles (`admin`, `user`, `pending`) and an approval queue for new ones
- Groups carrying permissions, and per-model access control granted to them
- Per-user API keys for an OpenAI- and Anthropic-compatible API, on the same permissions
- An audit log of who called what, kept on the volume
- Sign-in with the built-in form, OIDC/OAuth (Keycloak, Entra, Google), or LDAP
- Models served by the bundled server, GPU-accelerated, or by several GPU machines
- Concurrency, queue depth and residency tuned for a GPU many people share

## Usage

### 1. Deploy

```bash
dxflow workflow create --identity gatehouse hub://gatehouse

# Start with defaults, or tune per run with --override
dxflow workflow start gatehouse
dxflow workflow start gatehouse \
    --override env.app.ADMIN_EMAIL=you@example.com \
    --override env.app.STARTUP_MODELS=qwen2.5:7b,llama3.1:8b

# Publish the web port on an HTTPS link, for users outside the machine
dxflow workflow start gatehouse --link
```

### 2. Sign in as the administrator

The first start against an empty volume registers `ADMIN_EMAIL`, and Open WebUI makes the first account an administrator. Open `http://localhost:8080` — or the HTTPS url a `--link` start prints — and sign in with `ADMIN_EMAIL` and `ADMIN_PASSWORD`.

Set a password of your own on the start that creates the account, since the default is on this page:

```bash
dxflow workflow start gatehouse --override env.app.ADMIN_PASSWORD=my-strong-pass
```

Left empty, a password is generated instead and the logs print it once:

```bash
dxflow workflow logs gatehouse | grep "generated its password"
```

Either way, change it from **Settings → Account** once you are in; later starts do not touch an account that already exists.

### 3. Add users and decide what they reach

Everything below lives in **Admin Panel**, reached from the account menu:

- **Users** — create an account, or approve one waiting in the queue. `DEFAULT_USER_ROLE=pending` is what puts a new account in that queue rather than letting it in.
- **Groups** — a group carries permissions (chat, file upload, web search, workspace) and is what model access is granted to, so it is worth creating before the accounts that join it.
- **Models** — each model is public or restricted to groups. Restrict the large ones to the group allowed to occupy the GPU, and leave a small one public.
- **Settings** — the deployment-wide toggles, re-read from the workflow definition on every start (see [Notes](#notes)).

Signup is closed by default (`ENABLE_SIGNUP=false`): accounts are created by an administrator, or by an identity provider. Open it, and `DEFAULT_USER_ROLE` decides whether a new account waits for approval or walks in.

### 4. Use the API

Each user issues their own key from **Settings → Account → API keys**. The key carries that user's permissions, so a model they cannot see in the browser is not reachable with it either:

```bash
# What this key may call
curl -H "Authorization: Bearer sk-..." http://localhost:8080/api/models

# A completion, in the OpenAI shape any client already speaks
curl http://localhost:8080/api/chat/completions \
    -H "Authorization: Bearer sk-..." \
    -H "Content-Type: application/json" \
    -d '{
      "model": "smollm2:135m",
      "messages": [{ "role": "user", "content": "Hello!" }]
    }'
```

Point an OpenAI client at `http://localhost:8080/api` as its base url — or at the `--link` url — with the key as its API key. `/api/v1/messages` answers in the Anthropic Messages shape for a client that speaks that instead.

### 5. Watch what goes through

```bash
# Who called what, as it happens
dxflow artifact download gatehouse/data/audit.log -

# The startup pulls, the model server, the interface
dxflow workflow logs --live gatehouse
```

## Configuration

The step carries a GPU by default, which is what the larger models need. Drop it with `--override resource.app.gpu=` to run on CPU alone.

```yaml
name: gatehouse
tags:
    - ai
steps:
    - name: app
      runtime: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/gatehouse:latest
      volumes:
          - name: volume
            host: ./volume/gatehouse
            container: /volume
      ports:
          - name: web
            host: "8080"
            container: "8080"
      env:
          - ADMIN_EMAIL=gatehouse@dxflow.ai
          - ADMIN_PASSWORD=dxflow
          - ADMIN_NAME=Admin
          - ENABLE_SIGNUP=false
          - DEFAULT_USER_ROLE=pending
          - ENABLE_API_KEYS=true
          - AUDIT_LOG_LEVEL=METADATA
          - WEBUI_NAME=Gatehouse
          - WEBUI_URL=
          - WEBUI_SECRET_KEY=
          - STARTUP_MODELS=smollm2:135m
          - OLLAMA_BASE_URLS=
          - OLLAMA_NUM_PARALLEL=4
          - OLLAMA_MAX_LOADED_MODELS=2
          - OLLAMA_MAX_QUEUE=512
          - OLLAMA_KEEP_ALIVE=5m
      resources:
          cpu: "8"
          memory: 16G
          gpu: nvidia
      link: web
```

```ini
[volume]
app.volume = ./volume/gatehouse

[port]
app.web = 8080

[env]
app.ADMIN_EMAIL = gatehouse@dxflow.ai
app.ADMIN_PASSWORD = dxflow
app.ADMIN_NAME = Admin
app.ENABLE_SIGNUP = false
app.DEFAULT_USER_ROLE = pending
app.ENABLE_API_KEYS = true
app.AUDIT_LOG_LEVEL = METADATA
app.WEBUI_NAME = Gatehouse
app.WEBUI_URL =
app.WEBUI_SECRET_KEY =
app.STARTUP_MODELS = smollm2:135m
app.OLLAMA_BASE_URLS =
app.OLLAMA_NUM_PARALLEL = 4
app.OLLAMA_MAX_LOADED_MODELS = 2
app.OLLAMA_MAX_QUEUE = 512
app.OLLAMA_KEEP_ALIVE = 5m

[resource]
app.cpu = 8
app.memory = 16G
app.gpu = nvidia
```

```json
{
    "arch": ["amd64", "arm64"],
    "image": "ghcr.io/dxflow-ai/gatehouse:latest",
    "version": "0.11.3",
    "minimum": {
        "cpu": 4,
        "memory": "8G",
        "storage": "100G"
    }
}
```

## In front of GPU machines you already have

`OLLAMA_BASE_URLS` takes the model servers to serve from, separated by `;`. Given any, the bundled server does not start and the step becomes the gate alone — it needs no GPU of its own, and each url can be an [Ollama](/hub/ai/ollama) deployment on a machine that does:

```bash
dxflow workflow start gatehouse \
    --override 'env.app.OLLAMA_BASE_URLS=http://gpu-01:11434;http://gpu-02:11434' \
    --override resource.app.gpu= \
    --override resource.app.memory=4G
```

Open WebUI spreads requests across them and merges what they hold into one model list, so a model present on both is one entry with twice the capacity behind it. Those machines must then be reachable from this step and from nowhere else — an Ollama server has no authentication of its own, which is the whole reason this entry exists.

Models reached over an OpenAI-compatible API join the same list under the same permissions, so a hosted model, a vLLM server, or a [LiteLLM](https://www.litellm.ai/) proxy with per-key budgets sits beside the local ones:

```bash
dxflow workflow start gatehouse \
    --override env.app.OPENAI_API_BASE_URLS=http://litellm:4000/v1 \
    --override env.app.OPENAI_API_KEYS=sk-...
```

## Options

### Step environment

| Variable                   | Description                                                                  | Default           |
| -------------------------- | ---------------------------------------------------------------------------- | ----------------- |
| `ADMIN_EMAIL`              | The first account, registered on a fresh volume and made an administrator    | `gatehouse@dxflow.ai` |
| `ADMIN_PASSWORD`           | Its password; empty generates one and prints it to the logs once             | `dxflow`          |
| `ADMIN_NAME`               | Its display name                                                             | `Admin`           |
| `ENABLE_SIGNUP`            | Let a visitor register an account; closed, an administrator creates them     | `false`           |
| `DEFAULT_USER_ROLE`        | What a new account gets — `pending` (waits for approval), `user`, or `admin` | `pending`         |
| `ENABLE_API_KEYS`          | Let users issue personal API keys for the API                                | `true`            |
| `AUDIT_LOG_LEVEL`          | `NONE`, `METADATA`, `REQUEST`, or `REQUEST_RESPONSE`                         | `METADATA`        |
| `WEBUI_NAME`               | The name the interface carries                                               | `Gatehouse`       |
| `WEBUI_URL`                | Public url, for share links and OAuth redirects — set it for a `--link` start | empty            |
| `WEBUI_SECRET_KEY`         | Session signing key; empty keeps a generated one on the volume               | empty             |
| `STARTUP_MODELS`           | Models pulled after startup, comma-separated; empty pulls nothing            | `smollm2:135m`    |
| `OLLAMA_BASE_URLS`         | Model servers to serve from, `;`-separated; empty starts the bundled one     | empty             |
| `OLLAMA_NUM_PARALLEL`      | Requests one model answers at once                                           | `4`               |
| `OLLAMA_MAX_LOADED_MODELS` | Models resident in VRAM together                                             | `2`               |
| `OLLAMA_MAX_QUEUE`         | Requests queued before further ones are refused                              | `512`             |
| `OLLAMA_KEEP_ALIVE`        | How long an idle model stays loaded — `-1` never unloads it                  | `5m`              |

### Further settings

Open WebUI and the model server read many more from the environment — add them with `--override env.app.<NAME>=<value>`. The ones this workflow is most often extended with:

| Variable                                 | Description                                                             |
| ---------------------------------------- | ----------------------------------------------------------------------- |
| `OPENAI_API_BASE_URLS` · `OPENAI_API_KEYS` | OpenAI-compatible backends to offer beside the local models, `;`-separated |
| `DEFAULT_MODELS`                         | Model selected for a new chat, before the user picks one                |
| `DEFAULT_GROUP_ID`                       | Group every new account joins, so permissions apply before approval     |
| `API_KEYS_ALLOWED_ENDPOINTS`             | Endpoints an API key may call, comma-separated                          |
| `ENABLE_API_KEYS_ENDPOINT_RESTRICTIONS`  | Enforce that list                                                       |
| `ENABLE_LOGIN_FORM`                      | Hide the password form, leaving only the identity provider              |
| `ENABLE_OAUTH_SIGNUP`                    | Let an OIDC identity create the account it signs in with                |
| `OAUTH_CLIENT_ID` · `OAUTH_CLIENT_SECRET` · `OPENID_PROVIDER_URL` | The OIDC provider (Keycloak, Entra, Google) |
| `ENABLE_OAUTH_ROLE_MANAGEMENT`           | Take the role from an OIDC claim rather than `DEFAULT_USER_ROLE`        |
| `ENABLE_OAUTH_GROUP_MANAGEMENT`          | Keep group membership in step with the provider's groups                |
| `ENABLE_LDAP`                            | Authenticate against a directory server instead                         |
| `AUDIT_EXCLUDED_PATHS`                   | Paths kept out of the audit log (default `/chats,/chat,/folders`)       |
| `ENABLE_AUDIT_GET_REQUESTS`              | Record reads as well as writes                                          |
| `ENABLE_ADMIN_CHAT_ACCESS`               | Whether an administrator can read other users' chats                    |
| `ENABLE_CODE_EXECUTION`                  | The code interpreter, on by default                                     |
| `ENABLE_WEB_SEARCH`                      | Web search in a chat, off by default                                    |
| `OLLAMA_CONTEXT_LENGTH` · `OLLAMA_KV_CACHE_TYPE` · `OLLAMA_FLASH_ATTENTION` | What a model costs in VRAM per request |
| `DATABASE_URL`                           | A Postgres url, for a deployment outliving the SQLite file on the volume |
| `UVICORN_WORKERS`                        | Interface workers; above 1 needs Redis for websockets                   |
| `ENABLE_PERSISTENT_CONFIG`               | `True` keeps settings changed in the interface across a restart          |

## Output files

Everything the deployment accumulates lands under `gatehouse/` in **Artifacts**:

| Path                      | Description                                                        |
| ------------------------- | ------------------------------------------------------------------ |
| `gatehouse/data/webui.db` | Accounts, groups, permissions, API keys, chats, prompts, documents |
| `gatehouse/data/audit.log` | Who called what, rotated at 10MB                                  |
| `gatehouse/data/uploads/` | Files users uploaded to a chat                                     |
| `gatehouse/data/.secret`  | The generated session signing key                                  |
| `gatehouse/models/`       | The model store — what `STARTUP_MODELS` and the admin page pull    |

## Notes

- **The model server is not published.** It listens on `127.0.0.1:11434` inside the container and no port reaches it, so every request arrives through port `8080`, which asks who is making it. Publishing `11434` would hand the models to anyone who can reach the host, with no account and no permission check — that is what this entry exists to prevent. The same holds for the machines behind `OLLAMA_BASE_URLS`: reachable from this step, and from nowhere else.
- **Two ways in, one permission model.** The chat interface and the API key are the same account: a model restricted to a group in **Admin Panel → Models** is absent from that user's model list and refused to their key alike. `BYPASS_MODEL_ACCESS_CONTROL` is off and belongs off — it makes every model reachable by everyone.
- **Settings come from the workflow definition.** `ENABLE_PERSISTENT_CONFIG` is `False`, so what the environment says wins on every start, and a start is what changes a setting — a toggle flipped in the interface lasts until then. Accounts, groups, keys and chats are not settings: they live in the database on the volume and persist regardless. Set `ENABLE_PERSISTENT_CONFIG=True` to manage the settings from the interface instead, at the price of `--override` quietly doing nothing on a later start.
- **Set `ADMIN_PASSWORD` on the start that creates the account.** It defaults to `dxflow`, which every reader of this page knows, and a `--link` start puts the sign-in page on the public internet. Left empty it generates one instead, printed once to the logs and stored nowhere.
- **The first start registers the administrator** against an empty volume. On every later start the same request comes back "already registered" and is ignored, so changing `ADMIN_PASSWORD` afterwards does not change the password — do that from the account page, or start against a fresh volume.
- **The audit log records metadata** — who, when, which endpoint, which model — and by default excludes the chat paths, so conversation bodies stay out of it. `REQUEST` and `REQUEST_RESPONSE` put the bodies in; consider what that means for the people using it before turning them on.
- **There are no per-user token budgets.** Open WebUI meters nothing: it decides *whether* a user may call a model, not *how much*. `OLLAMA_MAX_QUEUE` and `OLLAMA_NUM_PARALLEL` bound the load a shared GPU takes, and the audit log says who is generating it, but a spending cap means putting a proxy that keeps one — LiteLLM, say — behind `OPENAI_API_BASE_URLS`.
- **Sharing one GPU** is what `OLLAMA_NUM_PARALLEL` and `OLLAMA_MAX_LOADED_MODELS` govern: each parallel slot and each resident model costs VRAM, so `4` and `2` suit a 24GB card holding 7B models and want lowering for larger ones. `OLLAMA_KEEP_ALIVE=-1` pins a model in VRAM, which is worth it for the one everybody uses and wasteful for the rest.
- **Models** are pulled by `STARTUP_MODELS` after the interface is up, so a large one downloads behind a working sign-in page rather than in front of it, and from **Admin Panel → Settings → Models** any time. They land in `gatehouse/models/` on the volume, so a restart does not fetch them again. `smollm2:135m` is preloaded into the image to make the first start immediate; raise the volume's storage to fit what you pull.
- **Change what a `--link` start exposes.** That publishes the sign-in page on the public internet: set `WEBUI_URL` to the link url so share links and OAuth redirects resolve, and leave `ENABLE_SIGNUP=false` unless you mean it.
- **SQLite on the volume** holds the deployment by default, which suits a team. Point `DATABASE_URL` at Postgres for one that outgrows a single file, and note that `UVICORN_WORKERS` above `1` needs Redis behind `WEBSOCKET_MANAGER` as well.

## References

- **Documentation**: [Open WebUI docs](https://docs.openwebui.com/)
- **Access control**: [Roles](https://docs.openwebui.com/features/authentication-access/rbac/roles/) · [Groups](https://docs.openwebui.com/features/authentication-access/rbac/groups/) · [Permissions](https://docs.openwebui.com/features/authentication-access/rbac/permissions/)
- **API**: [API keys](https://docs.openwebui.com/features/authentication-access/api-keys/) · [API endpoints](https://docs.openwebui.com/getting-started/api-endpoints/)
- **Environment**: [Open WebUI variables](https://docs.openwebui.com/getting-started/env-configuration/) · [Ollama variables](https://docs.ollama.com/faq)
- **Source**: [open-webui/open-webui](https://github.com/open-webui/open-webui)
