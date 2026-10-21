#!/bin/sh
set -eu

# Pin the published browser bundle so asset refreshes are reproducible.
version=3.1.2
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

npm pack "@jocmp/mercury-parser@$version" --ignore-scripts \
    --cache "$tmp/cache" --pack-destination "$tmp" --quiet > /dev/null
tar -xzf "$tmp/jocmp-mercury-parser-$version.tgz" -C "$tmp" \
    package/dist/mercury.web.js
node "$root/tool/prepare_mercury.cjs" "$tmp/package/dist/mercury.web.js" "$tmp/mercury.web.js"
cp "$tmp/mercury.web.js" "$root/assets/article/mercury.web.js"
echo "Updated Mercury Parser to @jocmp/mercury-parser@$version"
