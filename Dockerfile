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
# 这一步通常会生成 dist 目录
RUN npm run build

# ------------------------------
# 阶段 2: 基础环境 (Base)
# ------------------------------
FROM rust:alpine AS chef
# 安装 musl 编译环境
RUN apk add --no-cache musl-dev pkgconfig openssl-dev
# 安装 cargo-chef
RUN cargo install cargo-chef
WORKDIR /app

# ------------------------------
# 阶段 3: 规划 (Planner)
# ------------------------------
FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

# ------------------------------
# 阶段 4: 烹饪与构建 (Builder)
# ------------------------------
FROM chef AS builder
COPY --from=planner /app/recipe.json recipe.json
# 编译依赖缓存
RUN cargo chef cook --release --recipe-path recipe.json

# 复制真正的后端源代码
COPY . .

# 【修复点 1】：将前端构建产物复制到 Rust 要求的 "public" 目录
# 假设前端构建输出在 dist，我们将其重命名为 public 放到 /app 下
COPY --from=frontend-builder /web_build/dist ./public

# 【修复点 2】：注入 BUILD_TIME 环境变量并编译
# Rust 的 env! 宏需要在编译命令执行时存在该变量
RUN BUILD_TIME=$(date "+%Y-%m-%d %H:%M:%S") cargo build --release

# ------------------------------
# 阶段 5: 运行时镜像 (Runtime)
# ------------------------------
FROM alpine:latest

RUN apk add --no-cache ca-certificates tzdata libgcc

WORKDIR /app

# 复制编译产物
COPY --from=builder /app/target/release/yaolist-backend /app/yaolist
COPY --from=builder /app/config.yaml /app/config.yaml

EXPOSE 8080

RUN chmod +x /app/yaolist
CMD ["./yaolist"]
