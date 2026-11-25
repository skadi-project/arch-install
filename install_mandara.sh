#!/usr/bin/env bash
# Скрипт установки пакетов для Arch Linux + Mandara Shell
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "Не запускай скрипт от root — он сам вызовет sudo где нужно." >&2
  exit 1
fi

show_help() {
  cat <<'EOF'
Использование: ./install_*.sh [параметры]

Параметры:
  --help                 показать эту справку
  --dry-run              показать часть команд; режим не является безопасным предпросмотром
  --gpu MODE             auto, ask, amd, intel, nvidia, all или skip

Переменные окружения:
  GPU_MODE=auto|ask|amd|intel|nvidia|all|skip
  DRY_RUN=1
  LOG_FILE=/path/to/install.log
  KERNEL_HEADERS=linux-headers

  Выбор приложений:
    FILE_MANAGER=nautilus|thunar|nemo|pcmanfm-qt|yazi (по умолчанию: nautilus)
    TERMINAL=foot|kitty|alacritty|wezterm|ghostty     (по умолчанию: foot)
    USER_SHELL=fish|bash|zsh|nushell                  (по умолчанию: fish)
    BROWSER=firefox|chromium|brave|google-chrome|librewolf|qutebrowser (по умолчанию: firefox)
    TEXT_EDITORS='vscodium neovim|helix|emacs|kate|gedit|micro' (по умолчанию: оба)
EOF
}

DRY_RUN=${DRY_RUN:-0}
GPU_MODE=${GPU_MODE:-auto}
LOG_FILE=${LOG_FILE:-"$HOME/arch-install-$(date +%Y%m%d-%H%M%S).log"}

while (($#)); do
  case "$1" in
    --help) show_help; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    --gpu) shift; GPU_MODE=${1:?--gpu requires a mode} ;;
    *) echo "Неизвестный параметр: $1" >&2; show_help >&2; exit 2 ;;
  esac
  shift
done

command -v sudo >/dev/null || { echo 'Нужен sudo.' >&2; exit 1; }
sudo -v
if [[ $DRY_RUN != 1 ]]; then
  exec > >(tee -a "$LOG_FILE") 2>&1
  trap 'status=$?; if ((status != 0)); then echo "Ошибка в строке $LINENO. Лог: $LOG_FILE" >&2; fi' EXIT
else
  echo "DRY_RUN=1: команды установки будут показаны, но не выполнены."
fi

run() {
  if [[ $DRY_RUN == 1 ]]; then printf '+'; printf ' %q' "$@"; printf '\n'; return 0; fi
  "$@"
}

backup_file() {
  local file=$1
  if [[ -e $file && $DRY_RUN != 1 ]]; then  
    local backup="${file}.backup.$(date +%Y%m%d-%H%M%S)"
    local suffix=1
    while [[ -e $backup ]]; do
      backup="${file}.backup.$(date +%Y%m%d-%H%M%S).${suffix}"
      suffix=$((suffix + 1))
    done
    sudo cp -a "$file" "$backup"
    echo "Резервная копия: $backup"
  fi
}

select_kernel_headers() {
  local kernel=${KERNEL_HEADERS:-}
  if [[ -n $kernel ]]; then echo "$kernel"; return; fi
  case "$(uname -r)" in
    *-lts*) echo linux-lts-headers ;;
    *cachyos*) echo linux-cachyos-headers ;;
    *) echo linux-headers ;;
  esac
}

select_nvidia_driver() {
  local gpu_info
  gpu_info=$(LC_ALL=C lspci -nn | grep -Ei 'VGA|3D|Display' || true)
  if grep -qi 'NVIDIA' <<< "$gpu_info"; then
    if grep -Eqi 'GT 7[0-9][0-9]|GTX 7[0-9][0-9]|GTX 6[0-9][0-9]|Quadro [KMP]|Tesla [KMP]' <<< "$gpu_info"; then
      echo 'nvidia-dkms'
    else
      echo 'nvidia-open-dkms'
    fi
  else
    echo 'nvidia-open-dkms'
  fi
}

FILE_MANAGER_DEFAULT=nautilus
TERMINAL_DEFAULT=foot
USER_SHELL_DEFAULT=fish
BROWSER_DEFAULT=firefox
TEXT_EDITORS_DEFAULT="vscodium neovim"

