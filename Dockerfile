# 多阶段构建 Dockerfile for CLI Proxy API Management Center
# 阶段 1: 构建阶段
FROM node:18-alpine AS builder

# 设置工作目录
WORKDIR /app

# 复制 package.json 和 package-lock.json（如果存在）
COPY package*.json ./

# 安装依赖（仅生产依赖不够，需要 devDependencies 中的 serve）
RUN npm ci

# 复制所有源代码
COPY . .

# 执行构建，生成 dist/index.html
RUN npm run build

# 阶段 2: 运行阶段
FROM nginx:alpine

# 复制自定义 nginx 配置
COPY --from=builder /app/dist/index.html /usr/share/nginx/html/index.html

# 创建 nginx 配置文件以支持 SPA 路由
RUN echo 'server { \
    listen 80; \
    server_name localhost; \
    root /usr/share/nginx/html; \
    index index.html; \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
    # 启用 gzip 压缩 \
    gzip on; \
    gzip_types text/html text/css application/javascript application/json; \
    gzip_min_length 1000; \
    # 缓存静态资源 \
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ { \
        expires 1y; \
        add_header Cache-Control "public, immutable"; \
    } \
}' > /etc/nginx/conf.d/default.conf

# 暴露端口
EXPOSE 80

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

# 启动 nginx
CMD ["nginx", "-g", "daemon off;"]
