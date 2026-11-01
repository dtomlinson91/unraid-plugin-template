#!/bin/bash
# Install build/$PACKAGE.txz, run the binary, then remove the package.
# Run it in a Slackware container.
set -euo pipefail

. ./plugin.conf

: "${PACKAGE:?}" "${VERSION:?}"
install_dir=${INSTALL_DIR:-/usr/local/bin}
bin=$install_dir/$BINARY

cat /etc/slackware-version
installpkg "build/$PACKAGE.txz" >/dev/null
test -e "/var/log/packages/$PACKAGE"

# shellcheck disable=SC2086
output=$("$bin" ${VERSION_ARGS:---version} 2>&1)
echo "$output"
if [ "${VERSION_CHECK:-yes}" = "yes" ]; then
  case $output in
    *"$VERSION"*) ;;
    *)
      echo "error: the output of $BINARY does not contain $VERSION" >&2
      exit 1
      ;;
  esac
fi

if [ -n "${TEST_CMD:-}" ]; then
  bash -c "$TEST_CMD"
fi

removepkg "$PACKAGE" >/dev/null
if [ -e "$bin" ]; then
  echo "error: removepkg did not remove $bin" >&2
  exit 1
fi
echo "ok: $PACKAGE"
