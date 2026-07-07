FROM node:22-alpine AS base
WORKDIR /app

COPY package.json package-lock.json ./
COPY services/api/package.json services/api/package.json
COPY packages/shared/package.json packages/shared/package.json
COPY services/worker/package.json services/worker/package.json
RUN npm ci

COPY . .
RUN npm --workspace packages/shared run build
RUN npm --workspace services/api run build

EXPOSE 3000
CMD ["npm", "--workspace", "services/api", "run", "start"]
