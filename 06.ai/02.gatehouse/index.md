---
title: Gatehouse
description: Accounts, groups and per-model permissions in front of local large language models
navigation:
    icon: i-hugeicons:user-shield-01
---

Gatehouse is the door your team reaches the GPU through. It runs [Open WebUI](https://docs.openwebui.com/) in front of the model servers on your GPU machines, and everything arrives on one port that asks who is asking: an administrator creates accounts, sorts them into groups, and decides which model each group may call. Everyone else signs in and gets both ways through at once — the chat interface in the browser, and a personal API key for their own tools, answering to the same permissions and recorded in the same audit log.

It is the gate and nothing else. No model runs here and no card is needed: `OLLAMA_BASE_URLS` names the servers it fronts — an [Ollama](/hub/ai/ollama) deployment per GPU machine — and this step gives them the accounts, permissions and audit trail that Ollama has none of.

**Key features:**

- Accounts with roles (`admin`, `user`, `pending`) and an approval queue for new ones
- Groups carrying permissions, and per-model access control granted to them
- Per-user API keys for an OpenAI- and Anthropic-compatible API, on the same permissions
- An audit log of who called what, kept on the volume
- Sign-in with the built-in form, OIDC/OAuth (Keycloak, Entra, Google), or LDAP
- Several GPU machines behind one address, their models merged into one list
- Runs on 2 cores and 4G with no GPU of its own — the cards stay with the servers

## Usage

### 1. Deploy

```bash
dxflow workflow create --identity gatehouse hub://gatehouse

# Name the model servers it fronts — one per GPU machine, ; separated
dxflow workflow start gatehouse \
    --override 'env.app.OLLAMA_BASE_URLS=http://gpu-01:11434;http://gpu-02:11434' \
    --override env.app.ADMIN_PASSWORD=my-strong-pass

# Publish the web port on an HTTPS link, for users outside the machine
dxflow workflow start gatehouse --link
```

Those servers can be the hub's own [Ollama](/hub/ai/ollama) entry, deployed on each machine with a card. They must be reachable from this step and from nowhere else — an Ollama server has no authentication of its own, which is the whole reason this entry exists. Started with none named, the interface comes up with an empty model list and says so in the log.

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

- **Users → Overview** — create an account, or approve one waiting in the queue. `DEFAULT_USER_ROLE=pending` is what puts a new account in that queue rather than letting it in.
- **Users → Groups** — a group carries permissions (chat, file upload, web search, API keys) and is what model access is granted to, so it is worth creating before the accounts that join it.
- **Settings → Models** — each model is public or restricted to groups. Restrict the large ones to the group allowed to occupy the GPU, and leave a small one public.
- **Settings** — the deployment-wide toggles, re-read from the workflow definition on every start (see [Notes](#notes)).

Signup is closed by default (`ENABLE_SIGNUP=false`): accounts are created by an administrator, or by an identity provider. Open it, and `DEFAULT_USER_ROLE` decides whether a new account waits for approval or walks in.

### 4. Pull a model

Models live on the servers behind the gate, not here. Pull one from **Admin Panel → Settings → Models**, then the **Actions** dropdown at the top right → **Manage**. That opens the model manager: pick the server, and under **Pull a model from Ollama.com** enter a tag from [the Ollama library](https://ollama.com/library) and press the download button beside it. Progress shows in the modal, and the model lands in that machine's store.

Two things that send people looking in the wrong place: the search box on the Models page filters the models you already have rather than searching Ollama's library, so a tag you have not pulled returns nothing; and **Manage** is an item in the **Actions** dropdown, not a button on the page. If **Manage** opens without an Ollama section, no server is registered — check **Admin Panel → Settings → Connections**, which lists what `OLLAMA_BASE_URLS` named.

`qwen2.5:1.5b` is a good first pull — small enough for CPU, and its template carries tool calling, which Open WebUI uses for chat titles, tags and web search. A model without it answers a plain message and fails those with `does not support tools`; the tiny ones (`smollm2:135m`, `smollm2:360m`, most `:1b` tags) are the usual culprits. The badge on a library page is for the family, not the tag — `smollm2` is badged for tools and only its `1.7b` carries them.

Or pull on the machine itself, which writes the same store:

```bash
dxflow workflow shell ollama          # on the GPU machine
ollama pull qwen2.5:1.5b
```

A model present on two servers is one entry in the list with twice the capacity behind it.

### 5. Use the API

Each user issues their own key from their account menu → **Settings → Account → API keys**, pressing **Show** to reveal the section, then **Create new secret key**. That is their personal settings, not Admin Panel. The key carries that user's permissions, so a model they cannot see in the browser is not reachable with it either:

```bash
# What this key may call
curl -H "Authorization: Bearer sk-..." http://localhost:8080/api/models

# A completion, in the OpenAI shape any client already speaks
curl http://localhost:8080/api/chat/completions \
    -H "Authorization: Bearer sk-..." \
    -H "Content-Type: application/json" \
    -d '{
      "model": "qwen2.5:1.5b",
      "messages": [{ "role": "user", "content": "Hello!" }]
    }'
```

Point an OpenAI client at `http://localhost:8080/api` as its base url — or at the `--link` url — with the key as its API key. `/api/v1/messages` answers in the Anthropic Messages shape for a client that speaks that instead.

Check the gate while you are there. The same request without a key has to be refused:

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X POST http://localhost:8080/api/chat/completions \
    -H 'Content-Type: application/json' \
    -d '{"model":"qwen2.5:1.5b","messages":[{"role":"user","content":"hi"}]}'
# 401 — anything else means the gate is open
```

Use `POST`, not `GET`: a `GET` on that path returns `200` and the sign-in page's html, because the interface answers unmatched routes with its own app shell. That looks like a bypass and is not one.

### 6. Watch what goes through

```bash
# Who called what, as it happens
dxflow artifact download gatehouse/data/audit.log -

# The startup pulls, the model server, the interface
dxflow workflow logs --live gatehouse
```

## Configuration

No GPU and no model store: the cards stay with the servers `OLLAMA_BASE_URLS` names, and this step holds the accounts, the chats and the audit log.

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
          - OLLAMA_BASE_URLS=
          - ADMIN_EMAIL=gatehouse@dxflow.ai
          - ADMIN_PASSWORD=dxflow
          - ADMIN_NAME=Admin
          - ENABLE_SIGNUP=false
          - DEFAULT_USER_ROLE=pending
          - ENABLE_API_KEYS=true
          - USER_PERMISSIONS_FEATURES_API_KEYS=true
          - AUDIT_LOG_LEVEL=METADATA
          - WEBUI_NAME=Gatehouse
          - WEBUI_URL=
          - WEBUI_SECRET_KEY=
      resources:
          cpu: "2"
          memory: 4G
      link: web
```

```ini
[volume]
app.volume = ./volume/gatehouse

[port]
app.web = 8080

[env]
app.OLLAMA_BASE_URLS =
app.ADMIN_EMAIL = gatehouse@dxflow.ai
app.ADMIN_PASSWORD = dxflow
app.ADMIN_NAME = Admin
app.ENABLE_SIGNUP = false
app.DEFAULT_USER_ROLE = pending
app.ENABLE_API_KEYS = true
app.USER_PERMISSIONS_FEATURES_API_KEYS = true
app.AUDIT_LOG_LEVEL = METADATA
app.WEBUI_NAME = Gatehouse
app.WEBUI_URL =
app.WEBUI_SECRET_KEY =

[resource]
app.cpu = 2
app.memory = 4G
```

```json
{
    "arch": ["amd64", "arm64"],
    "image": "ghcr.io/dxflow-ai/gatehouse:latest",
    "version": "0.11.3",
    "minimum": {
        "cpu": 1,
        "memory": "2G",
        "storage": "20G"
    }
}
```

## The servers behind it

`OLLAMA_BASE_URLS` takes them separated by `;`. Open WebUI spreads requests across them and merges what they hold into one model list, so capacity is added by adding a machine:

```bash
dxflow workflow start gatehouse \
    --override 'env.app.OLLAMA_BASE_URLS=http://gpu-01:11434;http://gpu-02:11434'
```

How a shared card is divided is set **on those machines**, not here — `OLLAMA_NUM_PARALLEL` for the requests one model answers at once, `OLLAMA_MAX_LOADED_MODELS` for how many stay resident, `OLLAMA_MAX_QUEUE` for the backlog, `OLLAMA_KEEP_ALIVE` for how long an idle one holds VRAM. On the hub's [Ollama](/hub/ai/ollama) entry they are step environment like any other.

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
| `OLLAMA_BASE_URLS`         | The model servers to serve from, `;`-separated                                | empty             |
| `ADMIN_EMAIL`              | The first account, registered on a fresh volume and made an administrator    | `gatehouse@dxflow.ai` |
| `ADMIN_PASSWORD`           | Its password; empty generates one and prints it to the logs once             | `dxflow`          |
| `ADMIN_NAME`               | Its display name                                                             | `Admin`           |
| `ENABLE_SIGNUP`            | Let a visitor register an account; closed, an administrator creates them     | `false`           |
| `DEFAULT_USER_ROLE`        | What a new account gets — `pending` (waits for approval), `user`, or `admin` | `pending`         |
| `ENABLE_API_KEYS`          | Turn personal API keys on for the deployment                                 | `true`            |
| `USER_PERMISSIONS_FEATURES_API_KEYS` | Whether a non-admin account may issue one — upstream defaults this off | `true` |
| `AUDIT_LOG_LEVEL`          | `NONE`, `METADATA`, `REQUEST`, or `REQUEST_RESPONSE`                         | `METADATA`        |
| `WEBUI_NAME`               | The name the interface carries                                               | `Gatehouse`       |
| `WEBUI_URL`                | Public url, for share links and OAuth redirects — set it for a `--link` start | empty            |
| `WEBUI_SECRET_KEY`         | Session signing key; empty keeps a generated one on the volume               | empty             |

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

## Notes

- **The servers behind it must not be reachable except from here.** An Ollama server has no accounts, no keys and no permissions: anything that can open port `11434` gets every model on that machine. Keep them on a private network, and let port `8080` on this step be the only way in — that is the whole of what this entry does.
- **A key is worth what its account is worth.** An administrator's key reaches every model, so it proves nothing about access control and belongs in no application. Issue keys from the accounts that will use them, and check the restriction from one of those: the model missing from their `/api/models` is the permission working.
- **Two ways in, one permission model.** The chat interface and the API key are the same account: a model restricted to a group in **Admin Panel → Settings → Models** is absent from that user's model list and refused to their key alike. `BYPASS_MODEL_ACCESS_CONTROL` is off and belongs off — it makes every model reachable by everyone.
- **Settings come from the workflow definition.** `ENABLE_PERSISTENT_CONFIG` is `False`, so what the environment says wins on every start, and a start is what changes a setting — a toggle flipped in the interface lasts until then. Accounts, groups, keys and chats are not settings: they live in the database on the volume and persist regardless. Set `ENABLE_PERSISTENT_CONFIG=True` to manage the settings from the interface instead, at the price of `--override` quietly doing nothing on a later start.
- **Set `ADMIN_PASSWORD` on the start that creates the account.** It defaults to `dxflow`, which every reader of this page knows, and a `--link` start puts the sign-in page on the public internet. Left empty it generates one instead, printed once to the logs and stored nowhere.
- **The first start registers the administrator** against an empty volume. On every later start the same request comes back "already registered" and is ignored, so changing `ADMIN_PASSWORD` afterwards does not change the password — do that from the account page, or start against a fresh volume.
- **The audit log records metadata** — who, when, which endpoint, which model — and by default excludes the chat paths, so conversation bodies stay out of it. `REQUEST` and `REQUEST_RESPONSE` put the bodies in; consider what that means for the people using it before turning them on.
- **There are no per-user token budgets.** Open WebUI meters nothing: it decides *whether* a user may call a model, not *how much*. `OLLAMA_MAX_QUEUE` and `OLLAMA_NUM_PARALLEL` bound the load a shared GPU takes, and the audit log says who is generating it, but a spending cap means putting a proxy that keeps one — LiteLLM, say — behind `OPENAI_API_BASE_URLS`.
- **No model runs here.** The image is the interface and its database, 1.8GB rather than the 3.5GB a bundled server costs, and the step needs no card and little memory — 2 cores and 4G front as many GPU machines as you point it at. The models, their storage and their VRAM are the business of the servers in `OLLAMA_BASE_URLS`.
- **A connection added in the interface does not survive a restart** while `ENABLE_PERSISTENT_CONFIG` is off, because a connection is a setting. `OLLAMA_BASE_URLS` in the definition is what makes one permanent.
- **Tool calling is per tag, not per model.** Open WebUI asks for it when generating a chat title, tagging a conversation, or running a search, so a model whose template lacks it answers messages and fails those with `does not support tools`. `ollama.com/library/<name>` badges the family — check the tag: `smollm2` is badged for tools and only `smollm2:1.7b` carries them.
- **Change what a `--link` start exposes.** That publishes the sign-in page on the public internet: set `WEBUI_URL` to the link url so share links and OAuth redirects resolve, and leave `ENABLE_SIGNUP=false` unless you mean it.
- **SQLite on the volume** holds the deployment by default, which suits a team. Point `DATABASE_URL` at Postgres for one that outgrows a single file, and note that `UVICORN_WORKERS` above `1` needs Redis behind `WEBSOCKET_MANAGER` as well.

## References

- **Documentation**: [Open WebUI docs](https://docs.openwebui.com/)
- **Access control**: [Roles](https://docs.openwebui.com/features/authentication-access/rbac/roles/) · [Groups](https://docs.openwebui.com/features/authentication-access/rbac/groups/) · [Permissions](https://docs.openwebui.com/features/authentication-access/rbac/permissions/)
- **API**: [API keys](https://docs.openwebui.com/features/authentication-access/api-keys/) · [API endpoints](https://docs.openwebui.com/getting-started/api-endpoints/)
- **Environment**: [Open WebUI variables](https://docs.openwebui.com/getting-started/env-configuration/) · [Ollama variables](https://docs.ollama.com/faq)
- **Source**: [open-webui/open-webui](https://github.com/open-webui/open-webui)
