# Base image stages (pinnable by Renovate)
FROM stagex/core-ca-certificates@sha256:6f1b69f013287af74340668d7a6f14de8ff5555e60e7c4ef1a643a78ed1629bd AS certs
FROM stagex/core-busybox@sha256:4f3e3849acb54972e7c4f1d08c320526e0f8b314130bda68f83f821b02b4890b AS busybox
FROM stagex/core-git@sha256:441316b17e020eb28d31ccaec2197d61646519bb564da8af3e5eea7642363034 AS git
FROM stagex/core-musl@sha256:fe241a40ee103f34e8e2bc5054de9bf67ffe00593d7412b6d61e6d2795425f7c AS musl
FROM stagex/core-curl@sha256:d5874b8e4f2d9ea8db605fadada528dbe40c91840483d119b50a8929afcdf5cf AS curl
FROM stagex/core-openssl@sha256:a42aaff7895410d7823913e27c680b6b85ce2cb91489a5f4c875fa17e5d0aa5b AS openssl
FROM stagex/core-zlib@sha256:7d9dbe4ca873b75f3c7c8e35105f8d273db66a179e9678704c0510dc441ae4ca AS zlib
FROM stagex/core-libzstd@sha256:c6ff15d1b2cf240d68c42c0614b675b60b9a0943b92ac326d3866d87af7d18fb AS libzstd
FROM stagex/core-pcre2@sha256:8c0366b911cf99265e713f2f387931dcdb47cb547993f34e27750e3a3bf23ffc AS pcre2
FROM stagex/pallet-go@sha256:4398836d191a062d7d6afcb359ec8d574c50481b5a48c3048bd0ec05cb8d2db6 AS pallet-go

# Build stage: clone trust-manager and build the copier binary
FROM pallet-go AS build
COPY --from=busybox . /
COPY --from=certs . /
COPY --from=git . /
COPY --from=musl . /
COPY --from=curl . /
COPY --from=openssl . /
COPY --from=zlib . /
COPY --from=libzstd . /
COPY --from=pcre2 . /

ENV CGO_ENABLED=0
ENV GOOS=linux
ENV GOARCH=amd64
ENV GOPATH=/cache/go
ENV GOCACHE=/cache/go-cache
ENV TRUST_MANAGER_DIGEST=5dbfc12bb5af40089428f3fb5046ea727ea64048

# Pin to v0.22.0 by tag + verify commit SHA for reproducibility
RUN git clone --depth=1 --branch v0.22.0 https://github.com/cert-manager/trust-manager /src && \
    cd /src && test "$(git rev-parse HEAD)" = "${TRUST_MANAGER_DIGEST}"

WORKDIR /src/trust-packages/debian
RUN go build -trimpath -ldflags="-buildid=" -o /stagex-bundle-static .

# Bundle stage: generate the JSON package from stagex certs
FROM busybox AS bundler

COPY --from=certs /etc/ssl/certs/ca-certificates.crt /tmp/ca-certificates.crt

ARG VERSION=sx2026.03.0
ARG NAME=trust-pkg-stagex

RUN mkdir -p /tmp/stagex-package && \
    printf '{"name":"%s","version":"%s","bundle":"%s"}\n' \
      "$NAME" \
      "$VERSION" \
      "$(cat /tmp/ca-certificates.crt | sed 's/"/\\"/g' | tr '\n' '§' | sed 's/§/\\n/g')" \
      > /tmp/stagex-package/cert-manager-package-stagex.json

# Final stage
FROM scratch
COPY --from=build /stagex-bundle-static /ko-app/stagex-bundle-static
COPY --from=bundler /tmp/stagex-package /stagex-package
USER 65532
ENTRYPOINT ["/ko-app/stagex-bundle-static"]
