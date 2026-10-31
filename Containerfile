FROM docker.io/node:22-bookworm-slim

ARG OCI_REVISION=unknown

LABEL org.opencontainers.image.title="MeshCommander"
LABEL org.opencontainers.image.description="Containerized MeshCommander with scoped legacy OpenSSL settings for Intel AMT"
LABEL org.opencontainers.image.source="https://github.com/cuppett/meshcommander"
LABEL org.opencontainers.image.revision="${OCI_REVISION}"
LABEL org.opencontainers.image.licenses="Apache-2.0"

ENV NODE_ENV=production

WORKDIR /opt/meshcommander
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts \
    && npm cache clean --force \
    && mkdir /data \
    && chown node:node /data

COPY openssl.cnf /etc/vpro/openssl.cnf

USER node
WORKDIR /data
EXPOSE 3000

ENTRYPOINT ["node", "--openssl-config=/etc/vpro/openssl.cnf", "--tls-min-v1.0", "/opt/meshcommander/node_modules/meshcommander/"]
CMD ["--debug", "--any"]
