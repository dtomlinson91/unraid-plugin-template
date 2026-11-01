#!/usr/bin/env bash
# Download the Slackware package of each base in build/bases.tsv to build/dl/<tree>/.
# Checks the md5 from CHECKSUMS.md5 and the Slackware GPG signature. Then makes sure that no
# ELF file in the package needs a newer glibc than the Unraid base has.
# Needs curl, gpg, readelf and tar with xz.
set -euo pipefail

. ./plugin.conf

mirror=${MIRROR:-https://slackware.osuosl.org}
# the Slackware Linux Project signing key, security@slackware.com
key_fpr=EC5649DA401E22ABFA6736EF6A4463C040102233

rm -rf build/dl build/x
mkdir -p build/dl build/x

GNUPGHOME=$(mktemp -d)
export GNUPGHOME
trap 'rm -rf "$GNUPGHOME"' EXIT

while IFS=$'\t' read -r glob tree glibc _image path md5 _version _package; do
  dir=build/dl/$tree
  mkdir -p "$dir"
  file=$dir/$(basename "$path")
  url=$mirror/slackware64-$tree/$path
  curl -fsSL -o "$file" "$url"
  curl -fsSL -o "$file.asc" "$url.asc"

  if [ "$(md5sum "$file" | cut -d' ' -f1)" != "$md5" ]; then
    echo "error: the md5 of $(basename "$file") does not match CHECKSUMS.md5" >&2
    exit 1
  fi

  if [ ! -s "$GNUPGHOME/key.done" ]; then
    curl -fsSL -o "$GNUPGHOME/GPG-KEY" "$mirror/slackware64-$tree/GPG-KEY"
    gpg --batch --quiet --import "$GNUPGHOME/GPG-KEY" 2>/dev/null
    fpr=$(gpg --batch --with-colons --fingerprint | awk -F: '/^fpr:/ {print $10; exit}')
    if [ "$fpr" != "$key_fpr" ]; then
      echo "error: the GPG key from $mirror has fingerprint $fpr, not $key_fpr" >&2
      exit 1
    fi
    echo "$fpr" >"$GNUPGHOME/key.done"
  fi
  if ! gpg --batch --quiet --trusted-key "${key_fpr: -16}" --verify "$file.asc" "$file" 2>"$dir/gpg.log"; then
    cat "$dir/gpg.log" >&2
    echo "error: the GPG signature of $(basename "$file") is not good" >&2
    exit 1
  fi

  x=build/x/$tree
  mkdir -p "$x"
  tar -xJf "$file" -C "$x"
  need=$(find "$x" -type f -print0 |
    xargs -0 -r -n 50 readelf -W -V 2>/dev/null |
    grep -oE 'GLIBC_[0-9]+(\.[0-9]+)+' | sed 's/^GLIBC_//' | sort -uV | tail -1 || true)
  if [ -n "$need" ] && [ "$(printf '%s\n%s\n' "$need" "$glibc" | sort -V | tail -1)" != "$glibc" ]; then
    echo "error: $(basename "$file") needs glibc $need. Unraid $glob has glibc $glibc." >&2
    exit 1
  fi
  echo "$glob: $(basename "$file") is signed and needs glibc ${need:-none} (base has $glibc)"
done <build/bases.tsv
