# Your Cheap Seats: the app, pinned to a release, with this repo as its config. Dependabot opens a pull
# request when a new release is out; review its release notes and the plan in its checks, then
# merge to upgrade. The digest pins the exact image, so a re-pushed tag can't change what you run;
# Dependabot updates the tag and the digest together.
FROM ghcr.io/cheapseatsdev/cheapseats:0.5.5@sha256:8e48380c078ca8265cb1df7bf84c010ebb63d3390613b15d2d3ceb514772d8c8
COPY cheapseats.toml /config/cheapseats.toml
COPY prompt-sets /config/prompt-sets
# The commit this config came from, recorded on every run (the deploy workflow passes it).
ARG REVISION=""
ENV CHEAPSEATS_CONFIG_REV=$REVISION
