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
   binding in `compose.yaml`.
3. In this repo's settings: a deploy key pair whose public half is in the host user's
   `~/.ssh/authorized_keys`, and these secrets: `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_SSH_KEY` (the
   private half). Set the repository variable `DEPLOY` to `docker-host`.
4. Merge, or run the deploy workflow by hand. It logs the host into GHCR with the run's own
   token just long enough to pull, then `docker compose up -d`.

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
   kubectl create secret generic cheapseats \
     --from-literal=CHEAPSEATS_TOKENS=... --from-literal=ANTHROPIC_API_KEY=...
   # This repo's image is private: a pull secret, from a token with read:packages.
   kubectl create secret docker-registry ghcr --docker-server=ghcr.io \
     --docker-username=<github user> --docker-password=<token>
   ```

2. Adjust [`values.yaml`](values.yaml): volume size, ingress host and TLS.
   `helm show values oci://ghcr.io/cheapseatsdev/charts/cheapseats` lists everything.
3. In this repo's settings: the secret `KUBECONFIG` (a kubeconfig that can deploy to that
   namespace) and the repository variable `DEPLOY=kubernetes`.
4. Merge. The workflow runs `helm upgrade --install --rollback-on-failure`: a deploy whose pod
   doesn't come up healthy (a broken config, a bad secret) rolls back by itself.

The chart runs one replica and replaces it rather than rolling, so two Cheap Seatss never share the
database; expect a few seconds of downtime per deploy. The volume claim is kept if the release is
uninstalled.

## Upgrades and rollbacks

- Cheap Seats copies its database to `cheapseats.db.bak-v<N>` before any schema change, and refuses to
  start on a database from a newer version. To roll back across one, stop it, put the copy back
  as `cheapseats.db`, and deploy the previous image.
- A run in progress when a deploy restarts Cheap Seats resumes on its own afterwards.
