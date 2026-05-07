#!/bin/sh
set -eu

backend="${OFFICIAL_BACKEND:-Resources/7zz}"
url="${SEVENZIP_MAC_URL:?SEVENZIP_MAC_URL is required}"
archive_sha256="${SEVENZIP_MAC_ARCHIVE_SHA256:?SEVENZIP_MAC_ARCHIVE_SHA256 is required}"
binary_sha256="${SEVENZIP_MAC_BINARY_SHA256:?SEVENZIP_MAC_BINARY_SHA256 is required}"

hash_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

if [ -x "$backend" ]; then
  current_sha256="$(hash_file "$backend")"
  if [ "$current_sha256" = "$binary_sha256" ]; then
    echo "$backend already matches official 7zz sha256: $binary_sha256"
    lipo -info "$backend"
    exit 0
  fi

  echo "$backend exists but has sha256 $current_sha256, expected $binary_sha256"
  echo "Downloading the pinned official 7-Zip macOS archive."
fi

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT HUP INT TERM

archive="$tmpdir/7z-mac.tar.xz"
extract_dir="$tmpdir/extract"
mkdir -p "$extract_dir"

curl -fsSL -o "$archive" "$url"
echo "$archive_sha256  $archive" | shasum -a 256 -c -

tar -xJf "$archive" -C "$extract_dir"
extracted_backend="$(find "$extract_dir" -type f -name 7zz -perm -111 -print -quit)"
if [ -z "$extracted_backend" ]; then
  echo "Downloaded archive did not contain an executable 7zz" >&2
  exit 1
fi

extracted_sha256="$(hash_file "$extracted_backend")"
if [ "$extracted_sha256" != "$binary_sha256" ]; then
  echo "Extracted 7zz sha256 mismatch: got $extracted_sha256, expected $binary_sha256" >&2
  exit 1
fi

lipo -info "$extracted_backend" | grep -q 'x86_64'
lipo -info "$extracted_backend" | grep -q 'arm64'

mkdir -p "$(dirname "$backend")"
cp "$extracted_backend" "$backend"
chmod +x "$backend"
lipo -info "$backend"
echo "Installed official 7zz to $backend"
