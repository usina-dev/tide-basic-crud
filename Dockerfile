FROM rust:1.47 AS planner
WORKDIR /app
# We only pay the installation cost once,
# it will be cached from the second build onwards
# To ensure a reproducible build consider pinning
# the cargo-chef version with `--version X.X.X`
RUN cargo install cargo-chef
COPY . .
# Compute a lock-like file for our project
RUN cargo chef prepare  --recipe-path recipe.json

FROM rust:1.47 AS cacher
WORKDIR /app
RUN cargo install cargo-chef
COPY --from=planner /app/recipe.json recipe.json
# Build our project dependencies, not our application!
RUN cargo chef cook --release --recipe-path recipe.json

FROM rust:1.47 AS builder
WORKDIR /app
# Copy over the cached dependencies
COPY --from=cacher /app/target target
COPY --from=cacher /usr/local/cargo /usr/local/cargo
COPY . .
# Build our application, leveraging the cached deps!
ENV SQLX_OFFLINE true
RUN cargo build --release --bin tide-basic-crud

FROM debian:buster-slim AS runtime
WORKDIR /app
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends openssl \
    # Clean up
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/tide-basic-crud tide-basic-crud

EXPOSE 9090

ENTRYPOINT ["./tide-basic-crud"]



# # build stage
# FROM rust:latest as cargo-build

# RUN apt-get update && apt-get install musl-tools -y
# RUN rustup target add x86_64-unknown-linux-musl

# WORKDIR /usr/src/app
# COPY . .

# RUN RUSTFLAGS=-Clinker=musl-gcc cargo build --release --target=x86_64-unknown-linux-musl

# ###################
# # final stage
# FROM alpine:latest

# RUN addgroup -g 1000 app
# RUN adduser -D -s /bin/sh -u 1000 -G app app

# WORKDIR /home/app/bin/
# COPY --from=cargo-build /usr/src/app/target/x86_64-unknown-linux-musl/release/tide-basic-crud .

# RUN chown app:app tide-basic-crud
# USER app

# EXPOSE 9090

# CMD ["./tide-basic-crud"]