select_multiple_applications() {
  local env_name=$1 prompt=$2 default=$3 result_name=$4
  shift 4
  local -a choices=("$@") selected=()
  local value="" token choice index=1

  if [[ -v $env_name ]]; then
    value=${!env_name}
  elif [[ ! -t 0 ]]; then
    printf 'Неинтерактивный запуск требует %s.\n' "$env_name" >&2
    return 1
  else
    printf '%s\n' "$prompt"
    for choice in "${choices[@]}"; do
      printf '  %d) %s\n' "$index" "$choice"
      index=$((index + 1))
    done
    printf 'Можно выбрать несколько: номера через пробел или запятую.\n'
    read -r -p "Выбор [${default}]: " value
    value=${value:-$default}
  fi

  value=${value//,/ }
  for token in $value; do
    if [[ $token =~ ^[0-9]+$ ]]; then
      if ((token < 1 || token > ${#choices[@]})); then
        printf 'Недопустимый номер %s для %s.\n' "$token" "$env_name" >&2
        return 1
      fi
      token=${choices[token - 1]}
    fi
    choice=''
    for choice in "${choices[@]}"; do
      [[ $token == "$choice" ]] && break
    done
    if [[ $token != "$choice" ]]; then
      printf 'Недопустимое значение %s=%s. Допустимо: %s.\n' "$env_name" "$token" "${choices[*]}" >&2
      return 1
    fi
    case " ${selected[*]} " in
      *" $token "*) ;;
      *) selected+=("$token") ;;
    esac
  done
  if ((${#selected[@]} == 0)); then
    printf '%s не может быть пустым.\n' "$env_name" >&2
    return 1
  fi
  printf -v "$result_name" '%s' "${selected[*]}"
}

select_application_choices() {
  select_multiple_applications FILE_MANAGER 'Файловый менеджер' "$FILE_MANAGER_DEFAULT" FILE_MANAGER nautilus thunar nemo pcmanfm-qt yazi
  select_multiple_applications TERMINAL 'Терминал' "$TERMINAL_DEFAULT" TERMINAL foot kitty alacritty wezterm ghostty
  select_multiple_applications USER_SHELL 'Оболочка' "$USER_SHELL_DEFAULT" USER_SHELL fish bash zsh nushell
  select_multiple_applications BROWSER 'Браузер' "$BROWSER_DEFAULT" BROWSER firefox chromium brave google-chrome librewolf qutebrowser
  select_multiple_applications TEXT_EDITORS 'Текстовые редакторы' "$TEXT_EDITORS_DEFAULT" TEXT_EDITORS vscodium neovim helix emacs kate gedit micro
}

resolve_application_packages() {
  CORE_PAC_PACKAGES=()
  CORE_AUR_PACKAGES=()
  local app
  for app in $FILE_MANAGER; do
    case "$app" in
      nautilus) CORE_PAC_PACKAGES+=(nautilus gvfs file-roller) ;;
      thunar) CORE_PAC_PACKAGES+=(thunar thunar-volman thunar-archive-plugin gvfs tumbler xarchiver) ;;
      nemo) CORE_PAC_PACKAGES+=(nemo nemo-fileroller gvfs) ;;
      pcmanfm-qt) CORE_PAC_PACKAGES+=(pcmanfm-qt gvfs) ;;
      yazi) CORE_PAC_PACKAGES+=(yazi) ;;
    esac
  done
  for app in $TERMINAL; do
    CORE_PAC_PACKAGES+=("$app")
  done
  for app in $USER_SHELL; do
    CORE_PAC_PACKAGES+=("$app")
  done
  for app in $BROWSER; do
    case "$app" in
      brave) CORE_AUR_PACKAGES+=(brave-bin) ;;
      google-chrome) CORE_AUR_PACKAGES+=(google-chrome) ;;
      librewolf) CORE_PAC_PACKAGES+=(librewolf) ;;
      *) CORE_PAC_PACKAGES+=("$app") ;;
    esac
  done
  for app in $TEXT_EDITORS; do
    case "$app" in
      vscodium) CORE_AUR_PACKAGES+=(vscodium-bin) ;;
      *) CORE_PAC_PACKAGES+=("$app") ;;
    esac
  done
}

if [[ $DRY_RUN == 1 ]]; then
  PAC='echo pacman -S --needed --noconfirm'
else
  PAC='sudo pacman -S --needed --noconfirm'
fi

select_application_choices
resolve_application_packages
printf 'Выбраны приложения: файловый менеджер=%s, терминал=%s, оболочка=%s, браузер=%s, редакторы=%s\n' \
  "$FILE_MANAGER" "$TERMINAL" "$USER_SHELL" "$BROWSER" "$TEXT_EDITORS"

# ─────────────────────────────────────────────
# 1. Система, multilib, базовые инструменты сборки
# ─────────────────────────────────────────────
# multilib нужен для lib32-* (nvidia, steam, wine, gamemode, mangohud)
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
  sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
fi

run sudo pacman -Syu --noconfirm
$PAC base-devel git

