#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM_VERSION="${1:-0.1+git20261117.2931cc5}"
OUTDIR="${2:-${ROOT}/dist}"
SOURCE_DIR="${OUTDIR}/cefbrowser-${UPSTREAM_VERSION}"
ORIG_TARBALL="${OUTDIR}/cefbrowser_${UPSTREAM_VERSION}.orig.tar.xz"

CEF_ARCHIVE="cef_binary_126.2.7+g300bb05+chromium-126.0.6478.115_linux64_minimal.tar.bz2"
CEF_URL="https://cef-builds.spotifycdn.com/cef_binary_126.2.7%2Bg300bb05%2Bchromium-126.0.6478.115_linux64_minimal.tar.bz2"

command -v git >/dev/null
command -v meson >/dev/null
command -v curl >/dev/null
command -v sha1sum >/dev/null
command -v tar >/dev/null

rm -rf "${SOURCE_DIR}"
mkdir -p "${SOURCE_DIR}" "${OUTDIR}"

git -C "${ROOT}" archive --format=tar HEAD | tar -xf - -C "${SOURCE_DIR}"

cd "${SOURCE_DIR}"
rm -rf subprojects/cef subprojects/packagecache

# Meson wrap files contain their own immutable source hashes.  Resolve all wrap
# dependencies now so the Launchpad builder never needs outbound network access.
meson subprojects download

curl --fail --location --retry 3   "${CEF_URL}.sha1"   --output "subprojects/${CEF_ARCHIVE}.sha1"
curl --fail --location --retry 3   "${CEF_URL}"   --output "subprojects/${CEF_ARCHIVE}"

CEF_SHA1="$(tr -d '[:space:]' < "subprojects/${CEF_ARCHIVE}.sha1")"
printf '%s  %s\n' "${CEF_SHA1}" "subprojects/${CEF_ARCHIVE}" | sha1sum -c -

tar -C subprojects -xf "subprojects/${CEF_ARCHIVE}"
rm "subprojects/${CEF_ARCHIVE}" "subprojects/${CEF_ARCHIVE}.sha1"

CEF_EXTRACTED="$(find subprojects -mindepth 1 -maxdepth 1 -type d -name 'cef_binary_*_linux64_minimal' -print -quit)"
test -n "${CEF_EXTRACTED}"
mv "${CEF_EXTRACTED}" subprojects/cef

TMPDIR_ORIG="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_ORIG}"' EXIT
mkdir -p "${TMPDIR_ORIG}/cefbrowser-${UPSTREAM_VERSION}"
cp -a . "${TMPDIR_ORIG}/cefbrowser-${UPSTREAM_VERSION}/"
rm -rf "${TMPDIR_ORIG}/cefbrowser-${UPSTREAM_VERSION}/debian"
rm -rf "${TMPDIR_ORIG}/cefbrowser-${UPSTREAM_VERSION}/dist"

SOURCE_DATE_EPOCH="$(git -C "${ROOT}" show -s --format=%ct HEAD)"
tar --sort=name   --mtime="@${SOURCE_DATE_EPOCH}"   --owner=0 --group=0 --numeric-owner   -C "${TMPDIR_ORIG}"   -cJf "${ORIG_TARBALL}"   "cefbrowser-${UPSTREAM_VERSION}"

printf 'PREPARED_SOURCE=%s\n' "${SOURCE_DIR}"
printf 'ORIG_TARBALL=%s\n' "${ORIG_TARBALL}"
printf 'UPSTREAM_FIX_HEAD=%s\n' "2931cc51bbbb9357270d0704031dd7c99e2f733c"
