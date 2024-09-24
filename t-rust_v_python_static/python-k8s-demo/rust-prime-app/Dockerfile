FROM rust:1.72-alpine as builder
RUN apk add --no-cache musl-dev
WORKDIR /usr/src/app
COPY . .
RUN cargo build --release

FROM alpine:latest
COPY --from=builder /usr/src/app/target/release/rust-prime-app /usr/local/bin/rust-prime-app
CMD ["rust-prime-app"]
