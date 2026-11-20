#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sudo install -m 755 "${SCRIPT_DIR}/hyprland-share-picker" /usr/local/bin/hyprland-share-picker
echo "Nyx hyprland-share-picker installed to /usr/local/bin/hyprland-share-picker"
