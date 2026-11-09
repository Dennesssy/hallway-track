# syntax=docker/dockerfile:1
FROM swift:6.4-noble AS build
RUN apt-get update && apt-get install -y --no-install-recommends libjemalloc-dev make curl ca-certificates && rm -rf /var/lib/apt/lists/*

# GRDB on Linux needs the sqlite3_snapshot_* functions, which Ubuntu's SQLite
# (3.45.1) is built without. Build SQLite from the official source with
# snapshots enabled and link it statically.
ARG SQLITE_URL=https://sqlite.org/2026/sqlite-autoconf-3540100.tar.gz
ARG SQLITE_SHA256=926ef8d3eab93fbf6e06011901273eec076b25594a4e1cdadd50c987f4f6d64e
RUN ln -s "$(command -v clang)" /usr/local/bin/cc \
 && curl -fsSL -o /tmp/sqlite.tgz "$SQLITE_URL" \
 && echo "$SQLITE_SHA256  /tmp/sqlite.tgz" | sha256sum -c - \
 && tar -xzf /tmp/sqlite.tgz -C /tmp && cd /tmp/sqlite-autoconf-* \
 && ./configure --prefix=/opt/sqlite --disable-shared --enable-static \
      CFLAGS="-O2 -DSQLITE_ENABLE_SNAPSHOT -DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_PREUPDATE_HOOK -DSQLITE_ENABLE_SESSION" \
 && make -j2 && make install && rm -rf /tmp/sqlite*

WORKDIR /build
COPY Package.swift Package.resolved ./
RUN swift package resolve
COPY Sources ./Sources
RUN swift build -c release --static-swift-stdlib -Xcc -I/opt/sqlite/include -Xlinker -L/opt/sqlite/lib -Xlinker -ljemalloc -j 2
RUN mkdir /stage && cp "$(swift build -c release --show-bin-path)/iaiperk" /stage/

FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends libjemalloc2 ca-certificates tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home --home-dir /app --shell /usr/sbin/nologin iaiperk \
    && mkdir /data && chown iaiperk /data
WORKDIR /app
COPY --from=build /stage/iaiperk ./iaiperk
COPY Public ./Public
COPY SeedData ./SeedData
USER iaiperk
ENV IAIPERK_DB=/data/iaiperk.sqlite
VOLUME /data
EXPOSE 8090
ENTRYPOINT ["./iaiperk"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8090"]
