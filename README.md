# Linux Setup Script

Automated setup script for [Owen's dotfiles](https://github.com/Owen-3456/dotfiles). Installs all dependencies, clones the dotfiles repo, and symlinks configs into place using [GNU Stow](https://www.gnu.org/software/stow/). Designed to work on headless and GUI-less systems.

Supports **Arch-based** and **Debian-based** distributions, including derivatives (Manjaro, EndeavourOS, Garuda, Pop!_OS, Linux Mint, Zorin, Elementary, etc.).

## Quick Start

> Requires `curl` to be installed.

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

The script must **not** be run as root -- it uses `sudo` internally when needed.

---

## What It Does

The script runs the following steps in order:

### 1. Install yay (Arch only)

Installs the [yay](https://github.com/Jguer/yay) AUR helper if not already present. Ensures `base-devel` is installed first (required by `makepkg`). Clones and builds from the AUR into a temp directory, which is cleaned up after.

### 2. Install packages

Performs a full system upgrade, then installs all packages required by the dotfiles. Every package maps to a specific function, alias, or config in the dotfiles -- nothing unnecessary is installed.

**Arch**: `pacman -Syu` followed by `pacman -S --needed` to avoid reinstalling existing packages.

**Debian**: Installs [nala](https://gitlab.com/volian/nala) (a better apt frontend) first via `apt-get`, then uses nala for the system upgrade and all subsequent package installs.

#### Installed Packages

| Package | Purpose |
|---|---|
| `bash-completion` | Command auto-completion |
| `bat` | `cat` replacement with syntax highlighting |
| `btop` | Resource monitor (`top`/`htop` alias) |
| `curl` | HTTP transfers (`hb`, `weather`, etc.) |
| `eza` | Modern `ls` replacement with icons |
| `fastfetch` | System info (`neofetch` alias) |
| `fzf` | Fuzzy finder (`installpkg`, `removepkg`, `fzfkill`, `fzfdel`, keybinds) |
| `gawk` | Text processing (`cpp` function) |
| `git` | Version control |
| `git-lfs` | Git Large File Storage (configured in `.gitconfig`) |
| `jq` | JSON processing (`hb` function) |
| `nano` | Text editor (`$EDITOR`) |
| `ripgrep` | Fast search (`grep` alias) |
| `stow` | Symlink-based dotfile manager |
| `tldr` | Simplified man pages (`man` alias) |
| `tmux` | Terminal multiplexer |
| `trash-cli` | Safe file deletion (`rm` alias, `fzfdel`) |
| `wget` | Downloads with progress bar |
| `xclip` | Clipboard utility (`copy` alias, `hb`, `serve`) |
| `xdg-utils` | Desktop utilities (`openremote` function) |
| `zoxide` | Smarter `cd` replacement |
| `aria2` | Download accelerator (used by `ytdl` if available) |
| `fd` / `fd-find` | Fast find alternative (fzf keybinds, `fzfdel`) |
| `ffmpeg` | Audio/video processing (required by `yt-dlp`) |
| `iproute2` | Networking utilities (`whatsmyip`) |
| `net-tools` | Legacy networking (`openports` alias) |
| `nmap` | Network scanner (`portscan` function) |
| `p7zip` / `p7zip-full` | 7z archive extraction (`extract` function) |
| `python` / `python3` | HTTP server (`serve` function) |
| `strace` | System call tracer (`cpp` function) |
| `unrar` | RAR extraction (`extract` function) |
| `unzip` | ZIP extraction (`extract` function) |
| `yt-dlp` | YouTube downloader (`ytdl` function) |
| `aspell`, `aspell-en` | Spell checking (nano backend) |

Some package names differ between Arch and Debian (e.g., `fd` vs `fd-find`, `python` vs `python3`, `p7zip` vs `p7zip-full`). The script handles this with separate package arrays.

### 3. Install Starship

Installs the [Starship](https://starship.rs/) prompt via the official install script. Starship is not available in Debian's default repos, so it is always installed this way regardless of distro.

### 4. Install JetBrainsMono Nerd Font

Downloads and installs the [JetBrainsMono Nerd Font](https://www.nerdfonts.com/) from the latest [nerd-fonts release](https://github.com/ryanoasis/nerd-fonts/releases) on GitHub. Required for Starship prompt glyphs and eza file icons to render correctly.

- Installs to `~/.local/share/fonts/JetBrainsMono/` (user-level, no root needed)
- Rebuilds the font cache via `fc-cache` after install
- Skipped if the font is already installed
- Non-fatal -- if the download fails, the script continues

After setup, set your terminal emulator's font to **JetBrainsMono Nerd Font** (or **JetBrainsMono NF**).

### 5. Clone dotfiles

Clones the [dotfiles repo](https://github.com/Owen-3456/dotfiles) to `~/.dotfiles`. If the directory already exists, it pulls the latest changes instead.

### 6. Stow dotfiles

Removes existing config files that would conflict with stow symlinks, then symlinks each package into `$HOME` using `stow --no-folding` (prevents stow from symlinking entire directories).

If a stow operation fails due to conflicts, it retries with `--adopt` (absorbs the existing file into the stow package) and then restores the original from git.

**GUI packages are skipped** -- `alacritty` is not stowed, so the script works on headless/server systems. To set up alacritty manually on a GUI system:

```bash
cd ~/.dotfiles && stow alacritty
```

#### Configs applied

| Package | Target | Description |
|---|---|---|
| `bash` | `~/.bashrc` | Aliases, functions, keybinds (~1250 lines) |
| `nano` | `~/.nanorc` | Keybinds, spell check, syntax highlighting |
| `tmux` | `~/.tmux.conf` | Mouse support, dark theme, 50k scrollback |
| `git` | `~/.gitconfig` | Git LFS, credential store |
| `starship` | `~/.config/starship.toml` | Prompt theme |
| `fastfetch` | `~/.config/fastfetch/config.jsonc` | System info display |

### 7. Update Flatpaks

If Flatpak is installed, updates all Flatpak packages. Skipped silently if Flatpak is not present.

---

## Distro Detection

The script reads `/etc/os-release` and classifies the system as `arch` or `debian`. It recognizes these distributions directly:

| Arch-based | Debian-based |
|---|---|
| Arch Linux | Debian |
| Manjaro | Ubuntu |
| EndeavourOS | Pop!_OS |
| Garuda | Linux Mint |
| | Zorin OS |
| | elementary OS |

For unlisted distros, it falls back to the `ID_LIKE` field (e.g., a distro reporting `ID_LIKE="ubuntu debian"` will be treated as Debian-based). If neither match, the script exits with an error.

---

## Post-Setup

After the script completes, you should:

1. **Restart your shell** -- run `exec bash` or open a new terminal
2. **Review `~/.gitconfig`** -- update `[user] name` and `email` to your own values
3. **Set your terminal font** -- select **JetBrainsMono Nerd Font** in your terminal emulator's settings for icons to render correctly

---

## Requirements

- A supported Arch-based or Debian-based Linux distribution
- `curl` installed
- A non-root user with `sudo` access
- Internet connection

---

*Disclaimer: This README was mostly generated by AI.*
