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
podman build --build-arg OCI_REVISION="$(git rev-parse HEAD)" -t "$IMAGE" .
podman push "$IMAGE"
```

The `org.opencontainers.image.source` label links the published package to
`https://github.com/cuppett/meshcommander`.

## Run

### Ad-hoc container

```bash
podman run --rm -it \
  --name meshcommander \
  -p 127.0.0.1:3001:3000 \
  -v ./data:/data:Z \
  ghcr.io/cuppett/meshcommander:latest
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

The unit uses `ghcr.io/cuppett/meshcommander:latest`, `AutoUpdate=registry`, and
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
