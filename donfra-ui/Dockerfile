# syntax=docker/dockerfile:1.6

# ===== deps/build =====
FROM node:20-alpine AS build
WORKDIR /app

# Build-time env for Next (pass via --build-arg or compose build args)
ARG NEXT_PUBLIC_API_BASE_URL
ENV NEXT_PUBLIC_API_BASE_URL=${NEXT_PUBLIC_API_BASE_URL}

COPY package.json ./
RUN npm install

COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production
RUN npm run build

# ===== serve =====
FROM nginx:alpine
WORKDIR /usr/share/nginx/html

# 1. 拷贝静态站点
COPY --from=build /app/out ./

# 2. 删掉默认站点配置，避免和我们自己的 nginx.conf 冲突
RUN rm /etc/nginx/conf.d/default.conf

# 3. 拷贝你自己的 nginx.conf
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
