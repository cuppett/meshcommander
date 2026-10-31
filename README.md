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

## Build

```bash
cd ~/Development/vpro
podman build -t localhost/vpro-meshcommander:latest .
```

## Run

```bash
podman run --rm -it \
  --name vpro-meshcommander \
  -p 127.0.0.1:3001:3000 \
  localhost/vpro-meshcommander:latest
```

Open <http://127.0.0.1:3001> and add your AMT host (e.g. `192.0.2.10` or your
host's LAN IP) as a TLS-enabled AMT target on port `16993`. Stop the container
with Ctrl-C. Host port `3001` avoids the existing Open WebUI listener on port
`3000`.

To persist MeshCommander state, create `data/` and add
`-v ./data:/data:Z` to the run command. Treat that directory as sensitive:
MeshCommander can store AMT credentials in its configuration.
