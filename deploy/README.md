# Deploying

Every merge to `main` runs [`deploy.yml`](../.github/workflows/deploy.yml): it checks the config,
builds `ghcr.io/<this repo>:sha-<commit>` (Cheap Seats with this config inside) and, if the repository
variable `DEPLOY` says where, deploys it. Cheap Seats is one always-on instance with one database
volume; never run two against the same data.

Either way you need these secrets for Cheap Seats itself:

| variable | |
| --- | --- |
| `CHEAPSEATS_TOKENS` | comma-separated access tokens for the UI, API and MCP (`openssl rand -hex 32`) |
| `ANTHROPIC_API_KEY` | grading and the fix list (Claude) |
| `OPENAI_API_KEY` | only if an answerer uses `provider = "openai"` |

## A Docker host

Any Linux machine with Docker and the compose plugin.

1. On the host, once: make `~/cheapseats`, copy [`compose.yaml`](compose.yaml) into it, and write
   `~/cheapseats/.env` with the variables above (mode 600).
2. Put a TLS-terminating proxy in front of `127.0.0.1:3000` (Caddy, nginx), or change the port
   binding in `compose.yaml`. The proxy must pass the public host name through, or Cheap Seats must
   be told it: a form posted from the page arrives with its origin, and Cheap Seats refuses a
   change whose origin isn't the host the request came to (cross-site request forgery). Caddy
   passes `Host` through by default; nginx rewrites it to the upstream address unless you add
   `proxy_set_header Host $host;`. Either way, `CHEAPSEATS_HOSTS=cheapseats.example.com` in `.env`
   names the host and is enough on its own. Have the proxy redirect HTTP to HTTPS and send
   `Strict-Transport-Security` (Caddy redirects by default; add the header with
   `header Strict-Transport-Security "max-age=31536000"`, or in nginx
   `add_header Strict-Transport-Security "max-age=31536000" always;` plus a port 80 server that
   `return 301 https://$host$request_uri;`), so a browser never sends the access token in clear.
3. In this repo's settings: a deploy key pair whose public half is in the host user's
   `~/.ssh/authorized_keys`, and these secrets: `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_SSH_KEY` (the
   private half) and `DEPLOY_HOST_KEY`, the host's own public key, so the workflow talks to the
   host and not to whatever answers at its name. Read it over a connection you already trust (not
   `ssh-keyscan` from somewhere new, which would trust whatever answered):

   ```sh
   ssh <user>@<host> cat /etc/ssh/ssh_host_ed25519_key.pub
   ```

   Set the repository variable `DEPLOY` to `docker-host`.

   The deploy key only needs to run commands, so restrict it in `authorized_keys`:

   ```
   no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-pty ssh-ed25519 AAAA... cheapseats-deploy
   ```

   Where practical, also add `command="..."` naming a script that runs `$SSH_ORIGINAL_COMMAND`
   only if it's one of the three the workflow sends (`docker login`, the `cd cheapseats && ...
   docker compose` line and `docker logout`). The host user can run Docker, which is as good as
   root on that machine, so the key is worth that care.

   A deploy set up before `DEPLOY_HOST_KEY` existed fails at this step, with a message naming the
   secret, until it's set: the workflow used to accept whatever key the host presented on first
   contact, which a fresh runner does on every run.
4. Merge, or run the deploy workflow by hand from `main` (from any other branch it does nothing).
   It logs the host into GHCR with the run's own token, which can only read packages, just long
   enough to pull, then `docker compose up -d`, and logs it out again even if the deploy failed.

The database lives in the `cheapseats-data` volume. Back it up with Cheap Seats' own command, which
takes a consistent copy while it runs (copying `cheapseats.db` itself can miss recent writes still in
SQLite's write-ahead log):

```bash
cd ~/cheapseats
docker compose exec cheapseats /app/cheapseats backup /data/backup-$(date +%F).db
docker compose cp cheapseats:/data/backup-$(date +%F).db .
```

Cheap Seats also writes `cheapseats.db.bak-v<N>` itself before any schema change. To restart by hand:
`cd ~/cheapseats && docker compose --env-file image.env up -d`.

## Kubernetes

Uses the Cheap Seats Helm chart, released with the app at the same version as the Dockerfile's `FROM`.

1. Once, in the namespace you deploy to:

   ```bash
   umask 077   # the files below are readable by you only
   # cheapseats.env: the variables above, one NAME=value per line. Write it in an editor, so no
   # key is typed on a command line (shell history, the process list).
   "${EDITOR:-vi}" cheapseats.env
   kubectl create secret generic cheapseats --from-env-file=cheapseats.env

   # This repo's image is private: a pull secret, from a token with read:packages.
   read -rs GHCR_TOKEN   # paste the token; it isn't echoed or kept in history
   printf '{"auths":{"ghcr.io":{"auth":"%s"}}}' \
     "$(printf '%s:%s' '<github user>' "$GHCR_TOKEN" | base64 | tr -d '\n')" >ghcr.json
   kubectl create secret generic ghcr --type=kubernetes.io/dockerconfigjson \
     --from-file=.dockerconfigjson=ghcr.json

   rm cheapseats.env ghcr.json; unset GHCR_TOKEN
   ```

2. Adjust [`values.yaml`](values.yaml): volume size, ingress host and TLS.
   `helm show values oci://ghcr.io/cheapseatsdev/charts/cheapseats` lists everything.
3. In this repo's settings: the secret `KUBECONFIG` (a kubeconfig that can deploy to that
   namespace) and the repository variable `DEPLOY=kubernetes`.
4. Merge. The workflow runs `helm upgrade --install --rollback-on-failure`: a deploy whose pod
   doesn't come up healthy (a broken config, a bad secret) rolls back by itself.

The chart runs one replica and replaces it rather than rolling, so two Cheap Seats instances never
share the database; expect a few seconds of downtime per deploy. The volume claim is kept if the
release is uninstalled.

## Upgrades and rollbacks

- Cheap Seats copies its database to `cheapseats.db.bak-v<N>` before any schema change, and refuses to
  start on a database from a newer version. To roll back across one, stop it, put the copy back
  as `cheapseats.db`, and deploy the previous image.
- A run in progress when a deploy restarts Cheap Seats resumes on its own afterwards.
