# Intel vPro / MeshCommander

Runs MeshCommander in a container so legacy Intel AMT TLS compatibility does not
require changing Fedora's system-wide crypto policy.

## Why this base and configuration

- `node:22-bookworm-slim` uses a supported Node.js LTS line and OpenSSL 3.
- Verified against Intel AMT 16.1 firmware (`16.1.25.2091`). Older AMT
  implementations reject modern clients with `unsafe legacy renegotiation
  disabled`.
- `openssl.cnf` uses Node's required `nodejs_conf` section. It enables TLS 1.0
  as a minimum, security level 0 ciphers, `UnsafeLegacyRenegotiation`, and
  `UnsafeLegacyServerConnect` **only for MeshCommander's Node process**.
- MeshCommander is pinned to npm release `0.9.5-a`; transitive dependencies are
  pinned in `package-lock.json`.

These settings are deliberately insecure for general Internet use. Keep both the
web UI and AMT targets on a trusted management network. The old `ws` dependency
also carries GHSA-96hv-2xvq-fx4p (unauthenticated memory-exhaustion DoS). A
forced upgrade breaks `express-ws`, so the host port must remain bound to
loopback as shown below; do not expose this UI to the LAN or Internet.

## Build and publish

```bash
cd ~/Development/meshcommander
IMAGE=ghcr.io/cuppett/meshcommander:latest
REVISION="$(git rev-parse HEAD)"
podman build \
  --build-arg OCI_REVISION="$REVISION" \
  --annotation "org.opencontainers.image.source=https://github.com/cuppett/meshcommander" \
  --annotation "org.opencontainers.image.revision=$REVISION" \
  --annotation "org.opencontainers.image.title=MeshCommander" \
  --annotation "org.opencontainers.image.description=Containerized MeshCommander with scoped legacy OpenSSL settings for Intel AMT" \
  --annotation "org.opencontainers.image.licenses=Apache-2.0" \
  -t "$IMAGE" .
podman push "$IMAGE"
```

The `org.opencontainers.image.source` OCI annotation links the published package
to `https://github.com/cuppett/meshcommander`.

### CI/CD (AWS)

Continuous builds are handled by the `meshcommander-pipeline-main` CodePipeline
(us-east-1), which builds multi-arch images from this repository's `main`
branch using the [aws-codebuild-podman](https://github.com/cuppett/aws-codebuild-podman)
stacks:

- Source: GitHub `cuppett/meshcommander` branch `main` (CodeStar connection)
- Base image: ECR mirror of `docker.io/library/node:22-bookworm-slim`
  (refreshed by [aws-ecr-mirror](https://github.com/cuppett/aws-ecr-mirror));
  a base image update re-triggers the build
- Output: `771294529343.dkr.ecr.us-east-1.amazonaws.com/meshcommander:main`
- On push, the mirror controller publishes the image to
  `ghcr.io/cuppett/meshcommander` with both `main` and `latest` tags

## Run

### Ad-hoc container

```bash
podman run --rm -it \
  --name meshcommander \
  -p 127.0.0.1:3001:3000 \
  -v ./data:/data:Z \
  ghcr.io/cuppett/meshcommander:main
```

### Systemd Quadlet (persistent service)

The tracked unit is `systemd/meshcommander.container`. Install it to
`~/.config/containers/systemd/meshcommander.container`, then:

```bash
systemctl --user daemon-reload
systemctl --user restart meshcommander.service
systemctl --user status meshcommander.service
journalctl --user -u meshcommander.service -f
```

The unit uses `ghcr.io/cuppett/meshcommander:main`, `AutoUpdate=registry`, and
persists state to `~/container-storage/meshcommander`. A best-effort
`podman pull` runs before each start; registry auto-update can be triggered with:

```bash
podman auto-update
```

Open <http://127.0.0.1:3001> and add your AMT host (e.g. `192.0.2.10` or your
host's LAN IP) as a TLS-enabled AMT target on port `16993`. Host port `3001`
avoids the existing Open WebUI listener on port `3000`.

Treat `~/container-storage/meshcommander` as sensitive: MeshCommander can store
AMT credentials in its configuration.
