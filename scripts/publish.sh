#!/usr/bin/env bash
# Commit $NAME.plg, tag it as $PLUGIN_VERSION, create the GitHub release, then push the default branch.
set -euo pipefail

. ./plugin.conf

: "${PLUGIN_VERSION:?}" "${VERSION:?}" "${TAG:?}" "${GITHUB_REPOSITORY:?}"
# ASSETS is a space-separated list of release files. Without it, the release holds the one package.
if [ -z "${ASSETS:-}" ]; then
  : "${PACKAGE:?}"
  ASSETS="build/$PACKAGE.txz build/$PACKAGE.txz.sha256"
fi
branch=$(gh repo view "$GITHUB_REPOSITORY" --json defaultBranchRef --jq .defaultBranchRef.name)
if [ "${GITHUB_REF_NAME:-}" != "$branch" ]; then
  echo "error: run the release from $branch, not from ${GITHUB_REF_NAME:-}" >&2
  exit 1
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add "$NAME.plg"
git commit -q -m "chore: release $TITLE $VERSION"
git tag "$PLUGIN_VERSION"

# the tag goes first, so that the default branch never points to a release that does not exist
git push -q origin "refs/tags/$PLUGIN_VERSION"
upstream_url=${UPSTREAM_URL:-https://github.com/$UPSTREAM/releases/tag/$TAG}
# shellcheck disable=SC2086
gh release create "$PLUGIN_VERSION" \
  $ASSETS \
  --verify-tag \
  --title "$TITLE $VERSION" \
  --notes "$TITLE $VERSION: $upstream_url"
git push -q origin "HEAD:$branch"
echo "released $PLUGIN_VERSION: $TITLE $VERSION"
