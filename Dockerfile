# Your Cheap Seats: the app, pinned to a release, with this repo as its config. Dependabot opens a pull
# request when a new release is out; review its release notes and the plan in its checks, then
# merge to upgrade. The digest pins the exact image, so a re-pushed tag can't change what you run;
# Dependabot updates the tag and the digest together.
FROM ghcr.io/cheapseatsdev/cheapseats:0.3.0@sha256:7c86a8ce03d444c65e15b7187c5adce11f8a78a82379e519cb2cea9bb3f3e97f
COPY cheapseats.toml /config/cheapseats.toml
COPY prompt-sets /config/prompt-sets
# The commit this config came from, recorded on every run (the deploy workflow passes it).
ARG REVISION=""
ENV CHEAPSEATS_CONFIG_REV=$REVISION
