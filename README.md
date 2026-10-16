# Arch + Hyprland

## Быстрый запуск через git

Подходит, если Arch уже установлен (см. раздел «Чистая система» выше), создан пользователь с `sudo` и работает сеть. Скрипт `install.sh` автоматизирует всё из раздела «Настройка чистой системы» ниже. Смену ядра на CachyOS он не выполняет: это отдельный необязательный шаг (раздел «Смена ядра на CachyOS» в конце).

1. Установите git:

```bash
sudo pacman -S --needed git
```

2. Склонируйте репозиторий:

```bash
git clone https://github.com/skadi-project/arch-install.git
cd arch-install
```

3. Запустите скрипт от обычного пользователя (не от root, `sudo` он вызовет сам):

```bash
chmod +x install.sh
./install.sh
```

4. После завершения перезагрузитесь, чтобы применились группы `docker`/`libvirt`/`kvm`, настройки NVIDIA и появился экран входа ReGreet:

```bash
sudo reboot
```

Что нужно знать перед запуском:

- Скрипт ставит драйвер **NVIDIA** (раздел 7 в `install.sh`) и `amd-ucode`. Для Intel отредактируйте этот раздел заранее, ориентируясь на раздел «Игровые пакеты» ниже.
- Пакеты ставятся с `--noconfirm`, а AUR-пакеты и Caelestia shell собираются из исходников, поэтому установка может занять много времени.
- Репозиторий `multilib` скрипт включает сам.
- Если нужен фон экрана входа, положите картинку в `/usr/share/backgrounds/greeter.jpg` и запустите скрипт заново.
- Если уже включён другой менеджер входа (sddm, gdm, ly), сначала отключите его: `sudo systemctl disable sddm`.

Обновить репозиторий позже: `git pull`.

## Чистая система

### Перед установкой

```bash
loadkeys ru
```

### Интернет

При подключении через провод, можно пропустить этот шаг.

Wi-Fi настраивается через `iwctl` (входит в live-образ Arch). Запустите интерактивный режим:

```bash
iwctl
```

Дальнейшие команды вводятся внутри `iwctl` (приглашение `[iwd]#`). Имя адаптера обычно `wlan0`, узнать его можно так:

```bash
device list
```

Сканирование и подключение:

```bash
station wlan0 scan
station wlan0 get-networks
station wlan0 connect "Имя_сети"   # попросит пароль
exit
```

Если имя сети содержит пробелы, возьмите его в кавычки. Для скрытой сети используйте `station wlan0 connect-hidden "Имя_сети"`.

То же одной командой, без интерактивного режима:

```bash
iwctl --passphrase "пароль" station wlan0 connect "Имя_сети"
```

Если адаптер не виден в `device list` или выключен:

```bash
rfkill list                              # проверить блокировки
rfkill unblock wifi
iwctl device wlan0 set-property Powered on
iwctl adapter phy0 set-property Powered on
```

Проверьте соединение:

```bash
iwctl station wlan0 show   # State: connected
ping -c 3 archlinux.org
```

> `iwd` из live-образа в установленную систему не переносится: там сетью управляет NetworkManager. После первой загрузки подключитесь к Wi-Fi так:
> 
> ```bash
> sudo systemctl enable --now NetworkManager
> nmcli device wifi list
> nmcli device wifi connect "Имя_сети" --ask
> ```
> 
> Либо интерактивно: `nmtui`.

### Время

```bash
timedatectl
```

### Подготовка диска

```bash
lsblk # Найти нужный диск /dev/###
cfdisk /dev/sda
```

#### Разметка

##### UEFI

```bash
gpt
new > 512M > type > EFI
new > 8G > type > SWAP
new > {all size} > Linux
write > yes
quit
```

Разделы: `/dev/sda1` — EFI, `/dev/sda2` — swap, `/dev/sda3` — корень.

##### BIOS

```bash
mbr
new > 8G > primary > type > SWAP
new > {all size} > primary > bootable > type > Linux
write > yes
quit
```

Разделы: `/dev/sda1` — swap, `/dev/sda2` — корень.

> Secure Boot работает только в режиме UEFI. Для BIOS этот вариант недоступен.

