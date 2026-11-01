#!/bin/bash
# Install the package of base TREE, run BINARY, then remove the package.
# Run it in the Slackware container of that base.
# usage: test.sh TREE
set -euo pipefail

. ./plugin.conf

tree=${1:?usage: test.sh TREE}
line=$(awk -F'\t' -v t="$tree" '$2 == t' build/bases.tsv)
version=$(printf '%s' "$line" | cut -f7)
package=$(printf '%s' "$line" | cut -f8)
: "${package:?no base $tree in build/bases.tsv}"

cat /etc/slackware-version
installpkg "build/$package.txz" >/dev/null
test -e "/var/log/packages/$package"

# shellcheck disable=SC2086
output=$("$BINARY" ${VERSION_ARGS:---version} 2>&1)
echo "$output"
case $output in
  *"$version"*) ;;
  *)
    echo "error: the output of $BINARY does not contain $version" >&2
    exit 1
    ;;
esac

if [ -n "${TEST_CMD:-}" ]; then
  bash -c "$TEST_CMD"
fi

removepkg "$package" >/dev/null
if [ -e "$BINARY" ]; then
  echo "error: removepkg did not remove $BINARY" >&2
  exit 1
fi
echo "ok: $package"
