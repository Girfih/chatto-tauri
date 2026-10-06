#!/usr/bin/env bash
set -Eeuo pipefail

readonly ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly INSTALLER="$ROOT/packaging/arch/install-chatto-desktop.sh"
readonly TEMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TEMP_DIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

# The real package must be found beside the installer even from another cwd.
actual="$(cd / && bash "$INSTALLER" --locate-only)"
expected="$ROOT/packaging/arch/chatto-desktop-0.7.0-1-x86_64.pkg.tar.zst"
[[ "$actual" == "$expected" ]] || fail "found '$actual', expected '$expected'"

# Pick the newest regular package and never mistake its debug companion for it.
mkdir -p "$TEMP_DIR/tools" "$TEMP_DIR/downloads"
cp "$INSTALLER" "$TEMP_DIR/tools/install-chatto-desktop.sh"
touch "$TEMP_DIR/tools/chatto-desktop-0.9.0-1-x86_64.pkg.tar.zst"
touch "$TEMP_DIR/tools/chatto-desktop-debug-0.9.0-1-x86_64.pkg.tar.zst"
actual="$(cd / && bash "$TEMP_DIR/tools/install-chatto-desktop.sh" --locate-only)"
expected="$TEMP_DIR/tools/chatto-desktop-0.9.0-1-x86_64.pkg.tar.zst"
[[ "$actual" == "$expected" ]] || fail "found '$actual', expected newest nearby package '$expected'"

# Do not scan outside the installer's directory.
mkdir -p "$TEMP_DIR/empty/tools" "$TEMP_DIR/unrelated"
cp "$INSTALLER" "$TEMP_DIR/empty/tools/install-chatto-desktop.sh"
touch "$TEMP_DIR/unrelated/chatto-desktop-9.9.9-1-x86_64.pkg.tar.zst"
if (cd / && bash "$TEMP_DIR/empty/tools/install-chatto-desktop.sh" --locate-only >/dev/null 2>&1); then
  fail 'found a package outside the installer directory tree'
fi

printf 'PASS: package lookup is independent of cwd, chooses the newest nearby package, and ignores debug packages.\n'
