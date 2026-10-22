#!/usr/bin/env bash
# Скрипт установки пакетов для Arch Linux (Hyprland + dev + gaming + виртуализация)
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "Не запускай скрипт от root — он сам вызовет sudo где нужно." >&2
  exit 1
fi

PAC="sudo pacman -S --needed --noconfirm"

# ─────────────────────────────────────────────
# 1. Система, multilib, базовые инструменты сборки
# ─────────────────────────────────────────────
# multilib нужен для lib32-* (nvidia, steam, wine, gamemode, mangohud)
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
  sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
fi

sudo pacman -Syu --noconfirm
$PAC base-devel git

# ─────────────────────────────────────────────
# 2. AUR-хелпер paru
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
# 3. Hyprland, Wayland и десктопное окружение
# ─────────────────────────────────────────────
$PAC hyprland uwsm xorg-xwayland xorg-xlsclients xorg-xwininfo \
  qt5-wayland qt6-wayland qt6-base qt6-declarative qt6-imageformats qt6-shadertools \
  glib2 glibc gcc-libs libpipewire aubio libqalculate pipewire wireplumber pipewire-pulse pavucontrol \
  networkmanager power-profiles-daemon brightnessctl ddcutil lm_sensors \
  libnotify grim slurp swappy wl-clipboard cliphist fuzzel dart-sass

# ─────────────────────────────────────────────
# 4. Шрифты
# ─────────────────────────────────────────────
$PAC noto-fonts noto-fonts-emoji ttf-nerd-fonts-symbols \
  ttf-jetbrains-mono-nerd ttf-cascadia-code-nerd

# ─────────────────────────────────────────────
# 4.1 Экран входа: greetd + ReGreet
# ─────────────────────────────────────────────
# greetd         — демон входа
# greetd-regreet — GTK4-greeter
# cage           — минимальный Wayland-композитор, в котором greeter запускается
# adw-gtk-theme, papirus-icon-theme — GTK-тема и иконки (ставятся системно,
#                  пользователь greeter не видит ~/.themes и ~/.icons)
$PAC greetd greetd-regreet cage gtk4 adw-gtk-theme papirus-icon-theme

# Курсор (Bibata) — может быть в AUR, paru разберётся
paru -S --needed --noconfirm bibata-cursor-theme

# Конфиг greetd: запускаем ReGreet внутри cage
# -s  — разрешить переключение VT, -m last — только последний подключённый монитор
sudo tee /etc/greetd/config.toml >/dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "cage -s -m last -- regreet"
user = "greeter"
EOF

# Обои для экрана входа (положи свой файл сюда, если хочешь фон)
sudo install -d -m 755 /usr/share/backgrounds
BG_LINE=""
if [[ -f /usr/share/backgrounds/greeter.jpg ]]; then
  BG_LINE=$'[background]\npath = "/usr/share/backgrounds/greeter.jpg"\nfit = "Cover"\n'
fi

# Конфиг ReGreet (темы можно менять — см. комментарии в конце скрипта)
sudo tee /etc/greetd/regreet.toml >/dev/null <<EOF
${BG_LINE}
[GTK]
application_prefer_dark_theme = true
theme_name = "adw-gtk3-dark"
icon_theme_name = "Papirus-Dark"
cursor_theme_name = "Bibata-Modern-Classic"
font_name = "JetBrainsMono Nerd Font 12"

[commands]
reboot = [ "systemctl", "reboot" ]
poweroff = [ "systemctl", "poweroff" ]
EOF

# Каталоги состояния и логов ReGreet (запоминание последнего пользователя/сессии)
sudo systemd-tmpfiles --create 2>/dev/null || true

# Включаем greetd. --now не используем, чтобы не убить текущую сессию.
# Если уже включён другой DM (sddm, gdm, ly), сначала отключи его:
#   sudo systemctl disable sddm
sudo systemctl enable greetd.service

# ─────────────────────────────────────────────
# 5. Приложения и CLI-утилиты
# ─────────────────────────────────────────────
$PAC firefox foot fish bash neovim \
  thunar thunar-volman thunar-archive-plugin gvfs gvfs-backends tumbler xarchiver 7zip \
  btop nvtop ncdu inxi fastfetch \
  fd bat eza ripgrep fzf zoxide yazi jq \
  ffmpeg poppler resvg imagemagick \
  github-cli tmux lazygit obs-studio telegram-desktop qbittorrent \
  libreoffice-still okular gimp veracrypt handbrake keepassxc celluloid \
  zerotier-one hardinfo2

