FROM node:22-alpine AS development

ENV NODE_ENV=development

WORKDIR /app

COPY package.json /app/package.json
COPY package-lock.json /app/package-lock.json

RUN npm ci

FROM node:22-alpine AS test

ENV NODE_ENV=development

WORKDIR /app

COPY --from=development /app/node_modules /app/node_modules
COPY --from=development /app/package.json /app/package.json
COPY --from=development /app/package-lock.json /app/package-lock.json

COPY src /app/src
COPY tsconfig.json /app/tsconfig.json
COPY tsconfig.build.json /app/tsconfig.build.json
COPY .mocha.entry.js /app/.mocha.entry.js
COPY .mocharc.json /app/.mocharc.json
COPY .c8rc.json /app/.c8rc.json

CMD ["npm", "run", "cover"]


FROM development AS build

ENV NODE_ENV=development

WORKDIR /app

COPY src /app/src
COPY package.json /app/package.json
COPY tsconfig.json /app/tsconfig.json
COPY tsconfig.build.json /app/tsconfig.build.json

RUN npm run build

FROM node:22-alpine AS production

ENV NODE_ENV=production
EXPOSE 3000

WORKDIR /app

COPY --from=build /app/dist /app/dist
COPY --from=development /app/package.json /app/package.json
COPY --from=development /app/package-lock.json /app/package-lock.json

RUN npm install --omit=dev

RUN chown -R node:node /app
USER node

HEALTHCHECK --interval=10s --timeout=30s --start-period=5s --retries=3 \
    CMD ["node", "dist/scripts/healthcheck.js"]

CMD ["node", "dist/index.js"]