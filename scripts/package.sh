#!/bin/bash
# Make build/$PACKAGE.txz and build/$PACKAGE.txz.sha256 from build/bin/$BINARY.
# Run it in a Slackware 14.2 container, so that the package matches the pkgtools of Unraid 6.9.2.
set -euo pipefail

. ./plugin.conf

: "${PACKAGE:?}"
install_dir=${INSTALL_DIR:-/usr/local/bin}
bin=build/bin/$BINARY

dist=build/dist
rm -rf "$dist" build/*.txz build/*.sha256
mkdir -p "$dist$install_dir" "$dist/usr/local/emhttp/plugins/$NAME"
install -m 755 "$bin" "$dist$install_dir/$BINARY"
if [ -d usr ]; then
  cp -a usr "$dist/"
fi
cp description.md "$dist/usr/local/emhttp/plugins/$NAME/README.md"

(cd "$dist" && makepkg -l y -c y "../$PACKAGE.txz")
(cd build && sha256sum "$PACKAGE.txz" >"$PACKAGE.txz.sha256")
cat "build/$PACKAGE.txz.sha256"