#### Файловая система корня

Выберите один вариант: ext4 (проще) или btrfs (сжатие, снапшоты, подтома).

Сначала укажите раздел корня:

```bash
ROOT=/dev/sda3   # UEFI
ROOT=/dev/sda2   # BIOS
```

##### Вариант 1: ext4

```bash
mkfs.ext4 $ROOT
mount $ROOT /mnt
```

##### Вариант 2: btrfs

```bash
mkfs.btrfs -L arch $ROOT
mount $ROOT /mnt

# Подтома
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@snapshots
umount /mnt

# Монтирование подтомов (noatime + сжатие zstd)
OPTS=noatime,compress=zstd
mount -o $OPTS,subvol=@ $ROOT /mnt
mount --mkdir -o $OPTS,subvol=@home $ROOT /mnt/home
mount --mkdir -o $OPTS,subvol=@log $ROOT /mnt/var/log
mount --mkdir -o $OPTS,subvol=@pkg $ROOT /mnt/var/cache/pacman/pkg
mount --mkdir -o $OPTS,subvol=@snapshots $ROOT /mnt/.snapshots
```

Swap делаем отдельным разделом (swap-файл на btrfs требует особых действий).

#### Загрузочный раздел и swap

##### UEFI

```bash
mkfs.fat -F 32 /dev/sda1
mkswap /dev/sda2

mount --mkdir /dev/sda1 /mnt/boot
swapon /dev/sda2
```

##### BIOS

```bash
mkswap /dev/sda1
swapon /dev/sda1
```

### Установка системы

Замените `amd-ucode` на `intel-ucode`, если у вас устанавлен процессор от Intel.

Для btrfs добавьте `btrfs-progs`, для Secure Boot — `sbctl`.

```bash
pacstrap -K /mnt base base-devel linux linux-firmware dosfstools \
  e2fsprogs pciutils usbutils amd-ucode nano man-db man-pages

# Только btrfs:
pacstrap -K /mnt btrfs-progs
# Только Secure Boot:
pacstrap -K /mnt sbctl
```

### Конфигурация

```bash
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot -S /mnt 

# Найти временную зону: ls /usr/share/zoneinfo/Europe
ln -sf /usr/share/zoneinfo/Europe/Ulyanovsk /etc/localtime
hwclock --systohc

# Раскомментировать строку с ru_RU.UTF-8 и en_US.UTF-8 в /etc/locale.gen
locale-gen
echo "LANG=ru_RU.UTF-8" > /etc/locale.conf
echo "skadi-arch" > /etc/hostname
echo "127.0.1.1 skadi-arch.localdomain skadi-arch" >> /etc/hosts

# Задание пароля root и создание пользователя
passwd
useradd -mG wheel,audio,video,input,storage skadi
passwd skadi

# Раскомментировать строку с %wheel ALL=(ALL:ALL) ALL
EDITOR=nano visudo

# Установка пакетов (GRUB: BIOS и UEFI)
pacman -S networkmanager grub efibootmgr

# Установка пакетов (UEFI + Secure Boot, вместо grub)
pacman -S networkmanager sbctl
```

Проверьте `/etc/fstab`: для btrfs в нём должны быть строки с `subvol=@`, `subvol=@home` и т.д.

### Установка загрузчика

#### BIOS

```bash
grub-install --target=i386-pc /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg
```

#### UEFI

```bash
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=arch
grub-mkconfig -o /boot/grub/grub.cfg
```

#### UEFI + Secure Boot (systemd-boot + sbctl)

Вместо GRUB используем `systemd-boot` (входит в пакет `systemd`) и `sbctl`, который сам генерирует ключи и подписывает файлы. ESP смонтирован в `/boot`, поэтому ядро лежит на FAT-разделе — это одинаково работает и с ext4, и с btrfs.

**1. В прошивке (BIOS Setup)** переведите Secure Boot в режим **Setup Mode**: очистите ключи («Erase / Clear Secure Boot Keys», «Custom mode») и пока оставьте Secure Boot выключенным. Название пунктов зависит от производителя.

**2. Установка загрузчика (в chroot):**

```bash
bootctl install
```

**3. Конфигурация загрузчика.** Узнайте UUID корня:

