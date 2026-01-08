#!/usr/bin/env bash

set -euo pipefail

PREFIX="${1:-$HOME/.local}"
BINDIR="$PREFIX/bin"
DATADIR="$PREFIX/share/ralph-codex"

mkdir -p "$BINDIR" "$DATADIR"
install -m 0755 "$(dirname "$0")/../bin/ralph" "$BINDIR/ralph"
install -m 0644 "$(dirname "$0")/../README.md" "$DATADIR/README.md"

cat <<INSTALL_EOF
Installed ralph to:
  $BINDIR/ralph

Docs:
  $DATADIR/README.md
INSTALL_EOF

if ! command -v ralph >/dev/null 2>&1; then
  cat <<PATH_EOF

Note: $BINDIR is not on your PATH. Add this to your shell profile:
  export PATH="$BINDIR:\$PATH"
PATH_EOF
fi
