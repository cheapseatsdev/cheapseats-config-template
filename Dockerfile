# Your Popcorn: the app, pinned to a release, with this repo as its config. Dependabot opens a pull
# request when a new release is out; review its release notes and the plan in its checks, then
# merge to upgrade.
FROM ghcr.io/metcalfc/popcorn:0.2.0
COPY popcorn.toml /config/popcorn.toml
COPY prompt-sets /config/prompt-sets
# The commit this config came from, recorded on every run (the deploy workflow passes it).
ARG REVISION=""
ENV POPCORN_CONFIG_REV=$REVISION