```bash
blkid -s UUID -o value /dev/sda3
```

`/boot/loader/loader.conf`:

```
default arch.conf
timeout 3
console-mode max
editor no
```

`/boot/loader/entries/arch.conf` (замените `amd-ucode` на `intel-ucode` при необходимости):

```
title   Arch Linux
linux   /vmlinuz-linux
initrd  /amd-ucode.img
initrd  /initramfs-linux.img
options root=UUID=<UUID> rw
```

Для **btrfs** строка options должна включать подтом:

```
options root=UUID=<UUID> rootflags=subvol=@ rw
```

Опция `editor no` важна: иначе в меню загрузчика можно изменить параметры ядра и обойти защиту.

Затем завершите установку (см. «Завершение установки» ниже). Secure Boot пока выключен. После первой загрузки продолжите с раздела «Secure Boot: ключи и подпись».

> GRUB с Secure Boot здесь не рассматривается: ему нужен shim или отдельная сборка с подписью, что заметно сложнее.

### Завершение установки

Выйдите из chroot, отмонтируйте разделы и перезагрузитесь (извлеките установочный носитель):

```bash
exit
umount -R /mnt
reboot
```

После первой загрузки войдите под созданным пользователем и переходите к разделу «Настройка чистой системы». Если выбрали вариант с Secure Boot, сначала выполните шаги из следующего раздела.

### Secure Boot: ключи и подпись

Нужно только для варианта «UEFI + Secure Boot (systemd-boot + sbctl)», после первой загрузки в установленную систему.

**1. Ключи и подпись:**

```bash
sudo sbctl status                 # Setup Mode: Enabled
sudo sbctl create-keys
sudo sbctl enroll-keys -m         # -m — добавить ключи Microsoft (нужны для части прошивок, GPU, dual boot)

sudo sbctl verify                 # покажет неподписанные файлы
sudo sbctl sign -s /boot/EFI/systemd/systemd-bootx64.efi
sudo sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
sudo sbctl sign -s /boot/vmlinuz-linux
sudo sbctl verify                 # всё должно быть подписано

sudo systemctl enable systemd-boot-update.service
```

Флаг `-s` сохраняет файл в базу sbctl, и pacman-хук пакета `sbctl` автоматически переподписывает его после обновлений ядра и загрузчика. Периодически проверяйте `sudo sbctl verify`.

**2. Включите Secure Boot** в прошивке и перезагрузитесь. Проверка:

```bash
sudo sbctl status                 # Secure Boot: Enabled
bootctl status
```

> Модули NVIDIA (`nvidia-open-dkms`) подписывать не нужно: на Arch по умолчанию ядро не требует подписи модулей.

## Настройка чистой системы

Все шаги ниже повторяют `install.sh` (кроме смены ядра, она вынесена в отдельный раздел в конце). Если ставите вручную, выполняйте их по порядку: AUR-пакеты (в том числе курсор для экрана входа) требуют `paru`.

### Подготовка системы

Включите сеть:

```bash
sudo systemctl enable --now NetworkManager
```

Для игровых пакетов (`lib32-*`, Steam, Wine) в `/etc/pacman.conf` раскомментируйте multilib:

```bash
[multilib]
Include = /etc/pacman.d/mirrorlist
```

Обновите систему и поставьте инструменты для сборки пакетов:

```bash
sudo pacman -Syu
sudo pacman -S --needed base-devel git
```

Системные службы:

```bash
sudo systemctl enable --now systemd-timesyncd # синхронизация времени
sudo systemctl enable fstrim.timer # Периодический TRIM для SSD
```

#### AUR-хелпер paru

```bash
git clone https://aur.archlinux.org/paru-bin.git
cd paru-bin
makepkg -si
cd .. && rm -rf paru-bin
```

### Hyprland и десктопное окружение

Панель, лаунчер и виджеты даёт Caelestia shell.

```bash
sudo pacman -S --needed hyprland uwsm xorg-xwayland xorg-xlsclients \
  xorg-xwininfo qt5-wayland qt6-wayland qt6-base qt6-declarative \
  qt6-imageformats qt6-shadertools glib2 glibc gcc-libs libpipewire \
  aubio libqalculate networkmanager power-profiles-daemon brightnessctl \
  ddcutil lm_sensors libnotify grim slurp swappy wl-clipboard cliphist \
  fuzzel dart-sass
```

