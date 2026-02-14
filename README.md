# Linux Setup Script

Automated setup script for my [dotfiles](https://github.com/Owen-3456/dotfiles). Installs dependencies, clones the dotfiles repo, and symlinks configs into place with [GNU Stow](https://www.gnu.org/software/stow/).

Supports **Arch-based** and **Debian-based** distributions.

## Quick Start

```bash
curl -fsSL https://owen3456.xyz/linux | bash
```

Or manually:

```bash
git clone https://github.com/Owen-3456/Linux-Setup-Script.git
cd Linux-Setup-Script
chmod +x setup.sh
./setup.sh
```

> Requires `curl` and a non-root user with `sudo` access.

## What It Does

1. **Installs yay** (Arch only) -- AUR helper
2. **Installs packages** -- full system upgrade, then all CLI tools needed by the dotfiles
3. **Installs tldr** (Debian only) -- via pip, since it's not in apt repos
4. **Installs [Starship](https://starship.rs/)** -- prompt theme
5. **Installs [JetBrainsMono Nerd Font](https://www.nerdfonts.com/)** -- required for prompt glyphs and file icons
6. **Clones and stows [dotfiles](https://github.com/Owen-3456/dotfiles)** -- symlinks configs for bash, nano, tmux, git, starship, and fastfetch
7. **Updates Flatpaks** -- if Flatpak is installed

All command output is suppressed and logged to `/tmp/dotfiles-setup-*.log`.

### Configs Applied

| Package     | Target                             |
| ----------- | ---------------------------------- |
| `bash`      | `~/.bashrc`                        |
| `nano`      | `~/.nanorc`                        |
| `tmux`      | `~/.tmux.conf`                     |
| `git`       | `~/.gitconfig`                     |
| `starship`  | `~/.config/starship.toml`          |
| `fastfetch` | `~/.config/fastfetch/config.jsonc` |

GUI packages (e.g. `alacritty`) are skipped. To stow manually: `cd ~/.dotfiles && stow alacritty`

## Supported Distros

Detected via `/etc/os-release`. Falls back to `ID_LIKE` for unlisted distros.

| Arch-based                         | Debian-based                                      |
| ---------------------------------- | ------------------------------------------------- |
| Arch, Manjaro, EndeavourOS, Garuda | Debian, Ubuntu, Pop!\_OS, Mint, Zorin, elementary |

## Post-Setup

1. Restart your shell: `exec bash`
2. Update `~/.gitconfig` with your name/email
3. Set your terminal font to **JetBrainsMono Nerd Font**
