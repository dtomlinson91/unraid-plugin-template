#!/usr/bin/env bash
# Find the Slackware package of each Unraid base in BASES, and the names of the release.
# Reads plugin.conf in the current directory.
# Writes one line for each base to build/bases.tsv.
# Writes TAG, VERSION, SOURCES, PLUGIN_VERSION and SKIP to $GITHUB_ENV, or to stdout.
set -euo pipefail

. ./plugin.conf

: "${NAME:?}" "${SLACK_PKG:?}" "${BASES:?}"
mirror=${MIRROR:-https://slackware.osuosl.org}
out=${GITHUB_ENV:-/dev/stdout}
force=${INPUT_FORCE:-false}

# unraid compares plugin versions with strcmp, so a date sorts correctly and an upstream version does not
plugin_version=$(date -u +%Y.%m.%d)
if [ -n "${GITHUB_REPOSITORY:-}" ]; then
  base=$plugin_version
  for suffix in "" a b c d e f g h i j k l m n o p q r s t u v w x y z; do
    plugin_version=$base$suffix
    if ! gh release view "$plugin_version" -R "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
      break
    fi
  done
fi

mkdir -p build
: >build/bases.tsv
versions=()
sources=()
for line in "${BASES[@]}"; do
  read -r glob tree glibc image <<<"$line"
  : "${image:?BASES line '$line' needs 4 fields: glob tree glibc image}"
  sums=$(curl -fsSL "$mirror/slackware64-$tree/CHECKSUMS.md5")
  # a package in patches/ replaces the package of the same name in the main tree
  path=$(printf '%s\n' "$sums" | grep -oE "\./patches/packages/$SLACK_PKG-[^-/]+-x86_64-[^-/]+\.txz$" | tail -1 || true)
  if [ -z "$path" ]; then
    path=$(printf '%s\n' "$sums" | grep -oE "\./slackware64/[a-z]+/$SLACK_PKG-[^-/]+-x86_64-[^-/]+\.txz$" | tail -1 || true)
  fi
  if [ -z "$path" ]; then
    echo "error: slackware64-$tree has no $SLACK_PKG package" >&2
    exit 1
  fi
  md5=$(printf '%s\n' "$sums" | awk -v p="$path" '$2 == p && !m {m = $1} END {print m}')
  source=$(basename "$path" .txz)
  version=${source%-x86_64-*}
  version=${version##*-}
  package=$NAME-$version-x86_64-${plugin_version}_$tree
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$glob" "$tree" "$glibc" "$image" "${path#./}" "$md5" "$version" "$package" >>build/bases.tsv
  echo "$glob: slackware64-$tree ${path#./}" >&2
  versions+=("$version")
  sources+=("$source")
done

version=$(printf '%s\n' "${versions[@]}" | awk '!seen[$0]++' | paste -sd+ -)
source_list=${sources[*]}

current=""
if [ -f "$NAME.plg" ]; then
  current=$(sed -nE 's/.*<!ENTITY sources +"([^"]*)".*/\1/p' "$NAME.plg")
fi

skip=false
if [ "$source_list" = "$current" ] && [ "$force" != "true" ]; then
  echo "$NAME already has $source_list. Set force to build it again." >&2
  skip=true
fi

{
  echo "TAG=$version"
  echo "VERSION=$version"
  echo "SOURCES=$source_list"
  echo "PLUGIN_VERSION=$plugin_version"
  echo "SKIP=$skip"
} >>"$out"
