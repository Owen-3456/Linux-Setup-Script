#!/bin/bash
set -euo pipefail

# =============================================================================
# Dotfiles Setup Script
# Supports: Arch-based and Debian-based distributions
# =============================================================================

# -- Colors -------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RC='\033[0m'

# -- Helpers ------------------------------------------------------------------
info()  { echo -e "${CYAN}[INFO]${RC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${RC}  $*"; }
error() { echo -e "${RED}[ERROR]${RC} $*"; }
ok()    { echo -e "${GREEN}[OK]${RC}    $*"; }

# -- Pre-flight checks -------------------------------------------------------
if [[ $EUID -eq 0 ]]; then
    error "Do not run this script as root. It will use sudo when needed."
    exit 1
fi

if ! command -v curl &>/dev/null; then
    error "curl is required but not installed. Install it first and re-run."
    exit 1
fi

# -- Install git if missing ---------------------------------------------------
if ! command -v git &>/dev/null; then
    info "git is not installed. Installing git..."
    if [[ -f /etc/arch-release ]] || grep -qi 'arch' /etc/os-release 2>/dev/null; then
        sudo pacman -Sy --noconfirm git
    elif [[ -f /etc/debian_version ]]; then
        sudo apt-get update -qq && sudo apt-get install -y git
    else
        error "git is required but not installed, and could not auto-install on this distro."
        exit 1
    fi
    ok "git installed."
fi

# -- Package lists ------------------------------------------------------------
# Packages are grouped by purpose. Commented-out packages are not required by
# the dotfiles but may be useful to have installed.

arch_packages=(
    # -- Core tools (required by dotfiles/bashrc) --
    "bash-completion"     # command auto-completion
    "bat"                 # cat clone with syntax highlighting (bashrc alias)
    "btop"                # resource monitor (bashrc alias: top/htop)
    "curl"                # HTTP transfer tool (used by hb, weather, etc.)
    "eza"                 # modern ls replacement (bashrc aliases)
    "fastfetch"           # system info fetcher (bashrc alias: neofetch)
    "fzf"                 # fuzzy finder (installpkg, removepkg, fzfkill, etc.)
    "gawk"                # text processing (used by cpp function)
    "git"                 # version control
    "git-lfs"             # Git Large File Storage (gitconfig filter)
    "jq"                  # JSON processor (used by hb function)
    "nano"                # terminal text editor (EDITOR in bashrc)
    "ripgrep"             # fast recursive search (bashrc alias: grep)
    "stow"                # symlink-based dotfile manager
    "tldr"                # simplified man pages (bashrc alias: man)
    "tmux"                # terminal multiplexer
    "trash-cli"           # safe trash management (bashrc alias: rm, fzfdel)
    "wget"                # HTTP download tool (bashrc alias with progress bar)
    "xclip"               # clipboard utility (bashrc copy alias, hb, serve)
    "xdg-utils"           # desktop utilities (openremote function uses xdg-open)
    "zoxide"              # smarter cd (bashrc alias: cd)

    # -- Used by bashrc functions --
    "aria2"               # download accelerator (used by ytdl if available)
    "fd"                  # fast find alternative (used by fzf keybinds & fzfdel)
    "ffmpeg"              # audio/video processing (required by yt-dlp for merging)
    "iproute2"            # networking utilities (whatsmyip function)
    "net-tools"           # legacy networking tools (openports alias)
    "nmap"                # network scanner (portscan function)
    "p7zip"               # 7z archive extraction (extract function)
    "python"              # HTTP server (serve function)
    "strace"              # system call tracer (cpp function)
    "unrar"               # rar archive extraction (extract function)
    "unzip"               # zip archive extraction (extract function)
    "yt-dlp"              # YouTube downloader (ytdl function)

    # -- Nano spell checking --
    "aspell"              # spell checker (nano speller backend)
    "aspell-en"           # English dictionary for aspell
)

