#!/usr/bin/env bash
# Sign release artifacts: dist/SHA256SUMS + detached ASCII-armored signature.
#
# This script will NOT generate a key. A key created next to the artifact it
# signs proves nothing: the trust root has to be a key whose fingerprint you
# published through a channel independent of this repository.
#
# Usage:
#   tools/sign-artifacts.sh              # uses the first secret key in the keyring
#   GPG_KEY=<keyid> tools/sign-artifacts.sh
set -euo pipefail
cd "$(dirname "$0")/.."

[ -d dist ] || { echo "error: no dist/ — run tools/build.sh first" >&2; exit 1; }

if ! gpg --list-secret-keys --with-colons 2>/dev/null | grep -q '^sec'; then
  cat >&2 << 'MSG'
error: no secret key in this GPG keyring.

This script deliberately refuses to invent one. A signature only means something
when the verifying key's fingerprint was published somewhere other than the
place the artifact lives. Create or import your key out of band, publish the
fingerprint (personal site, social bio, business card, keyserver + independent
confirmation), then run this again.
MSG
  exit 1
fi

keyid=${GPG_KEY:-$(gpg --list-secret-keys --with-colons | awk -F: '/^sec/{print $5; exit}')}

( cd dist
  sha256sum ./* > SHA256SUMS
  gpg --batch --yes --local-user "$keyid" --armor --detach-sign SHA256SUMS
)

fpr=$(gpg --list-secret-keys --with-colons "$keyid" | awk -F: '/^fpr/{print $10; exit}')
echo "signed dist/SHA256SUMS with key $keyid"
echo "fingerprint: $fpr"
echo
echo "Publish that fingerprint somewhere other than this repo. Then anyone can run:"
echo "  gpg --verify SHA256SUMS.asc SHA256SUMS && sha256sum -c SHA256SUMS"
echo "and know the checksums came from you and not from whoever controls the host."
