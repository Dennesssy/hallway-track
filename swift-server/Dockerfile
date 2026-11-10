# syntax=docker/dockerfile:1
# Hallway Track — conference session search (PerksMix Swift starter).
# Build context: repository root (Public/ and data/ live outside swift-server/).
#   docker build -f swift-server/Dockerfile -t hallway-track .
# Builds two binaries: hallway-track (server) and hallway-index (ES indexer job).
FROM swift:6.4-noble AS build
RUN apt-get update && apt-get install -y --no-install-recommends libjemalloc-dev make ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY swift-server/Package.swift swift-server/Package.resolved ./
RUN swift package resolve
COPY swift-server/Sources ./Sources
COPY swift-server/Tests ./Tests
RUN swift build -c release --static-swift-stdlib -j 2
RUN mkdir /stage \
    && cp "$(swift build -c release --show-bin-path)/hallway-track" /stage/ \
    && cp "$(swift build -c release --show-bin-path)/hallway-index" /stage/
FROM ubuntu:24.04
RUN apt-get update \
    && apt-get install -y --no-install-recommends libjemalloc2 ca-certificates tzdata curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home --home-dir /app --shell /usr/sbin/nologin hallway \
    && mkdir -p /app/data && chown hallway /app/data
WORKDIR /app
COPY --from=build /stage/hallway-track ./hallway-track
COPY --from=build /stage/hallway-index ./hallway-index
COPY swift-server/Public ./Public
COPY data/sessions.json ./data/sessions.json
USER hallway
ENV PORT=8080 \
    HOST=0.0.0.0 \
    PUBLIC_DIR=/app/Public \
    SESSIONS_JSON=/app/data/sessions.json
EXPOSE 8080
ENTRYPOINT ["/app/hallway-track"]
