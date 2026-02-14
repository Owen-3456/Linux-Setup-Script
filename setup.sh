#!/bin/bash
set -euo pipefail

# =============================================================================
# Dotfiles Setup Script
# Supports: Arch-based and Debian-based distributions
# =============================================================================

# -- Colors & Formatting ------------------------------------------------------
BOLD='\033[1m'
DIM='\033[2m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RC='\033[0m'

# -- Symbols ------------------------------------------------------------------
TICK="${GREEN}${BOLD}✓${RC}"
CROSS="${RED}${BOLD}✗${RC}"
ARROW="${CYAN}${BOLD}›${RC}"
WARN_SYM="${YELLOW}${BOLD}!${RC}"

# -- Log file -----------------------------------------------------------------
LOG_FILE=$(mktemp /tmp/dotfiles-setup-XXXXXX.log)

# -- Step tracking ------------------------------------------------------------
CURRENT_STEP=0
TOTAL_STEPS=7

# -- Helpers ------------------------------------------------------------------
step_header() {
    ((CURRENT_STEP++)) || true
    echo ""
    echo -e "  ${BOLD}${CYAN}[${CURRENT_STEP}/${TOTAL_STEPS}]${RC} ${BOLD}$*${RC}"
}

info()  { echo -e "       ${ARROW} $*"; }
warn()  { echo -e "       ${WARN_SYM} ${YELLOW}$*${RC}"; }
ok()    { echo -e "       ${TICK} $*"; }
fail()  { echo -e "       ${CROSS} $*"; }

# -- Spinner ------------------------------------------------------------------
# Usage: run_with_spinner "message" command [args...]
# Runs the command with all output redirected to LOG_FILE, showing a spinner.
_spinner_pid=""

_start_spinner() {
    local msg="$1"
    {
        local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
        local i=0
        while true; do
            printf "\r       \033[0;36m%s\033[0m \033[2m%s\033[0m" "${frames[$i]}" "$msg"
            i=$(( (i + 1) % ${#frames[@]} ))
            sleep 0.08
        done
    } &
    _spinner_pid=$!
}

_stop_spinner() {
    if [[ -n "$_spinner_pid" ]]; then
        kill "$_spinner_pid" 2>/dev/null || true
        wait "$_spinner_pid" 2>/dev/null || true
        _spinner_pid=""
    fi
    printf "\r\033[K"
}

_cleanup() {
    _stop_spinner
    # Kill sudo keepalive if running
    if [[ -n "${_sudo_keepalive_pid:-}" ]]; then
        kill "$_sudo_keepalive_pid" 2>/dev/null || true
        wait "$_sudo_keepalive_pid" 2>/dev/null || true
    fi
    tput cnorm 2>/dev/null || true
}

trap '_cleanup' EXIT
trap '_cleanup; exit 130' INT

run_with_spinner() {
    local msg="$1"
    shift

    _start_spinner "$msg"

    # Run the actual command, capturing output to log.
    # stdin is inherited (not redirected) so sudo can prompt for a password.
    local rc=0
    echo "=== $(date '+%H:%M:%S') :: $msg ===" >> "$LOG_FILE"
    "$@" >> "$LOG_FILE" 2>&1 || rc=$?

    _stop_spinner

    if [[ $rc -eq 0 ]]; then
        ok "$msg"
    else
        fail "$msg"
        echo -e "       ${DIM}See log: ${LOG_FILE}${RC}"
    fi

    return "$rc"
}

# -- Pre-flight checks -------------------------------------------------------
if [[ $EUID -eq 0 ]]; then
    echo -e "\n  ${CROSS} ${RED}Do not run this script as root. It will use sudo when needed.${RC}\n"
    exit 1
fi

if ! command -v curl &>/dev/null; then
    echo -e "\n  ${CROSS} ${RED}curl is required but not installed. Install it first and re-run.${RC}\n"
    exit 1
fi

# -- Cache sudo credentials upfront -------------------------------------------
# This prompts the user for their password *before* any spinners start,
# so the prompt is visible and interactive. The credential is then cached
# for subsequent sudo calls.
echo -e "  ${ARROW} Sudo access is required for package installation."
if ! sudo -v; then
    echo -e "  ${CROSS} ${RED}Failed to obtain sudo credentials.${RC}"
    exit 1
fi
# Keep sudo alive in the background for the duration of the script
(while true; do sudo -n true; sleep 50; done) &
_sudo_keepalive_pid=$!

# -- Install git if missing ---------------------------------------------------
if ! command -v git &>/dev/null; then
    echo -e "  ${ARROW} git not found, installing..."
    if [[ -f /etc/arch-release ]] || grep -qi 'arch' /etc/os-release 2>/dev/null; then
        sudo pacman -Sy --noconfirm git >> "$LOG_FILE" 2>&1
    elif [[ -f /etc/debian_version ]]; then
        sudo apt-get update -qq >> "$LOG_FILE" 2>&1 && sudo apt-get install -y git >> "$LOG_FILE" 2>&1
    else
        echo -e "  ${CROSS} ${RED}Cannot auto-install git on this distro.${RC}"
        exit 1
    fi
    echo -e "  ${TICK} git installed"
fi

# -- Package lists ------------------------------------------------------------
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
    echo -e "\n  ${CROSS} ${RED}Unsupported distribution. This script supports Arch-based and Debian-based systems only.${RC}\n"
    exit 1
fi

# -- Install packages ---------------------------------------------------------
install_packages() {
    if [[ "$distro" == "arch" ]]; then
        run_with_spinner "Upgrading system" sudo pacman -Syu --noconfirm
        run_with_spinner "Installing packages (${#arch_packages[@]} packages)" \
            sudo pacman -S --noconfirm --needed "${arch_packages[@]}"

    elif [[ "$distro" == "debian" ]]; then
        run_with_spinner "Updating package lists" sudo apt-get update -qq

        if ! command -v nala &>/dev/null; then
            run_with_spinner "Installing nala package manager" sudo apt-get install -y nala
        fi

        run_with_spinner "Updating package lists (nala)" sudo nala update
        run_with_spinner "Upgrading system" sudo nala upgrade -y
        run_with_spinner "Installing packages (${#debian_packages[@]} packages)" \
            sudo nala install -y "${debian_packages[@]}"
    fi
}

# -- Install yay (Arch only) --------------------------------------------------
install_yay() {
    [[ "$distro" != "arch" ]] && return 0

    if command -v yay &>/dev/null; then
        ok "yay already installed"
        return 0
    fi

    run_with_spinner "Installing base-devel" sudo pacman -S --noconfirm --needed base-devel

    local tmpdir
    tmpdir=$(mktemp -d)

    run_with_spinner "Cloning yay from AUR" git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    run_with_spinner "Building and installing yay" bash -c "cd '$tmpdir/yay' && makepkg -si --noconfirm"
    rm -rf "$tmpdir"
}

# -- Install starship prompt ---------------------------------------------------
install_starship() {
    if command -v starship &>/dev/null; then
        ok "Starship already installed"
        return 0
    fi

    run_with_spinner "Installing Starship prompt" \
        bash -c 'curl -sS https://starship.rs/install.sh | sh -s -- -y'
}

# -- Install JetBrainsMono Nerd Font ------------------------------------------
install_nerd_font() {
    local font_name="JetBrainsMono"
    local font_dir="$HOME/.local/share/fonts/$font_name"

    if [[ -d "$font_dir" ]] && ls "$font_dir"/*.ttf &>/dev/null; then
        ok "JetBrainsMono Nerd Font already installed"
        return 0
    fi

    local tmpdir
    tmpdir=$(mktemp -d)

    local latest_url
    latest_url=$(curl -sI "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_name}.zip" \
        | grep -i '^location:' | tr -d '\r' | awk '{print $2}')

    if [[ -z "$latest_url" ]]; then
        latest_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_name}.zip"
    fi

    if ! run_with_spinner "Downloading JetBrainsMono Nerd Font" \
        curl -fsSL -o "$tmpdir/${font_name}.zip" "$latest_url"; then
        warn "Failed to download Nerd Font, skipping"
        rm -rf "$tmpdir"
        return 0
    fi

    mkdir -p "$font_dir"
    run_with_spinner "Extracting font files" unzip -qo "$tmpdir/${font_name}.zip" -d "$font_dir"
    rm -rf "$tmpdir"

    if command -v fc-cache &>/dev/null; then
        run_with_spinner "Rebuilding font cache" fc-cache -f "$font_dir"
    fi
}

# -- Clone / update dotfiles --------------------------------------------------
setup_dotfiles() {
    if [[ ! -d "$HOME/.dotfiles" ]]; then
        run_with_spinner "Cloning dotfiles repository" \
            git clone https://github.com/Owen-3456/dotfiles.git "$HOME/.dotfiles"
    else
        run_with_spinner "Pulling latest dotfiles" \
            git -C "$HOME/.dotfiles" pull
    fi
}

# -- Stow dotfiles ------------------------------------------------------------
stow_dotfiles() {
    local files_to_remove=(
        "$HOME/.bashrc"
        "$HOME/.nanorc"
        "$HOME/.tmux.conf"
        "$HOME/.gitconfig"
        "$HOME/.config/fastfetch/config.jsonc"
        "$HOME/.config/starship.toml"
    )

    info "Removing conflicting config files"
    for file in "${files_to_remove[@]}"; do
        if [[ -f "$file" || -L "$file" ]]; then
            rm -f "$file"
        fi
    done

    local stow_dir="$HOME/.dotfiles"
    local packages=()
    local skip_packages=("alacritty")

    for dir in "$stow_dir"/*/; do
        [[ -d "$dir" ]] || continue
        local pkg
        pkg=$(basename "$dir")
        # shellcheck disable=SC2076
        if [[ " ${skip_packages[*]} " =~ " $pkg " ]]; then
            info "Skipping GUI package: ${DIM}$pkg${RC}"
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
        if stow -d "$stow_dir" -t "$HOME" --no-folding "$pkg" 2>> "$LOG_FILE"; then
            ok "Stowed ${BOLD}$pkg${RC}"
        else
            if stow -d "$stow_dir" -t "$HOME" --no-folding --adopt "$pkg" 2>> "$LOG_FILE"; then
                git -C "$stow_dir" checkout -- "$pkg" >> "$LOG_FILE" 2>&1
                ok "Stowed ${BOLD}$pkg${RC} ${DIM}(adopted & restored)${RC}"
            else
                fail "Failed to stow: $pkg"
                ((failed++)) || true
            fi
        fi
    done

    if [[ $failed -gt 0 ]]; then
        warn "$failed package(s) failed to stow. Check log: $LOG_FILE"
    fi
}

# -- Update flatpaks (if installed) -------------------------------------------
update_flatpaks() {
    if command -v flatpak &>/dev/null; then
        run_with_spinner "Updating Flatpak packages" flatpak update -y
    else
        info "${DIM}Flatpak not installed, skipping${RC}"
    fi
}

# -- Main ---------------------------------------------------------------------
main() {
    local start_time
    start_time=$(date +%s)

    echo ""
    echo -e "  ${BOLD}Dotfiles Setup${RC} ${DIM}| ${distro} | log: ${LOG_FILE}${RC}"
    echo -e "  ${DIM}──────────────────────────────────────${RC}"

    step_header "Installing AUR helper"
    install_yay

    step_header "Installing system packages"
    install_packages

    step_header "Installing Starship prompt"
    install_starship

    step_header "Installing Nerd Font"
    install_nerd_font

    step_header "Setting up dotfiles"
    setup_dotfiles

    step_header "Linking dotfiles with Stow"
    stow_dotfiles

    step_header "Updating Flatpak packages"
    update_flatpaks

    # -- Summary --------------------------------------------------------------
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    echo ""
    echo -e "  ${GREEN}${BOLD}──────────────────────────────────────${RC}"
    echo -e "  ${GREEN}${BOLD}  All done!${RC}  ${DIM}Completed in $((duration / 60))m $((duration % 60))s${RC}"
    echo -e "  ${GREEN}${BOLD}──────────────────────────────────────${RC}"
    echo ""
    echo -e "  ${BOLD}Configs applied:${RC}"
    echo -e "    ${TICK} bash      ${DIM}~/.bashrc${RC}"
    echo -e "    ${TICK} nano      ${DIM}~/.nanorc${RC}"
    echo -e "    ${TICK} tmux      ${DIM}~/.tmux.conf${RC}"
    echo -e "    ${TICK} git       ${DIM}~/.gitconfig${RC}"
    echo -e "    ${TICK} starship  ${DIM}~/.config/starship.toml${RC}"
    echo -e "    ${TICK} fastfetch ${DIM}~/.config/fastfetch/config.jsonc${RC}"
    echo ""
    echo -e "  ${WARN_SYM} ${YELLOW}Review ~/.gitconfig and update [user] name/email if needed.${RC}"
    echo -e "  ${ARROW} Restart your shell or run: ${BOLD}exec bash${RC}"
    echo -e "  ${DIM}  Full log: ${LOG_FILE}${RC}"
    echo ""
}

main "$@"