debian_packages=(
    # -- Core tools (required by dotfiles/bashrc) --
    "bash-completion"     # command auto-completion
    "bat"                 # cat clone with syntax highlighting (bashrc alias)
    "btop"                # resource monitor (bashrc alias: top/htop)
    "curl"                # HTTP transfer tool (used by hb, weather, etc.)
    "eza"                 # modern ls replacement (bashrc aliases)
    "fastfetch"           # system info fetcher (bashrc alias: neofetch)
    "fzf"                 # fuzzy finder (installpkg, removepkg, fzfkill, etc.)
    "gawk"                # text processing (used by cpp function)
    "git"                 # version control
    "git-lfs"             # Git Large File Storage (gitconfig filter)
    "jq"                  # JSON processor (used by hb function)
    "nano"                # terminal text editor (EDITOR in bashrc)
    "ripgrep"             # fast recursive search (bashrc alias: grep)
    "stow"                # symlink-based dotfile manager
    "tldr"                # simplified man pages (bashrc alias: man)
    "tmux"                # terminal multiplexer
    "trash-cli"           # safe trash management (bashrc alias: rm, fzfdel)
    "wget"                # HTTP download tool (bashrc alias with progress bar)
    "xclip"               # clipboard utility (bashrc copy alias, hb, serve)
    "xdg-utils"           # desktop utilities (openremote function uses xdg-open)
    "zoxide"              # smarter cd (bashrc alias: cd)

    # -- Used by bashrc functions --
    "aria2"               # download accelerator (used by ytdl if available)
    "fd-find"             # fast find alternative (used by fzf keybinds & fzfdel)
    "ffmpeg"              # audio/video processing (required by yt-dlp for merging)
    "iproute2"            # networking utilities (whatsmyip function)
    "net-tools"           # legacy networking tools (openports alias)
    "nmap"                # network scanner (portscan function)
    "p7zip-full"          # 7z archive extraction (extract function)
    "python3"             # HTTP server (serve function)
    "strace"              # system call tracer (cpp function)
    "unrar"               # rar archive extraction (extract function)
    "unzip"               # zip archive extraction (extract function)
    "yt-dlp"              # YouTube downloader (ytdl function)

    # -- Nano spell checking --
    "aspell"              # spell checker (nano speller backend)
    "aspell-en"           # English dictionary for aspell
)

# -- Detect distribution ------------------------------------------------------
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case $ID in
            arch|manjaro|endeavouros|garuda) echo "arch" ;;
            ubuntu|debian|pop|linuxmint|zorin|elementary) echo "debian" ;;
            *)
                case ${ID_LIKE:-} in
                    *arch*) echo "arch" ;;
                    *debian*|*ubuntu*) echo "debian" ;;
                    *) echo "unknown" ;;
                esac
                ;;
        esac
    else
        echo "unknown"
    fi
}

distro=$(detect_distro)

if [[ "$distro" == "unknown" ]]; then
    error "Unsupported distribution. This script supports Arch-based and Debian-based systems only."
    exit 1
fi

info "Detected distribution type: ${distro}"

# -- Install packages ---------------------------------------------------------
install_packages() {
    if [[ "$distro" == "arch" ]]; then
        info "Performing full system upgrade..."
        sudo pacman -Syu --noconfirm

        info "Installing packages..."
        # --needed skips already-installed packages for speed
        sudo pacman -S --noconfirm --needed "${arch_packages[@]}"

    elif [[ "$distro" == "debian" ]]; then
        # Update package lists with apt first (always available)
        info "Updating package lists..."
        sudo apt-get update -qq

        # Install nala if not already present
        if ! command -v nala &>/dev/null; then
            info "Installing nala package manager..."
            sudo apt-get install -y nala
        fi

        # From here on, use nala for everything
        info "Updating package lists (nala)..."
        sudo nala update

        info "Upgrading system (nala)..."
        sudo nala upgrade -y

        info "Installing packages..."
        sudo nala install -y "${debian_packages[@]}"
    fi
}

# -- Install yay (Arch only) --------------------------------------------------
install_yay() {
    [[ "$distro" != "arch" ]] && return 0

    if command -v yay &>/dev/null; then
        ok "yay is already installed."
        return 0
    fi

    info "Installing yay AUR helper..."

    # base-devel is required for makepkg
    info "Ensuring base-devel is installed..."
    sudo pacman -S --noconfirm --needed base-devel

    local tmpdir
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
    ok "yay installed."
}

# -- Install starship prompt ---------------------------------------------------
install_starship() {
    if command -v starship &>/dev/null; then
        ok "starship is already installed."
        return 0
    fi

    info "Installing starship prompt..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    ok "starship installed."
}

