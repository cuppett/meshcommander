FROM docker.io/node:22-bookworm-slim

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
