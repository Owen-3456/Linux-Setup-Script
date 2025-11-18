#!/bin/bash

packages=(
    "alacritty"           # GPU-accelerated terminal
    "aspell"              # spell checker
    "aspell-en"           # English dictionary for aspell
    "aria2"               # lightweight download utility
    "bash-completion"     # command auto-completion
    "bat"                 # cat clone with syntax highlighting
    "btop"                # resource monitor
    "coreutils"           # basic GNU file utilities
    "curl"                # HTTP transfer tool
    "eza"                 # modern ls replacement
    "ffmpeg"              # audio/video processing
    "fastfetch"           # system info fetcher
    "fzf"                 # fuzzy finder
    "git"                 # version control
    "gawk"                # text processing tool
    "iproute2"            # networking utilities
    "jq"                  # JSON processor
    "net-tools"           # legacy networking tools
    "nano"                # simple terminal text editor
    "ripgrep"             # fast recursive search
    "starship"            # minimal shell prompt
    "stow"                # symlink-based dotfile manager
    "strace"              # system call tracer
    "tmux"                # terminal multiplexer
    "tldr"                # simplified man pages
    "trash-cli"           # safe trash management
    "youtube-dl"          # video downloader
    "zoxide"              # smarter cd
)

# Detect distribution type
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    case $ID in
        arch|manjaro) distribution_type="arch" ;;
        ubuntu|debian) distribution_type="debian" ;;
        *) 
            case $ID_LIKE in
                *arch*) distribution_type="arch" ;;
                *debian*) distribution_type="debian" ;;
                *) distribution_type="unknown" ;;
            esac
            ;;
    esac
else
    distribution_type="unknown"
fi

# Check if distribution is supported
if [[ $distribution_type != "arch" && $distribution_type != "debian" ]]; then
    echo "Unsupported distribution. This script supports only Arch-based and Debian-based distributions."
    exit 1
fi

# Install packages based on distribution type
if [[ $distribution_type == "arch" ]]; then
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm "${packages[@]}"
elif [[ $distribution_type == "debian" ]]; then
    sudo apt install -y nala
    sudo nala update
    sudo nala upgrade -y
    sudo nala install -y "${packages[@]}"
fi

# Install yay for Arch-based systems
if [[ $distribution_type == "arch" ]]; then
    if ! command -v yay &> /dev/null; then
        echo "Installing yay AUR helper..."
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        cd /tmp/yay
        makepkg -si --noconfirm
        cd ~/
        rm -rf /tmp/yay
    else
        echo "yay is already installed."
    fi
fi

# Clone dotfiles repository
if [[ ! -d ~/.dotfiles ]]; then
    git clone https://github.com/Owen-3456/dotfiles.git ~/.dotfiles
else
    echo "Dotfiles directory already exists. Pulling latest changes."
    cd ~/.dotfiles
    git pull
fi

# Remove existing config files if they exist
files_to_remove=(
    ~/.bashrc
    ~/.config/alacritty/alacritty.toml
    ~/.config/fastfetch/config.jsonc
    ~/.gitconfig
    ~/.config/starship.toml
)

for file in "${files_to_remove[@]}"; do
    [[ -f "$file" || -L "$file" ]] && rm -f "$file"
done

# Install dotfiles using stow
cd ~/.dotfiles
stow --override */

# Source the new .bashrc
source ~/.bashrc

cd ~/

echo "Setup complete!"