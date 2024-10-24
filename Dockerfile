FROM docker.io/library/node:20-bookworm AS builder
LABEL maintainer="Kwangil Ha <kwangil77@hotmail.com>"
ENV PYTHON /usr/bin/python3
WORKDIR /src
COPY . .
RUN apt update \
    && apt install -y librust-pangocairo-dev \
    && corepack enable \
    && yarn install \
    && yarn tsc \
    && yarn build:backend \
    && mkdir packages/backend/dist/skeleton packages/backend/dist/bundle \
    && tar xzf packages/backend/dist/skeleton.tar.gz -C packages/backend/dist/skeleton \
    && tar xzf packages/backend/dist/bundle.tar.gz -C packages/backend/dist/bundle \
    && rm -rf /var/lib/apt/lists/*

FROM docker.io/library/node:20-bookworm AS nodejs
LABEL maintainer="Kwangil Ha <kwangil77@hotmail.com>"
ENV PYTHON /usr/bin/python3
WORKDIR /src
COPY --from=builder /src/.yarnrc.yml /src/packages/backend/dist/skeleton/ /src/packages/backend/dist/bundle/ ./
COPY --from=builder /src/.yarn ./.yarn
RUN corepack enable \
    && yarn workspaces focus --all --production \
    && rm -rf "$(yarn cache clean)"

FROM docker.io/library/node:20-bookworm-slim
LABEL maintainer="Kwangil Ha <kwangil77@hotmail.com>"
ENV NODE_ENV production
USER node
WORKDIR /src
COPY --from=builder --chown=node:node /src/app-config.yaml /src/app-config.production.yaml /src/packages/backend/dist/skeleton/ /src/packages/backend/dist/bundle/ ./
COPY --from=nodejs --chown=node:node /src/.yarn ./.yarn
COPY --from=nodejs --chown=node:node /src/.yarnrc.yml  ./
COPY --from=nodejs --chown=node:node /src/node_modules ./node_modules
CMD ["node", "packages/backend", "--config", "app-config.yaml", "--config", "app-config.production.yaml"]