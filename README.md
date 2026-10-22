# Cheap Seats config

What [Cheap Seats](https://cheapseats.dev) asks about your brand, and how it's deployed.
Cheap Seats asks AI assistants the questions your buyers ask and grades whether they recommend you;
this repo is your copy of its config, kept private if you like:

| file | what it is |
| --- | --- |
| [`cheapseats.toml`](cheapseats.toml) | your brand, sites, answerers, grader, budget and schedule |
| [`prompt-sets/`](prompt-sets/) | the buyer questions, one file per category ([format](prompt-sets/README.md)) |
| [`Dockerfile`](Dockerfile) | your Cheap Seats: a pinned release with this config inside |
| [`deploy/`](deploy/) | how it runs: a Docker host or Kubernetes ([guide](deploy/README.md)) |

It starts out measuring Cheap Seats itself, as a working example. Make it yours:

1. **Create your repo** from this template ("Use this template" on GitHub).
2. **Describe your brand** in `cheapseats.toml`: its name and aliases, `about`, `audience`, its sites
   (`[[brand.sites]]`: marketing, docs, blog... with an owner each), and public facts the fix list
   may rely on.
3. **Write your prompt sets.** Replace the examples in `prompt-sets/`, one file per category of
   buyer question, 15–20 questions each, asked the way someone who's never heard of you would.
   Only `head-to-heads` may name you. Every prompt has a permanent id; read the
   [format](prompt-sets/README.md) before you start.
4. **Choose where it runs** and set it up once: [deploy/README.md](deploy/README.md).
5. **Merge to main.** The deploy workflow builds your image and ships it.

## How changes work

Every change is a pull request. Its checks run `cheapseats check` with the Cheap Seats release this repo is
pinned to, and comment a plan: which prompts were added, removed, reworded or moved, which trends
that affects, and how many answers a day the new config asks for. Merging deploys it; runs in
progress when it restarts pick up where they left off.

**Upgrading Cheap Seats** is a pull request too: Dependabot opens one when a release is out, bumping the
`FROM` line in the Dockerfile. Read the release notes, let the checks run against the new version,
and merge. Cheap Seats backs up its database before any schema change and keeps your history.

**Rolling back** is re-running an earlier successful run of the deploy workflow.

To try a change locally, from a checkout of the [app](https://github.com/cheapseatsdev/cheapseats):

```bash
CHEAPSEATS_CONFIG=../your-config/cheapseats.toml go run ./cmd/cheapseats check
go run ./cmd/cheapseats plan <a checkout of main> ../your-config
CHEAPSEATS_CONFIG=../your-config/cheapseats.toml go run ./cmd/cheapseats serve
```