#### Звук

```bash
sudo pacman -S --needed pipewire wireplumber pipewire-pulse pavucontrol
```

#### Шрифты

```bash
sudo pacman -S --needed noto-fonts noto-fonts-emoji ttf-nerd-fonts-symbols \
  ttf-jetbrains-mono-nerd ttf-cascadia-code-nerd
```

### Экран входа: greetd + ReGreet

`cage` — минимальный Wayland-композитор, внутри которого запускается greeter. Тема и иконки ставятся системно, потому что пользователь `greeter` не видит `~/.themes` и `~/.icons`.

```bash
sudo pacman -S --needed greetd greetd-regreet cage gtk4 adw-gtk-theme \
  papirus-icon-theme
paru -S --needed bibata-cursor-theme
```

`/etc/greetd/config.toml`:

```toml
[terminal]
vt = 1

[default_session]
command = "cage -s -m last -- regreet"
user = "greeter"
```

`/etc/greetd/regreet.toml`:

```toml
[GTK]
application_prefer_dark_theme = true
theme_name = "adw-gtk3-dark"
icon_theme_name = "Papirus-Dark"
cursor_theme_name = "Bibata-Modern-Classic"
font_name = "JetBrainsMono Nerd Font 12"

[commands]
reboot = [ "systemctl", "reboot" ]
poweroff = [ "systemctl", "poweroff" ]
```

Для фона экрана входа положите картинку в `/usr/share/backgrounds/greeter.jpg` и добавьте в начало `regreet.toml`:

```toml
[background]
path = "/usr/share/backgrounds/greeter.jpg"
fit = "Cover"
```

Если уже включён другой менеджер входа (sddm, gdm, ly), сначала отключите его: `sudo systemctl disable sddm`.

```bash
sudo systemd-tmpfiles --create
sudo systemctl enable greetd.service  # без --now, чтобы не убить текущую сессию
```

