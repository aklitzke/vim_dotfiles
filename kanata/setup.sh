#!/bin/bash
# Sets up kanata: symlinks config, installs startup service (macOS or Linux).
# Run from anywhere — uses the script's own directory to find config files.

set -euo pipefail

kanata_dir=$(cd "$(dirname "$0")"; pwd)
config_dir="$HOME/.config/kanata"
config_file="$config_dir/kanata.kbd"

# ── Find kanata binary ───────────────────────────────────────────────────────

if command -v kanata &>/dev/null; then
  kanata_bin=$(command -v kanata)
else
  echo "ERROR: kanata not found. Install it first:"
  echo "  macOS:  brew install kanata"
  echo "  Linux:  cargo install kanata  (or your distro's package)"
  exit 1
fi

echo "Using kanata at: $kanata_bin"

# ── Symlink config ───────────────────────────────────────────────────────────

mkdir -p "$config_dir"
ln -sf "$kanata_dir/kanata.kbd" "$config_file"
echo "Linked $config_file"

# ── Platform-specific startup setup ─────────────────────────────────────────

if [[ "$OSTYPE" == darwin* ]]; then
  plist_src="$kanata_dir/macos.plist"
  # LaunchDaemon (root) — kanata needs root to write to the virtual HID device
  plist_dst="/Library/LaunchDaemons/com.kanata.plist"

  sed \
    -e "s|KANATA_BIN|$kanata_bin|g" \
    -e "s|KANATA_CFG|$config_file|g" \
    "$plist_src" | sudo tee "$plist_dst" > /dev/null

  sudo chmod 644 "$plist_dst"

  # Remove old user-level LaunchAgent if present
  old_agent="$HOME/Library/LaunchAgents/com.kanata.plist"
  if [[ -f "$old_agent" ]]; then
    launchctl unload "$old_agent" 2>/dev/null || true
    rm "$old_agent"
    echo "Removed old LaunchAgent"
  fi

  # Reload daemon
  sudo launchctl unload "$plist_dst" 2>/dev/null || true
  sudo launchctl load -w "$plist_dst"

  echo "LaunchDaemon installed: $plist_dst"
  echo ""
  echo "If kanata fails to start, check logs:"
  echo "  tail -f /tmp/kanata.log /tmp/kanata.err"

elif [[ "$OSTYPE" == linux* ]]; then
  service_dir="$HOME/.config/systemd/user"
  service_dst="$service_dir/kanata.service"

  mkdir -p "$service_dir"
  sed "s|KANATA_BIN|$kanata_bin|g" "$kanata_dir/kanata.service" > "$service_dst"

  systemctl --user daemon-reload
  systemctl --user enable --now kanata.service

  echo "Systemd user service installed and started."
  echo ""
  echo "IMPORTANT (Linux): kanata needs access to /dev/input and /dev/uinput."
  echo "Run these once (then log out and back in):"
  echo "  sudo usermod -aG input,uinput \$USER"
  echo "  echo 'KERNEL==\"uinput\", MODE=\"0660\", GROUP=\"uinput\", OPTIONS+=\"static_node=uinput\"' \\"
  echo "    | sudo tee /etc/udev/rules.d/99-uinput.rules"
  echo "  sudo udevadm control --reload-rules && sudo udevadm trigger"
  echo ""
  echo "Check status: systemctl --user status kanata"

else
  echo "Unknown OS: $OSTYPE — skipping startup service setup."
  echo "Manually run: kanata --cfg $config_file"
fi
