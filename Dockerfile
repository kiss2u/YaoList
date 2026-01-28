# ------------------------------
# 阶段 1: 构建前端 (React/Node.js)
# ------------------------------
FROM node:18-alpine AS frontend-builder
WORKDIR /web_build
# 复制 package 文件
COPY web/package*.json ./
# 安装依赖
RUN npm install
# 复制源码并构建
COPY web/ .
RUN npm run build

# ------------------------------
# 阶段 2: 构建后端 (Rust + Alpine)
# ------------------------------
# 使用 rust:alpine 镜像，自动处理 musl 编译
FROM rust:alpine AS backend-builder
WORKDIR /app

# 安装 musl 编译所需的 C 库和 OpenSSL 开发包
# alpine 下编译通常需要 musl-dev, pkgconfig, openssl-dev
RUN apk add --no-cache musl-dev pkgconfig openssl-dev

# 复制 Cargo.toml (去掉 Cargo.lock 因为之前报错说没有)
COPY Cargo.toml ./

# 预编译依赖层
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -rf src

# 复制源码
COPY . .

# 编译正式二进制文件
# 注意：在 rust:alpine 中，target 默认就是 x86_64-unknown-linux-musl
RUN cargo build --release

# ------------------------------
# 阶段 3: 最终运行时镜像 (Alpine)
# ------------------------------
FROM alpine:latest

# 安装运行时必要依赖
# ca-certificates: 用于 HTTPS 请求
# tzdata: 用于设置时区
# libgcc: 某些 Rust 二进制需要
RUN apk add --no-cache ca-certificates tzdata libgcc

WORKDIR /app

# 从构建阶段复制二进制文件
# 注意：路径和名字需要根据 Cargo.toml 确认，这里假设是 yaolist
COPY --from=backend-builder /app/target/release/yaolist /app/yaolist
COPY --from=backend-builder /app/config.yaml /app/config.yaml

# 暴露端口
EXPOSE 8080

# 赋予执行权限并启动
RUN chmod +x /app/yaolist
CMD ["./yaolist"]