# -- Install JetBrainsMono Nerd Font ------------------------------------------
install_nerd_font() {
    local font_name="JetBrainsMono"
    local font_dir="$HOME/.local/share/fonts/$font_name"

    if [[ -d "$font_dir" ]] && ls "$font_dir"/*.ttf &>/dev/null; then
        ok "JetBrainsMono Nerd Font is already installed."
        return 0
    fi

    info "Installing JetBrainsMono Nerd Font..."

    local tmpdir
    tmpdir=$(mktemp -d)

    local latest_url
    latest_url=$(curl -sI "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_name}.zip" \
        | grep -i '^location:' | tr -d '\r' | awk '{print $2}')

    if [[ -z "$latest_url" ]]; then
        # Fallback: use the redirect URL directly
        latest_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_name}.zip"
    fi

    if ! curl -fsSL -o "$tmpdir/${font_name}.zip" "$latest_url"; then
        warn "Failed to download Nerd Font. Skipping font installation."
        rm -rf "$tmpdir"
        return 0
    fi

    mkdir -p "$font_dir"
    unzip -qo "$tmpdir/${font_name}.zip" -d "$font_dir"
    rm -rf "$tmpdir"

    # Rebuild font cache
    if command -v fc-cache &>/dev/null; then
        fc-cache -f "$font_dir"
    fi

    ok "JetBrainsMono Nerd Font installed to $font_dir"
}

# -- Clone / update dotfiles --------------------------------------------------
setup_dotfiles() {
    if [[ ! -d "$HOME/.dotfiles" ]]; then
        info "Cloning dotfiles repository..."
        git clone https://github.com/Owen-3456/dotfiles.git "$HOME/.dotfiles"
        ok "Dotfiles cloned."
    else
        info "Dotfiles directory already exists. Pulling latest changes..."
        git -C "$HOME/.dotfiles" pull
        ok "Dotfiles updated."
    fi
}

# -- Stow dotfiles ------------------------------------------------------------
stow_dotfiles() {
    # Remove existing config files that would conflict with stow symlinks
    local files_to_remove=(
        "$HOME/.bashrc"
        "$HOME/.nanorc"
        "$HOME/.tmux.conf"
        "$HOME/.gitconfig"
        "$HOME/.config/fastfetch/config.jsonc"
        "$HOME/.config/starship.toml"
    )

    info "Removing existing config files that conflict with stow..."
    for file in "${files_to_remove[@]}"; do
        if [[ -f "$file" || -L "$file" ]]; then
            rm -f "$file"
        fi
    done

    info "Stowing dotfiles..."
    local stow_dir="$HOME/.dotfiles"
    local packages=()

    # Dynamically detect all stow packages (top-level dirs that aren't hidden)
    # Skip GUI-only packages (alacritty) so the script works on headless systems
    local skip_packages=("alacritty")
    for dir in "$stow_dir"/*/; do
        [[ -d "$dir" ]] || continue
        local pkg
        pkg=$(basename "$dir")
        # shellcheck disable=SC2076
        if [[ " ${skip_packages[*]} " =~ " $pkg " ]]; then
            info "Skipping GUI package: $pkg"
            continue
        fi
        packages+=("$pkg")
    done

    if [[ ${#packages[@]} -eq 0 ]]; then
        warn "No stow packages found in $stow_dir"
        return 1
    fi

    local failed=0
    for pkg in "${packages[@]}"; do
        if stow -d "$stow_dir" -t "$HOME" --no-folding "$pkg" 2>/dev/null; then
            ok "Stowed: $pkg"
        else
            # Retry with --adopt to handle existing files, then restore from git
            if stow -d "$stow_dir" -t "$HOME" --no-folding --adopt "$pkg" 2>/dev/null; then
                git -C "$stow_dir" checkout -- "$pkg"
                ok "Stowed (adopted & restored): $pkg"
            else
                warn "Failed to stow: $pkg"
                ((failed++)) || true
            fi
        fi
    done

    if [[ $failed -gt 0 ]]; then
        warn "$failed package(s) failed to stow. Check for conflicting files."
    fi
}

# -- Update flatpaks (if installed) -------------------------------------------
update_flatpaks() {
    if command -v flatpak &>/dev/null; then
        info "Updating flatpak packages..."
        flatpak update -y || warn "Some flatpak updates may have failed."
        ok "Flatpak packages updated."
    fi
}

# -- Main ---------------------------------------------------------------------
main() {
    local start_time
    start_time=$(date +%s)

    echo ""
    echo -e "${CYAN}========================================${RC}"
    echo -e "${CYAN}  Dotfiles Setup Script${RC}"
    echo -e "${CYAN}========================================${RC}"
    echo ""

    install_yay
    echo ""

    install_packages
    echo ""

    install_starship
    echo ""

    install_nerd_font
    echo ""

    setup_dotfiles
    echo ""

    stow_dotfiles
    echo ""

    update_flatpaks
    echo ""

    # -- Summary --------------------------------------------------------------
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    echo -e "${GREEN}========================================${RC}"
    echo -e "${GREEN}  Setup complete!${RC}"
    echo -e "${GREEN}========================================${RC}"
    echo ""
    echo "  Time taken: $((duration / 60))m $((duration % 60))s"
    echo ""
    echo -e "  ${CYAN}What was set up:${RC}"
    echo "    - System packages installed and upgraded"
    echo "    - Starship prompt installed"
    echo "    - JetBrainsMono Nerd Font installed"
    echo "    - Dotfiles cloned and symlinked via stow"
    echo "    - Flatpak packages updated (if installed)"
    echo ""
    echo -e "  ${CYAN}Configs applied:${RC}"
    echo "    - bash     : ~/.bashrc (aliases, functions, keybinds)"
    echo "    - nano     : ~/.nanorc (keybinds, spell check, syntax highlighting)"
    echo "    - tmux     : ~/.tmux.conf (mouse support, dark theme)"
    echo "    - git      : ~/.gitconfig (LFS, credential store)"
    echo "    - starship : ~/.config/starship.toml (prompt theme)"
    echo "    - fastfetch: ~/.config/fastfetch/config.jsonc (system info display)"
    echo ""
    echo -e "  ${YELLOW}NOTE: Review ~/.gitconfig and update [user] name/email if needed.${RC}"
    echo ""
    echo "  Restart your shell or run: exec bash"
    echo ""
}

main "$@"
