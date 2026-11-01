#!/usr/bin/env bash
# Get the binary for TAG and VERSION, and put it at build/bin/$BINARY.
# SOURCE in plugin.conf selects the method: asset (a GitHub release asset), url or cargo.
set -euo pipefail

. ./plugin.conf

: "${TAG:?}" "${VERSION:?}"
source_type=${SOURCE:-asset}
binary_src=${BINARY_SRC:-$BINARY}

expand() {
  printf '%s' "$1" | sed -e "s|{tag}|$TAG|g" -e "s|{version}|$VERSION|g"
}

rm -rf build/dl build/x build/src build/bin
mkdir -p build/dl build/x build/bin

case $source_type in
  asset)
    asset=$(expand "$ASSET")
    gh release download "$TAG" -R "$UPSTREAM" -p "$asset" -D build/dl
    file=build/dl/$asset
    ;;
  url)
    url=$(expand "$URL")
    file=build/dl/$(basename "$url")
    curl -fsSL -o "$file" "$url"
    ;;
  cargo)
    target=x86_64-unknown-linux-musl
    # crates with vendored C code need musl-gcc for the musl target
    if [ -n "${CI:-}" ] && ! command -v musl-gcc >/dev/null; then
      sudo apt-get update -q
      sudo apt-get install -y -q musl-tools
    fi
    git clone -q --depth 1 --branch "$TAG" "https://github.com/$UPSTREAM.git" build/src
    rustup target add "$target"
    (cd build/src && cargo build --release --locked --target "$target" ${CARGO_ARGS:-})
    file=build/src/target/$target/release/$binary_src
    ;;
  *)
    echo "error: unknown SOURCE '$source_type'" >&2
    exit 1
    ;;
esac

case $file in
  *.tar.gz | *.tgz | *.tar.xz | *.tar.bz2)
    tar -xf "$file" -C build/x
    ;;
  *.zip)
    unzip -q "$file" -d build/x
    ;;
  *.gz)
    gunzip -c "$file" >build/x/"$binary_src"
    ;;
  *)
    cp "$file" build/x/"$binary_src"
    ;;
esac

matches=$(find build/x -type f -name "$binary_src")
count=$(printf '%s\n' "$matches" | grep -c . || true)
if [ "$count" -ne 1 ]; then
  echo "error: found $count files named '$binary_src' in $(basename "$file")" >&2
  find build/x -type f >&2
  exit 1
fi

bin=build/bin/$BINARY
cp "$matches" "$bin"
chmod 755 "$bin"

# file 5.36 in Slackware 14.2 reports a static-pie binary as dynamically linked, so check here
info=$(file -b "$bin")
echo "$BINARY: $info"
case $info in
  *ELF\ 64-bit*x86-64*) ;;
  *)
    echo "error: $BINARY is not an x86-64 ELF binary" >&2
    exit 1
    ;;
esac
if [ "${STATIC:-yes}" = "yes" ]; then
  case $info in
    *"statically linked"* | *"static-pie linked"*) ;;
    *)
      echo "error: $BINARY is not a static binary. Set STATIC=no in plugin.conf to allow it." >&2
      exit 1
      ;;
  esac
fi
