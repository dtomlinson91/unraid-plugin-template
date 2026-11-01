#!/bin/bash
# Make build/<package>.txz and its .sha256 for each base in build/bases.tsv.
# Each package holds the files and install script of the Slackware package, plus the README
# for the Plugins page. Run it in a Slackware container.
set -euo pipefail

. ./plugin.conf

rm -rf build/dist build/*.txz build/*.sha256
while IFS=$'\t' read -r _glob tree _glibc _image path _md5 _version package; do
  dist=build/dist/$tree
  mkdir -p "$dist"
  (cd "$dist" && explodepkg "../../dl/$tree/$(basename "$path")" >/dev/null)
  mkdir -p "$dist/usr/local/emhttp/plugins/$NAME"
  cp description.md "$dist/usr/local/emhttp/plugins/$NAME/README.md"
  if ! (cd "$dist" && makepkg -l y -c n "../../$package.txz" >"../makepkg-$tree.log" 2>&1); then
    cat "build/dist/makepkg-$tree.log" >&2
    exit 1
  fi
  (cd build && sha256sum "$package.txz" >"$package.txz.sha256")
  cat "build/$package.txz.sha256"
done <build/bases.tsv