# ─────────────────────────────────────────────
# 6. Разработка
# ─────────────────────────────────────────────
# C++
$PAC gcc clang cmake ninja make gdb lldb valgrind \
  ccache cppcheck clang-tools-extra boost fmt

# Rust
$PAC rustup rust-analyzer
rustup default stable

# Web (vscode-*-languageserver заменены на vscode-langservers-extracted)
$PAC nodejs npm pnpm typescript typescript-language-server \
  vscode-langservers-extracted eslint prettier
  
# SQL
$PAC postgresql sqlite
if [[ ! -f /var/lib/postgres/data/PG_VERSION ]]; then
  sudo -iu postgres initdb --locale=C.UTF-8 --encoding=UTF8 -D /var/lib/postgres/data
fi
sudo systemctl enable --now postgresql

# Docker
$PAC docker docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"

# ─────────────────────────────────────────────
# 7. NVIDIA
# ─────────────────────────────────────────────
$PAC linux-headers nvidia-open-dkms nvidia-utils lib32-nvidia-utils \
  nvidia-settings libva-nvidia-driver

# Строка "options ..." — это конфиг modprobe, а не команда shell
echo "options nvidia_drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf >/dev/null

# ─────────────────────────────────────────────
# 8. Игры
# ─────────────────────────────────────────────
$PAC steam lutris wine-staging winetricks wine-mono wine-gecko gamescope \
  gamemode lib32-gamemode scx-scheds \
  mangohud lib32-mangohud goverlay \
  mesa-utils vulkan-tools s-tui

# ─────────────────────────────────────────────
# 9. Виртуализация (QEMU/KVM + libvirt)
# ─────────────────────────────────────────────
# --ask 4 автоматически соглашается заменить iptables на iptables-nft
sudo pacman -S --needed --noconfirm --ask 4 \
  qemu-full libvirt virt-manager virt-viewer \
  dnsmasq swtpm edk2-ovmf dmidecode bridge-utils iptables-nft \
  openbsd-netcat spice-vdagent

sudo systemctl enable --now libvirtd.service
sudo usermod -aG libvirt,kvm "$USER"
sudo virsh net-autostart default
sudo virsh net-start default || true   # уже запущена — не ошибка

# ─────────────────────────────────────────────
# 10. AUR (в самом конце, когда все зависимости из репозиториев стоят)
# ─────────────────────────────────────────────
paru -S --needed --noconfirm \
  quickshell-git gpu-screen-recorder libcava \
  vscodium-bin \
  ttf-material-symbols-variable-git ttf-rubik-vf qt6-m3shapes-git \
  virtio-win libguestfs guestfs-tools virt-top \
  caelestia-cli \
  marktext-bin karing-bin teamspeak uxplay modrinth-app-bin

# ─────────────────────────────────────────────
# 11. Caelestia shell
# ─────────────────────────────────────────────
# XDG_CONFIG_HOME может быть не задан (а с set -u это ошибка) — берём запасной путь
QS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
mkdir -p "$QS_DIR"

if [[ ! -d "$QS_DIR/caelestia/.git" ]]; then
  git clone https://github.com/caelestia-dots/shell.git "$QS_DIR/caelestia"
fi

(
  cd "$QS_DIR/caelestia"
  cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/ \
    -DINSTALL_QSCONFDIR="$QS_DIR/caelestia"
  cmake --build build
  sudo cmake --install build
  sudo chown -R "$USER": "$QS_DIR/caelestia"
)   

sudo systemctl enable --now zerotier-one
sudo systemctl enable --now systemd-timesyncd
sudo systemctl enable fstrim.timer

echo
echo "Готово. Перезагрузись: применятся группы docker/libvirt/kvm, настройки NVIDIA и появится экран входа ReGreet."

# ─────────────────────────────────────────────
# Где брать темы для ReGreet (GTK4 + libadwaita)
# ─────────────────────────────────────────────
# Тема, иконки и курсор должны стоять СИСТЕМНО (/usr/share/themes, /usr/share/icons),
# а не в ~/.themes, иначе пользователь greeter их не увидит.
# После установки впиши имена в /etc/greetd/regreet.toml (секция [GTK]).
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
#            положи файл как /usr/share/backgrounds/greeter.jpg и перезапусти скрипт
#            или добавь секцию [background] в /etc/greetd/regreet.toml вручную
# Вдохновение и готовые конфиги: https://www.reddit.com/r/unixporn
# Документация ReGreet:          https://github.com/rharish101/ReGreet
#
# Установка темы из GitHub системно (пример для Colloid):
#   git clone https://github.com/vinceliuice/Colloid-gtk-theme && cd Colloid-gtk-theme
#   sudo ./install.sh --dest /usr/share/themes --tweaks black
