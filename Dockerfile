# ------------------------------
# 阶段 1: 构建前端 (React/Node.js)
# ------------------------------
FROM node:18-alpine AS frontend-builder
WORKDIR /web_build
COPY web/package*.json ./
RUN npm install
COPY web/ .
RUN npm run build

# ------------------------------
# 阶段 2: 基础环境 (Base) - 安装 cargo-chef
# ------------------------------
FROM rust:alpine AS chef
# 安装 musl 编译环境 (Alpine 编译 Rust 必须)
RUN apk add --no-cache musl-dev pkgconfig openssl-dev
# 安装 cargo-chef 工具
RUN cargo install cargo-chef
WORKDIR /app

# ------------------------------
# 阶段 3: 规划 (Planner)
# ------------------------------
FROM chef AS planner
COPY . .
# 这一步只分析 Cargo.toml/lock，生成 recipe.json (配方文件)
RUN cargo chef prepare --recipe-path recipe.json

# ------------------------------
# 阶段 4: 烹饪与构建 (Builder)
# ------------------------------
FROM chef AS builder
COPY --from=planner /app/recipe.json recipe.json

# 【核心步骤】利用配方文件构建依赖缓存
# cargo-chef 会自动识别这里需要 lib.rs 还是 main.rs 并自动创建
RUN cargo chef cook --release --recipe-path recipe.json

# 依赖编译完了，现在复制真正的源代码
COPY . .

# 编译正式二进制文件
RUN cargo build --release

# ------------------------------
# 阶段 5: 运行时镜像 (Runtime)
# ------------------------------
FROM alpine:latest

# 安装运行时必要依赖
RUN apk add --no-cache ca-certificates tzdata libgcc

WORKDIR /app

# 复制编译产物
# ⚠️ 注意：请再次确认 Cargo.toml 中的 name。这里假设是 yaolist-backend 或 yaolist
# 如果不确定名字，建议先用 COPY --from=builder /app/target/release/ /app/temp/ 进去看一眼
# 或者这里直接复制整个 release 目录下的文件（比较暴力但有效）
COPY --from=builder /app/target/release/yaolist /app/yaolist
COPY --from=builder /app/config.yaml /app/config.yaml

EXPOSE 8080

RUN chmod +x /app/yaolist
CMD ["./yaolist"]
