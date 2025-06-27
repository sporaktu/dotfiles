#!/usr/bin/env bash

# on macOS, Homebrew Fish lives here:
if [[ "$(uname)" == "Darwin" ]]; then
  exec /opt/homebrew/bin/fish --login --interactive
fi

# on Linux/Arch, Fish is in /usr/bin
exec /usr/bin/fish --login --interactive
