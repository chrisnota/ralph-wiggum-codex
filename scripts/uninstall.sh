#!/usr/bin/env bash

set -euo pipefail

PREFIX="${1:-$HOME/.local}"
BINDIR="$PREFIX/bin"
DATADIR="$PREFIX/share/ralph-codex"

rm -f "$BINDIR/ralph"
rm -rf "$DATADIR"

echo "Uninstalled ralph from $PREFIX"
