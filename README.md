# Dotfiles

Personal configurations managed with chezmoi, using Catppuccin Mocha with a blue accent.

## Included configurations

- Hyprland, Hypridle, Hyprlock, Hyprpaper, Hyprtoolkit and Kanshi.
- Quickshell bar, notifications, calendar, agenda, weather, audio, network, Bluetooth, display and power widgets, including Python helpers and SVG icons.
- Fuzzel, Alacritty, Zsh, Starship, tmux, Neovim, btop, bat, LazyGit, LazyDocker, gh-dash and Flameshot.
- GTK 3/4, local Catppuccin theme assets, Qt environment settings and desktop portal preferences.
- VS Code settings and keybindings, OpenCode theme settings and Firefox theme overrides for the personal and work profiles.
- Existing Waybar, SwayNC and Wlogout configurations, retained for optional use.
- Wallpapers and MIME application associations.

Home directory paths use chezmoi templates. Monitor names in Kanshi and Firefox profile names remain specific to this setup and may need adjustment on another machine.

## Restore

Install chezmoi and the applications you use, then clone this repository and run:

```sh
chezmoi --source "$HOME/Projects/personal/dotfiles" diff
chezmoi --source "$HOME/Projects/personal/dotfiles" apply
```

To make this checkout the default source, set `sourceDir` in `~/.config/chezmoi/chezmoi.toml` to its absolute path.

Quickshell uses PipeWire/WirePlumber, NetworkManager, BlueZ, brightnessctl and powerprofilesctl. Its settings buttons launch pavucontrol, nm-connection-editor and bluetui; system metrics launch btop in Alacritty.

Agenda and weather integration also require GNOME Calendar's calendar service, Evolution Data Server, GNOME Online Accounts, GNOME Weather, Python GObject bindings, GWeather 4 and optionally GeoClue. Google accounts and the weather location must be configured locally. These account credentials and GNOME settings databases are not stored here.

The repository does not install applications or reproduce their account connections.

## Update

```sh
chezmoi re-add
chezmoi diff
git -C "$HOME/Projects/personal/dotfiles" status --short
```

`re-add` updates managed files while preserving templates. For a changed template, edit the source with `chezmoi edit PATH` and check `chezmoi diff`. Add new configuration files individually with `chezmoi add --secrets=error PATH`.

Caches, logs, plugin installations, browser history, notification history and credentials are excluded from the tracked configuration selection.