# GPU_MODE: auto (default), ask, amd, intel, nvidia, all, skip.
install_gpu_drivers() {
  local mode=${GPU_MODE:-auto} pci='' vendor selected
  local -a detected=() vendors=() packages=()

  case "$mode" in
    auto|ask|all)
      $PAC pciutils
      pci=$(LC_ALL=C lspci -n)
      while IFS= read -r vendor; do
        case "$vendor" in
          1002) detected+=(amd) ;;
          8086) detected+=(intel) ;;
          10de) detected+=(nvidia) ;;
        esac
      done < <(awk '$2 ~ /^03[[:xdigit:]][[:xdigit:]]:$/ {split($3, id, ":"); print tolower(id[1])}' <<< "$pci" | sort -u)
      printf 'Detected GPU vendors: %s\n' "${detected[*]:-none supported}"
      ;;
    amd|intel|nvidia|skip) ;;
    *) echo "Invalid GPU_MODE: $mode (auto, ask, amd, intel, nvidia, all, skip)" >&2; return 1 ;;
  esac

  if [[ $mode == auto ]]; then
    if ((${#detected[@]} == 1)); then
      mode=${detected[0]}
    else
      mode=ask
    fi
  fi

  if [[ $mode == ask ]]; then
    if [[ ! -t 0 ]]; then
      echo 'GPU selection needs a terminal. Set GPU_MODE=amd, intel, nvidia, all or skip.' >&2
      return 1
    fi
    local PS3='Select GPU drivers: '
    local -a choices=(amd intel nvidia)
    if ((${#detected[@]})); then choices+=(all); fi
    choices+=(skip)
    select selected in "${choices[@]}"; do
      if [[ -n $selected ]]; then
        mode=$selected
        break
      fi
      echo 'Select a menu number.' >&2
    done
    if [[ $mode == ask ]]; then
      echo 'GPU selection ended without a choice.' >&2
      return 1
    fi
  fi

  case "$mode" in
    skip) echo 'Skipping explicit GPU driver installation.'; return 0 ;;
    all)
      if ((${#detected[@]} == 0)); then
        echo 'No supported GPU vendors detected. Choose a driver explicitly or use GPU_MODE=skip.' >&2
        return 1
      fi
      vendors=("${detected[@]}")
      ;;
    *) vendors=("$mode") ;;
  esac

  if [[ " ${vendors[*]} " == *' amd '* || " ${vendors[*]} " == *' intel '* ]]; then
    packages+=(mesa lib32-mesa)
  fi
  for vendor in "${vendors[@]}"; do
    case "$vendor" in
      amd) packages+=(vulkan-radeon lib32-vulkan-radeon libva-mesa-driver mesa-vdpau) ;;
      intel) packages+=(vulkan-intel lib32-vulkan-intel intel-media-driver) ;;
      nvidia) packages+=($(select_kernel_headers) $(select_nvidia_driver) nvidia-utils lib32-nvidia-utils nvidia-settings libva-nvidia-driver) ;;
    esac
  done
  printf 'GPU drivers (%s): %s\n' "${vendors[*]}" "${packages[*]}"
  $PAC "${packages[@]}"

  if [[ " ${vendors[*]} " == *' nvidia '* ]]; then
    local config=/etc/modprobe.d/arch-install-nvidia.conf
    if [[ ! -e $config && ! -e /etc/modprobe.d/nvidia.conf ]]; then
      printf '%s\n' 'options nvidia_drm modeset=1' | sudo tee "$config" >/dev/null
    fi
    echo 'After reboot, check NVIDIA with nvidia-smi.'
  fi
  echo 'After reboot, check Vulkan with vulkaninfo --summary in your desktop session.'
}

install_gpu_drivers

# ─────────────────────────────────────────────
# 2. mandara shell
# ─────────────────────────────────────────────

sh -c 'f=$(mktemp) && trap "rm -f -- \"\$f\"" 0 && curl --proto =https -fL https://thehamdiz.github.io/mandara/install.sh -o "$f" && sh "$f" "$@"' \
  sh --compositor mango

# ─────────────────────────────────────────────
# 3. AUR-хелпер paru
# ─────────────────────────────────────────────
if ! paru --version >/dev/null 2>&1; then
  $PAC rustup
  rustup default stable
  tmp=$(mktemp -d)
  git clone https://aur.archlinux.org/paru.git "$tmp/paru"
  (cd "$tmp/paru" && makepkg -si --noconfirm)
  rm -rf "$tmp"
fi

# ─────────────────────────────────────────────
# 4. Приложения и CLI-утилиты
# ─────────────────────────────────────────────
$PAC "${CORE_PAC_PACKAGES[@]}" \
  7zip unzip \
  btop nvtop ncdu inxi fastfetch \
  fd bat eza ripgrep fzf zoxide yazi jq \
  ffmpeg poppler resvg imagemagick \
  github-cli tmux lazygit obs-studio telegram-desktop qbittorrent \
  libreoffice-still okular gimp veracrypt handbrake keepassxc celluloid \
  zerotier-one hardinfo2 nwg-look

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
FOOT_SOURCE="$SCRIPT_DIR/mandara/foot/foot.ini"
FOOT_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/foot"
FOOT_CONFIG="$FOOT_CONFIG_DIR/foot.ini"
if [[ ! -f $FOOT_SOURCE ]]; then
  echo "Не найден конфиг foot: $FOOT_SOURCE" >&2
  exit 1
fi
run install -d -m 755 "$FOOT_CONFIG_DIR"
backup_file "$FOOT_CONFIG"
run install -m 644 "$FOOT_SOURCE" "$FOOT_CONFIG"

# ─────────────────────────────────────────────
# 5. Разработка
# ─────────────────────────────────────────────
# C++
$PAC gcc clang cmake ninja make gdb lldb valgrind \
  ccache cppcheck clang-tools-extra boost fmt

# Rust
$PAC rustup rust-analyzer
rustup default stable

# Web (vscode-*-languageserver заменены на vscode-langservers-extracted)
$PAC nodejs uv npm pnpm typescript typescript-language-server \
  eslint prettier
paru -S --needed --noconfirm \
  vscode-langservers-extracted 

# Docker
$PAC docker docker-compose
run sudo systemctl enable --now docker
run sudo usermod -aG docker "$USER"

# ─────────────────────────────────────────────
# 6. Игры
# ─────────────────────────────────────────────
$PAC steam lutris wine-staging winetricks wine-mono wine-gecko gamescope \
  gamemode lib32-gamemode scx-scheds \
  mangohud lib32-mangohud goverlay \
  mesa-utils vulkan-tools s-tui

# ─────────────────────────────────────────────
# 7. Виртуализация (QEMU/KVM + libvirt)
# ─────────────────────────────────────────────
# --ask 4 автоматически соглашается заменить iptables на iptables-nft
run sudo pacman -S --needed --noconfirm --ask 4 \
  qemu-full libvirt virt-manager virt-viewer \
  dnsmasq swtpm edk2-ovmf dmidecode iptables-nft \
  openbsd-netcat spice-vdagent
paru -S --needed --noconfirm \
  bridge-utils

run sudo systemctl enable --now libvirtd.service
run sudo usermod -aG libvirt,kvm "$USER"
run sudo virsh net-autostart default
run sudo virsh net-start default || true   # уже запущена — не ошибка


# ─────────────────────────────────────────────
# 8. AUR
# ─────────────────────────────────────────────
if ((${#CORE_AUR_PACKAGES[@]})); then
  paru -S --needed --noconfirm "${CORE_AUR_PACKAGES[@]}"
fi
paru -S --needed --noconfirm \
  virtio-win libguestfs guestfs-tools \
  marktext-bin karing-bin teamspeak uxplay modrinth-app-bin
  
# Зависимости для karing-bin
$PAC libayatana-indicator

# Службы
run sudo systemctl enable --now zerotier-one
run sudo systemctl enable --now systemd-timesyncd
run sudo systemctl enable fstrim.timer

echo
echo "Готово. Перезагрузись: применятся группы docker/libvirt/kvm и настройки видеодрайвера."

# ─────────────────────────────────────────────
# Где брать темы (GTK4 + libadwaita)
# ─────────────────────────────────────────────
# Тема, иконки и курсор должны стоять СИСТЕМНО (/usr/share/themes, /usr/share/icons)
#
# GTK-темы:
#   - https://www.gnome-look.org (раздел GTK3/4 Themes)
#   - Catppuccin GTK:  https://github.com/catppuccin/gtk  (архивирован, есть форки/AUR)
#   - Colloid:         https://github.com/vinceliuice/Colloid-gtk-theme
#   - Orchis:          https://github.com/vinceliuice/Orchis-theme
#   - Tokyo Night:     https://github.com/Fausto-Korpsvart/Tokyonight-GTK-Theme
#   - Gruvbox:         https://github.com/Fausto-Korpsvart/Gruvbox-GTK-Theme
#   - Rosé Pine:       https://github.com/Fausto-Korpsvart/Rose-Pine-GTK-Theme
#   - adw-gtk3:        https://github.com/lassekongo83/adw-gtk3 (уже поставлен)
# Иконки:    Papirus (поставлен), Tela, Colloid-icon-theme
# Курсоры:   Bibata (поставлен), Catppuccin cursors, Rosé Pine cursor
# Обои:      https://wallhaven.cc, https://unsplash.com
