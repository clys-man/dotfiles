#!/bin/sh

# DBus-activated helpers such as keyring prompts need the Wayland session
# environment, otherwise they may start without a display to show dialogs.
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
keyring_control="$runtime_dir/keyring"
ssh_auth_sock="$runtime_dir/gcr/ssh"
ssh_askpass="/usr/lib/gcr4-ssh-askpass"

export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-Hyprland}"
export XDG_SESSION_DESKTOP="${XDG_SESSION_DESKTOP:-Hyprland}"
export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-wayland}"
export GNOME_KEYRING_CONTROL="${GNOME_KEYRING_CONTROL:-$keyring_control}"
export SSH_AUTH_SOCK="$ssh_auth_sock"

if [ -x "$ssh_askpass" ]; then
	export SSH_ASKPASS="$ssh_askpass"
	export SSH_ASKPASS_REQUIRE="${SSH_ASKPASS_REQUIRE:-prefer}"
fi

dbus-update-activation-environment --systemd \
	DISPLAY \
	WAYLAND_DISPLAY \
	XDG_CURRENT_DESKTOP \
	XDG_SESSION_DESKTOP \
	XDG_SESSION_TYPE >/dev/null 2>&1 || true

systemctl --user import-environment \
	DISPLAY \
	WAYLAND_DISPLAY \
	XDG_CURRENT_DESKTOP \
	XDG_SESSION_DESKTOP \
	XDG_SESSION_TYPE >/dev/null 2>&1 || true

systemctl --user start gnome-keyring-daemon.service >/dev/null 2>&1 || true
systemctl --user start gcr-ssh-agent.socket >/dev/null 2>&1 || true

gnome-keyring-daemon --start --components=pkcs11,secrets >/dev/null 2>&1 || true

if [ ! -S "$ssh_auth_sock" ] && [ -x /usr/lib/gcr-ssh-agent ]; then
	mkdir -p "$runtime_dir/gcr"
	/usr/lib/gcr-ssh-agent --base-dir "$runtime_dir/gcr" >/dev/null 2>&1 &
fi

systemctl --user import-environment \
	GNOME_KEYRING_CONTROL \
	SSH_AUTH_SOCK \
	SSH_ASKPASS \
	SSH_ASKPASS_REQUIRE >/dev/null 2>&1 || true

dbus-update-activation-environment --systemd \
	GNOME_KEYRING_CONTROL \
	SSH_AUTH_SOCK \
	SSH_ASKPASS \
	SSH_ASKPASS_REQUIRE >/dev/null 2>&1 || true

if [ -n "${GNOME_KEYRING_CONTROL:-}" ]; then
	hyprctl keyword env "GNOME_KEYRING_CONTROL,$GNOME_KEYRING_CONTROL" >/dev/null 2>&1 || true
fi

if [ -n "${SSH_AUTH_SOCK:-}" ]; then
	hyprctl keyword env "SSH_AUTH_SOCK,$SSH_AUTH_SOCK" >/dev/null 2>&1 || true
fi

if [ -n "${SSH_ASKPASS:-}" ]; then
	hyprctl keyword env "SSH_ASKPASS,$SSH_ASKPASS" >/dev/null 2>&1 || true
fi

if [ -n "${SSH_ASKPASS_REQUIRE:-}" ]; then
	hyprctl keyword env "SSH_ASKPASS_REQUIRE,$SSH_ASKPASS_REQUIRE" >/dev/null 2>&1 || true
fi
