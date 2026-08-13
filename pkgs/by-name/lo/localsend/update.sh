#! /usr/bin/env nix-shell
#! nix-shell -I nixpkgs=./. -i bash -p curl gnused jq yq nix nix-update

set -eou pipefail

ROOT="$(dirname "$(readlink -f "$0")")"

latestVersion=$(curl --fail --silent https://api.github.com/repos/localsend/localsend/releases/latest | jq --raw-output .tag_name | sed 's/^v//')

currentVersion=$(nix-instantiate --eval -E "with import ./. {}; localsend.version or (lib.getVersion localsend)" | tr -d '"')

if [[ "$currentVersion" == "$latestVersion" ]]; then
  echo "package is up-to-date: $currentVersion"
  exit 0
fi

nix-update --version "$latestVersion" --subpackage rustDep localsend

DARWIN_x64_URL="https://github.com/localsend/localsend/releases/download/v${latestVersion}/LocalSend-${latestVersion}.dmg"
DARWIN_X64_SHA=$(nix --extra-experimental-features nix-command hash convert --hash-algo sha256 --to sri "$(nix-prefetch-url "$DARWIN_x64_URL")")
sed -i "/darwin/,/hash/{s|hash = \".*\"|hash = \"${DARWIN_X64_SHA}\"|}" "$ROOT/package.nix"

curl --fail --silent "https://raw.githubusercontent.com/localsend/localsend/v${latestVersion}/app/pubspec.lock" \
    | yq . >"$ROOT/pubspec.lock.json"

gitHashesScript=$(nix eval --raw --file . dart.fetchGitHashesScript)
"$gitHashesScript" --input "$ROOT/pubspec.lock.json" --output "$ROOT/git-hashes.json"
