# Deploying

Every merge to `main` runs [`deploy.yml`](../.github/workflows/deploy.yml): it checks the config,
builds `ghcr.io/<this repo>:sha-<commit>` (Popcorn with this config inside) and, if the repository
variable `DEPLOY` says where, deploys it. Popcorn is one always-on instance with one database
volume; never run two against the same data.

Either way you need these secrets for Popcorn itself:

| variable | |
| --- | --- |
| `POPCORN_TOKENS` | comma-separated access tokens for the UI, API and MCP (`openssl rand -hex 32`) |
| `ANTHROPIC_API_KEY` | grading and the fix list (Claude) |
| `OPENAI_API_KEY` | only if an answerer uses `provider = "openai"` |

## A Docker host

Any Linux machine with Docker and the compose plugin.

1. On the host, once: make `~/popcorn`, copy [`compose.yaml`](compose.yaml) into it, and write
   `~/popcorn/.env` with the variables above (mode 600).
2. Put a TLS-terminating proxy in front of `127.0.0.1:3000` (Caddy, nginx), or change the port
   binding in `compose.yaml`.
3. In this repo's settings: a deploy key pair whose public half is in the host user's
   `~/.ssh/authorized_keys`, and these secrets: `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_SSH_KEY` (the
   private half). Set the repository variable `DEPLOY` to `docker-host`.
4. Merge, or run the deploy workflow by hand. It logs the host into GHCR with the run's own
   token just long enough to pull, then `docker compose up -d`.

The database lives in the `popcorn-data` volume. Back it up with
`docker run --rm -v popcorn_popcorn-data:/data -v $PWD:/out busybox cp /data/popcorn.db /out/`
(Popcorn writes `popcorn.db.bak-v<N>` itself before any schema change). To restart by hand:
`cd ~/popcorn && docker compose --env-file image.env up -d`.

## Kubernetes

Uses the Popcorn Helm chart, released with the app at the same version as the Dockerfile's `FROM`.

1. Once, in the namespace you deploy to:

   ```bash
   kubectl create secret generic popcorn \
     --from-literal=POPCORN_TOKENS=... --from-literal=ANTHROPIC_API_KEY=...
   # This repo's image is private: a pull secret, from a token with read:packages.
   kubectl create secret docker-registry ghcr --docker-server=ghcr.io \
     --docker-username=<github user> --docker-password=<token>
   ```

2. Adjust [`values.yaml`](values.yaml): volume size, ingress host and TLS.
   `helm show values oci://ghcr.io/metcalfc/charts/popcorn` lists everything.
3. In this repo's settings: the secret `KUBECONFIG` (a kubeconfig that can deploy to that
   namespace) and the repository variable `DEPLOY=kubernetes`.
4. Merge. The workflow runs `helm upgrade --install --rollback-on-failure`: a deploy whose pod
   doesn't come up healthy (a broken config, a bad secret) rolls back by itself.

The chart runs one replica and replaces it rather than rolling, so two Popcorns never share the
database; expect a few seconds of downtime per deploy. The volume claim is kept if the release is
uninstalled.

## Upgrades and rollbacks

- Popcorn copies its database to `popcorn.db.bak-v<N>` before any schema change, and refuses to
  start on a database from a newer version. To roll back across one, stop it, put the copy back
  as `popcorn.db`, and deploy the previous image.
- A run in progress when a deploy restarts Popcorn resumes on its own afterwards.
