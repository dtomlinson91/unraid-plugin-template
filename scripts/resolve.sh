#!/usr/bin/env bash
# Find the upstream version to build and the names of the release.
# Reads plugin.conf in the current directory.
# Writes TAG, VERSION, PLUGIN_VERSION, PACKAGE and SKIP to $GITHUB_ENV, or to stdout.
set -euo pipefail

. ./plugin.conf

out=${GITHUB_ENV:-/dev/stdout}
input_version=${INPUT_VERSION:-}
force=${INPUT_FORCE:-false}

if [ -n "$input_version" ]; then
  tag=$input_version
elif [ -n "${LATEST_CMD:-}" ]; then
  tag=$(bash -c "$LATEST_CMD")
else
  tag=$(gh release view -R "$UPSTREAM" --json tagName --jq .tagName)
fi

version=${tag#v}
if ! printf '%s' "$version" | grep -Eq '^[0-9][0-9A-Za-z.+_]*$'; then
  echo "error: upstream version '$version' (tag '$tag') is not a valid Slackware package version" >&2
  exit 1
fi

current=""
if [ -f "$NAME.plg" ]; then
  current=$(sed -nE 's/.*<!ENTITY upstream +"([^"]*)".*/\1/p' "$NAME.plg")
fi

skip=false
if [ "$version" = "$current" ] && [ "$force" != "true" ]; then
  echo "$NAME already has $TITLE $version. Set force to build it again." >&2
  skip=true
fi

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

package=$NAME-$version-x86_64-$plugin_version

{
  echo "TAG=$tag"
  echo "VERSION=$version"
  echo "PLUGIN_VERSION=$plugin_version"
  echo "PACKAGE=$package"
  echo "SKIP=$skip"
} >>"$out"