Темы для ReGreet: [gnome-look.org](https://www.gnome-look.org), [Colloid](https://github.com/vinceliuice/Colloid-gtk-theme), [Orchis](https://github.com/vinceliuice/Orchis-theme), [Tokyo Night](https://github.com/Fausto-Korpsvart/Tokyonight-GTK-Theme), [Gruvbox](https://github.com/Fausto-Korpsvart/Gruvbox-GTK-Theme), [Rosé Pine](https://github.com/Fausto-Korpsvart/Rose-Pine-GTK-Theme). Устанавливать их нужно системно:

```bash
git clone https://github.com/vinceliuice/Colloid-gtk-theme && cd Colloid-gtk-theme
sudo ./install.sh --dest /usr/share/themes --tweaks black
```

После установки впишите имя темы в секцию `[GTK]` файла `/etc/greetd/regreet.toml`.

### Приложения и утилиты командной строки

```bash
sudo pacman -S --needed firefox foot fish bash neovim \
  thunar thunar-volman thunar-archive-plugin gvfs gvfs-backends tumbler \
  xarchiver 7zip \
  btop nvtop ncdu inxi fastfetch \
  fd bat eza ripgrep fzf zoxide yazi jq \
  ffmpeg poppler resvg imagemagick

# Смена оболочки
chsh -s /usr/bin/fish
```

### Пакеты для разработки

```bash
# C++
sudo pacman -S --needed gcc clang cmake ninja make gdb lldb valgrind \
  ccache cppcheck clang-tools-extra boost fmt
# Rust
sudo pacman -S --needed rustup rust-analyzer
rustup default stable
# Web
sudo pacman -S --needed nodejs npm pnpm typescript \
  typescript-language-server vscode-langservers-extracted eslint prettier
# Общее
sudo pacman -S --needed github-cli tmux lazygit
# SQL
sudo pacman -S --needed postgresql sqlite
# PostgreSQL
sudo -iu postgres initdb --locale=C.UTF-8 --encoding=UTF8 -D /var/lib/postgres/data
sudo systemctl enable --now postgresql
# Docker
sudo pacman -S --needed docker docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

VSCodium ставится из AUR (см. раздел AUR).

> **Для btrfs:** базы данных и образы ВМ лучше хранить без copy-on-write. Выполните `chattr +C` на **пустом** каталоге до создания в нём данных, например перед `initdb`: `sudo mkdir -p /var/lib/postgres/data && sudo chattr +C /var/lib/postgres/data`.

### Игровые пакеты

Нужен включённый multilib (см. выше).

Графические драйверы (выберите свою видеокарту):

```bash
# AMD
sudo pacman -S --needed mesa lib32-mesa vulkan-radeon \
  lib32-vulkan-radeon libva-mesa-driver mesa-vdpau

# Intel
sudo pacman -S --needed mesa lib32-mesa vulkan-intel lib32-vulkan-intel \
  intel-media-driver

# NVIDIA
sudo pacman -S --needed linux-headers nvidia-open-dkms nvidia-utils \
  lib32-nvidia-utils nvidia-settings libva-nvidia-driver
```

Для Nvidia создать или отредактировать файл `/etc/modprobe.d/nvidia.conf`:

```bash
options nvidia_drm modeset=1
```

Лаунчеры, совместимость, оптимизация и мониторинг:

```bash
sudo pacman -S --needed steam lutris wine-staging winetricks wine-mono \
  wine-gecko gamescope \
  gamemode lib32-gamemode scx-scheds \
  mangohud lib32-mangohud goverlay mesa-utils vulkan-tools s-tui
# только AMD:
sudo pacman -S --needed radeontop
```

Опции запуска в Steam:

```
gamemoderun mangohud %command%
# С gamescope (полезно при проблемах с масштабированием под Hyprland):
gamescope -W 2560 -H 1440 -r 144 -f -- gamemoderun mangohud %command%
```

### Виртуальные машины

`--ask 4` автоматически соглашается заменить `iptables` на `iptables-nft`.

```bash
sudo pacman -S --needed --ask 4 qemu-full libvirt virt-manager virt-viewer \
  dnsmasq swtpm edk2-ovmf dmidecode bridge-utils iptables-nft \
  openbsd-netcat spice-vdagent
sudo systemctl enable --now libvirtd.service
sudo usermod -aG libvirt,kvm $USER
sudo virsh net-autostart default
sudo virsh net-start default
```

Пакеты `virtio-win`, `libguestfs`, `guestfs-tools` и `virt-top` ставятся из AUR (см. ниже).

> **Для btrfs:** отключите copy-on-write для образов дисков (на пустом каталоге): `sudo chattr +C /var/lib/libvirt/images`.

### AUR

Менеджер `paru` уже установлен выше. Всё ставится в конце, когда зависимости из репозиториев на месте:

```bash
paru -S --needed quickshell-git gpu-screen-recorder libcava \
  vscodium-bin \
  ttf-material-symbols-variable-git ttf-rubik-vf qt6-m3shapes-git \
  virtio-win libguestfs guestfs-tools virt-top \
  caelestia-cli
```

### Caelestia shell

Оболочка собирается из исходников (нужны `cmake`, `ninja` и `gcc` из раздела «Пакеты для разработки») и кладётся в конфиг Quickshell:

```bash
QS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
mkdir -p "$QS_DIR"
git clone https://github.com/caelestia-dots/shell.git "$QS_DIR/caelestia"

cd "$QS_DIR/caelestia"
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/ \
  -DINSTALL_QSCONFDIR="$QS_DIR/caelestia"
cmake --build build
sudo cmake --install build
sudo chown -R "$USER": "$QS_DIR/caelestia"
```

После завершить настройку `caelestia`:

```bash
caelestia install
```

### Дополнительно

Повседневные приложения:

```bash
sudo pacman -S --needed obs-studio telegram-desktop qbittorrent \
  libreoffice-still okular gimp veracrypt handbrake keepassxc celluloid \
  zerotier-one hardinfo2
sudo systemctl enable --now zerotier-one
```

Пакеты AUR:

```bash
paru -S marktext-bin karing-bin teamspeak uxplay modrinth-app-bin
```

### Перезагрузка

Перезагрузитесь: применятся группы `docker`/`libvirt`/`kvm`, настройки NVIDIA и появится экран входа ReGreet.

```bash
sudo reboot
```

Убедитесь, что система работает на стандартном ядре. После этого при желании можно сменить ядро (следующий раздел).

## Смена ядра на CachyOS (опционально)

Выполняйте после настройки системы и перезагрузки: обычное ядро `linux` останется запасным вариантом, если что-то пойдёт не так. Скрипт `install.sh` этот шаг не делает.

### 1. Подключите репозиторий CachyOS

```bash
curl https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz
tar xvf cachyos-repo.tar.xz && cd cachyos-repo
sudo ./cachyos-repo.sh
```

Скрипт ставит ключи и список зеркал, добавляет репозитории CachyOS в `/etc/pacman.conf` выше репозиториев Arch и сам выбирает набор под ваш процессор (x86-64-v3 или v4). Поддержку можно проверить заранее:

```bash
/lib/ld-linux-x86-64.so.2 --help | grep supported
```

Репозитории v3/v4 содержат и оптимизированные сборки обычных пакетов Arch, поэтому при следующем обновлении часть системных пакетов может смениться на сборки CachyOS. Если нужно только ядро, подключайте репозитории вручную по [инструкции в вики CachyOS](https://wiki.cachyos.org/cachyos_repositories/how_to_add_cachyos_repo).

### 2. Выберите и установите ядро

Ядра отличаются планировщиком (BORE или EEVDF) и способом сборки. Для Hyprland, игр и NVIDIA подойдёт `linux-cachyos` или `linux-cachyos-bore`.

| Ядро                     | Назначение                                                                    |
| ------------------------ | ----------------------------------------------------------------------------- |
| `linux-cachyos`          | По умолчанию: EEVDF, сборка Clang с Thin LTO и AutoFDO. Универсальный вариант |
| `linux-cachyos-bore`     | Планировщик BORE, сборка GCC. Интерактивные задачи и игры                     |
| `linux-cachyos-eevdf`    | EEVDF, сборка GCC. Универсальная работа без Clang                             |
| `linux-cachyos-lts`      | Долгая поддержка. Стабильность, хорошее запасное ядро                         |
| `linux-cachyos-server`   | Настройки под серверную нагрузку                                              |
| `linux-cachyos-hardened` | Патчи безопасности, BORE                                                      |
| `linux-cachyos-rt-bore`  | Реальное время, BORE. Низкие задержки, аудио                                  |
| `linux-cachyos-deckify`  | Под Steam Deck и подобные устройства, BORE                                    |
| `linux-cachyos-rc`       | Релиз-кандидат апстрима. Тестирование, возможны сбои                          |
| `linux-cachyos-bmq`      | Планировщик BMQ. Эксперименты; sched_ext (`scx-scheds`) с ним не работает     |
| `linux-cachyos-gcc`      | Вариант `linux-cachyos`, собранный GCC                                        |

Команды для копирования (ядро + заголовки + готовый модуль NVIDIA open):

```bash
# linux-cachyos (по умолчанию)
sudo pacman -S linux-cachyos linux-cachyos-headers linux-cachyos-nvidia-open

# linux-cachyos-bore
sudo pacman -S linux-cachyos-bore linux-cachyos-bore-headers linux-cachyos-bore-nvidia-open

# linux-cachyos-eevdf
sudo pacman -S linux-cachyos-eevdf linux-cachyos-eevdf-headers linux-cachyos-eevdf-nvidia-open

# linux-cachyos-lts
sudo pacman -S linux-cachyos-lts linux-cachyos-lts-headers linux-cachyos-lts-nvidia-open

# linux-cachyos-server
sudo pacman -S linux-cachyos-server linux-cachyos-server-headers linux-cachyos-server-nvidia-open

# linux-cachyos-hardened
sudo pacman -S linux-cachyos-hardened linux-cachyos-hardened-headers linux-cachyos-hardened-nvidia-open

# linux-cachyos-rt-bore
sudo pacman -S linux-cachyos-rt-bore linux-cachyos-rt-bore-headers linux-cachyos-rt-bore-nvidia-open

# linux-cachyos-deckify
sudo pacman -S linux-cachyos-deckify linux-cachyos-deckify-headers linux-cachyos-deckify-nvidia-open

# linux-cachyos-rc
sudo pacman -S linux-cachyos-rc linux-cachyos-rc-headers linux-cachyos-rc-nvidia-open

# linux-cachyos-bmq
sudo pacman -S linux-cachyos-bmq linux-cachyos-bmq-headers linux-cachyos-bmq-nvidia-open

# linux-cachyos-gcc
sudo pacman -S linux-cachyos-gcc linux-cachyos-gcc-headers linux-cachyos-gcc-nvidia-open
```

Другие модули (подставьте имя своего ядра вместо `linux-cachyos`):

```bash
# NVIDIA, закрытые модули
sudo pacman -S linux-cachyos-nvidia

# ZFS
sudo pacman -S linux-cachyos-zfs
```



### 3. Добавьте ядро в загрузчик

**GRUB:**

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

**systemd-boot** (запись создаётся вручную, как и для обычного ядра). `/boot/loader/entries/cachyos.conf` (замените `amd-ucode` на `intel-ucode` при необходимости):

```
title   Arch Linux (CachyOS)
linux   /vmlinuz-linux-cachyos
initrd  /amd-ucode.img
initrd  /initramfs-linux-cachyos.img
options root=UUID=<UUID> rw
```

Для **btrfs** добавьте в `options` подтом: `rootflags=subvol=@`. Параметр `default` в `loader.conf` пока оставьте на `arch.conf`, а новое ядро выбирайте в меню загрузчика. Проверка: `bootctl list`.

**Secure Boot (sbctl):** подпишите новое ядро, иначе оно не загрузится:

```bash
sudo sbctl sign -s /boot/vmlinuz-linux-cachyos
sudo sbctl verify
```

Pacman-хук `sbctl` будет переподписывать его после обновлений.

### 4. Перезагрузитесь и проверьте

Выберите новое ядро в меню загрузчика, затем:

```bash
uname -r        # в выводе должно быть cachyos
dkms status     # модули собраны под новое ядро
nvidia-smi      # для NVIDIA
```

### 5. Удалите старое ядро (по желанию)

Только после того, как убедились, что всё работает на новом ядре:

```bash
sudo pacman -Rns linux linux-headers
```

- GRUB: повторите `sudo grub-mkconfig -o /boot/grub/grub.cfg`.
- systemd-boot: в `loader.conf` поставьте `default cachyos.conf` и удалите `/boot/loader/entries/arch.conf`.
- Secure Boot: уберите старый файл из базы подписей: `sudo sbctl remove-file /boot/vmlinuz-linux`.

### Откат репозитория

```bash
sudo ./cachyos-repo.sh --remove
```

Скрипт вернёт прежний `pacman.conf`, удалит список зеркал и ключи CachyOS. Запускайте его из распакованного каталога `cachyos-repo`.

## Репозитории используемых проектов

### Менеджеры пакетов и загрузка

- [paru](https://github.com/Morganamilo/paru) — AUR-хелпер
- [sbctl](https://github.com/Foxboron/sbctl) — ключи и подпись для Secure Boot

### Hyprland и оболочка

- [Hyprland](https://github.com/hyprwm/Hyprland)
- [uwsm](https://github.com/Vladimir-csp/uwsm)
- [Caelestia shell](https://github.com/caelestia-dots/shell)
- [caelestia-cli](https://github.com/caelestia-dots/cli)
- [Quickshell](https://github.com/quickshell-mirror/quickshell)
- [libcava (AUR)](https://aur.archlinux.org/packages/libcava)
- [qt6-m3shapes-git (AUR)](https://aur.archlinux.org/packages/qt6-m3shapes-git)
- [gpu-screen-recorder](https://git.dec05eba.com/gpu-screen-recorder)
- [dart-sass](https://github.com/sass/dart-sass)
- [fuzzel](https://codeberg.org/dnkl/fuzzel)
- [foot](https://codeberg.org/dnkl/foot)
- [grim](https://git.sr.ht/~emersion/grim)
- [slurp](https://github.com/emersion/slurp)
- [swappy](https://github.com/jtheoof/swappy)
- [wl-clipboard](https://github.com/bugaevc/wl-clipboard)
- [cliphist](https://github.com/sentriz/cliphist)
- [brightnessctl](https://github.com/Hummer12007/brightnessctl)
- [ddcutil](https://github.com/rockowitz/ddcutil)

### Экран входа, темы, шрифты

- [greetd](https://git.sr.ht/~kennylevinsen/greetd)
- [ReGreet](https://github.com/rharish101/ReGreet)
- [cage](https://github.com/cage-kiosk/cage)
- [adw-gtk3](https://github.com/lassekongo83/adw-gtk3)
- [Papirus icon theme](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme)
- [Bibata cursor](https://github.com/ful1e5/Bibata_Cursor)
- [ttf-material-symbols-variable-git (AUR)](https://aur.archlinux.org/packages/ttf-material-symbols-variable-git)
- [ttf-rubik-vf (AUR)](https://aur.archlinux.org/packages/ttf-rubik-vf)

### Утилиты командной строки

- [fish](https://github.com/fish-shell/fish-shell)
- [Neovim](https://github.com/neovim/neovim)
- [yazi](https://github.com/sxyazi/yazi)
- [btop](https://github.com/aristocratos/btop)
- [nvtop](https://github.com/Syllo/nvtop)
- [fastfetch](https://github.com/fastfetch-cli/fastfetch)
- [fd](https://github.com/sharkdp/fd)
- [bat](https://github.com/sharkdp/bat)
- [eza](https://github.com/eza-community/eza)
- [ripgrep](https://github.com/BurntSushi/ripgrep)
- [fzf](https://github.com/junegunn/fzf)
- [zoxide](https://github.com/ajeetdsouza/zoxide)
- [resvg](https://github.com/linebender/resvg)
- [tmux](https://github.com/tmux/tmux)
- [lazygit](https://github.com/jesseduffield/lazygit)
- [GitHub CLI](https://github.com/cli/cli)

### Игры

- [gamescope](https://github.com/ValveSoftware/gamescope)
- [GameMode](https://github.com/FeralInteractive/gamemode)
- [MangoHud](https://github.com/flightlessmango/MangoHud)
- [GOverlay](https://github.com/benjamimgois/goverlay)
- [Lutris](https://github.com/lutris/lutris)
- [Wine-Staging](https://github.com/wine-staging/wine-staging)
- [Winetricks](https://github.com/Winetricks/winetricks)
- [scx (sched_ext)](https://github.com/sched-ext/scx)
- [s-tui](https://github.com/amanusk/s-tui)
- [radeontop](https://github.com/clbr/radeontop) (только AMD)

### Виртуализация

- [QEMU](https://gitlab.com/qemu-project/qemu)
- [libvirt](https://github.com/libvirt/libvirt)
- [virt-manager](https://github.com/virt-manager/virt-manager)
- [libguestfs](https://github.com/libguestfs/libguestfs)
- [virtio-win](https://github.com/virtio-win/virtio-win-pkg-scripts)

### Приложения

- [Thunar](https://gitlab.xfce.org/xfce/thunar)
- [VSCodium](https://github.com/VSCodium/vscodium)
- [OBS Studio](https://github.com/obsproject/obs-studio)
- [Telegram Desktop](https://github.com/telegramdesktop/tdesktop)
- [qBittorrent](https://github.com/qbittorrent/qBittorrent)
- [VeraCrypt](https://github.com/veracrypt/VeraCrypt)
- [HandBrake](https://github.com/HandBrake/HandBrake)
- [KeePassXC](https://github.com/keepassxreboot/keepassxc)
- [Celluloid](https://github.com/celluloid-player/celluloid)
- [ZeroTier](https://github.com/zerotier/ZeroTierOne)
- [HardInfo2](https://github.com/hardinfo2/hardinfo2)
- [MarkText](https://github.com/marktext/marktext)
- [Karing](https://github.com/KaringX/karing)
- [UxPlay](https://github.com/FDH2/UxPlay)
- [Modrinth App](https://github.com/modrinth/code)
- [TeamSpeak (AUR)](https://aur.archlinux.org/packages/teamspeak)
