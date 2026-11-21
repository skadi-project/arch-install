# Arch Linux + Caelestia

## Быстрый запуск через git

Подходит, если Arch уже установлен (см. раздел «Установка Arch» ниже), создан пользователь с `sudo` и работает сеть. Скрипт `install_caelestia.sh` автоматизирует настройку Caelestia, Hyprland, greetd/ReGreet, приложений, инструментов разработки, видеодрайверов, игровых пакетов и виртуализации. Смену ядра на CachyOS он не выполняет: это отдельный необязательный шаг (раздел «Смена ядра на CachyOS» в конце).

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
chmod +x install_caelestia.sh
./install_caelestia.sh
```

4. После завершения перезагрузитесь, чтобы применились группы `docker`/`libvirt`/`kvm`, настройки видеодрайвера и появился экран входа ReGreet:

```bash
sudo reboot
```

Что нужно знать перед запуском:

- Пакеты ставятся с `--noconfirm`, а AUR-пакеты и Caelestia shell могут устанавливаться долго.
- Репозиторий `multilib` скрипт включает сам.
- Скрипт автоматически устанавливает и настраивает greetd/ReGreet, а также включает `greetd.service` без немедленного переключения текущей сессии.
- Если нужен фон экрана входа, заранее положите картинку в `/usr/share/backgrounds/greeter.jpg`. Скрипт добавит её в конфигурацию ReGreet.
- При повторном запуске скрипт заново создаёт `/etc/greetd/config.toml` и `/etc/greetd/regreet.toml`, поэтому пользовательские изменения в этих файлах нужно сохранить отдельно.
- Если уже включён другой менеджер входа (sddm, gdm, ly), сначала отключите его: `sudo systemctl disable sddm`.

Обновить репозиторий позже: `git pull`.

## Выбор видеодрайвера

По умолчанию установщик использует `GPU_MODE=auto`. Он определяет производителей графических устройств по PCI ID через `lspci`. Если найден один поддерживаемый производитель, скрипт выбирает его автоматически. Если найдено несколько или ни одного, открывается меню.

| `GPU_MODE`               | Поведение                                                                                                                       |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| `auto`                   | Автоопределение с переходом в меню при неоднозначном результате.                                                                |
| `ask`                    | Всегда открыть меню.                                                                                                            |
| `amd`, `intel`, `nvidia` | Установить указанный набор драйверов.                                                                                           |
| `all`                    | Установить наборы для всех обнаруженных поддерживаемых производителей. Подходит для гибридной графики, например Intel + NVIDIA. |
| `skip`                   | Пропустить отдельный шаг установки видеодрайверов. Другие пакеты могут установить графические зависимости.                      |

Выберите одну команду запуска:

```bash
GPU_MODE=ask ./install_caelestia.sh
GPU_MODE=all ./install_caelestia.sh
GPU_MODE=amd ./install_caelestia.sh
GPU_MODE=skip ./install_caelestia.sh
```

Для запуска без терминала задайте производителя явно, используйте `skip` или `all`, если обнаруживается хотя бы один поддерживаемый GPU. Если `auto` потребует меню, установщик завершится с ошибкой.

Для NVIDIA скрипт выбирает `nvidia-open-dkms` или `nvidia-dkms` по тексту `lspci`. Совместимость модели и наличие пакета нужно проверить. Заголовки выбираются по `uname -r` с возможностью переопределения через `KERNEL_HEADERS`. Проверьте поддержку модели открытыми модулями NVIDIA. Для неподдерживаемой карты выберите `skip` и настройте подходящий драйвер вручную. Для другого ядра нужны соответствующие заголовки.

После перезагрузки выполните `vulkaninfo --summary` в графической сессии. Для NVIDIA дополнительно выполните `nvidia-smi`.

Для справки используйте `--help`. Режим `--dry-run` не является полностью безопасным предпросмотром: он не выполняет часть вызовов `pacman` и `systemctl`, но всё ещё может запросить `sudo`, изменить `multilib`, запускать `rustup`, `makepkg`, `paru` и `caelestia install`. Не используйте его на системе, которую нельзя изменять.

```bash
# Показать справку
./install_caelestia.sh --help
```

Журнал установки сохраняется в файл `~/arch-install-<дата-время>.log`, если установка дошла до этапа настройки журнала. Для выбора нужных заголовков ядра можно передать `KERNEL_HEADERS=linux-lts-headers`.

## Установка Arch

### 1 Перед установкой

```bash
loadkeys ru
```

### 2 Интернет

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

### 3 Время

```bash
timedatectl
```

### 4 Подготовка диска

```bash
lsblk # Найти нужный диск /dev/###
fdisk /dev/sda
```

#### 4.1 Разметка

##### 4.1.1 UEFI

```bash
Command (m for help): p      # посмотреть текущую разметку
Command (m for help): g      # новая GPT-таблица (удаляет все разделы)

# ESP
Command (m for help): n
Partition number: 1
First sector: (Enter)
Last sector: +1G
# на вопрос про сигнатуру отвечаем Y
Command (m for help): t
Partition type or alias: 1       # EFI System

# swap
Command (m for help): n
Partition number: 2
First sector: (Enter)
Last sector: +8G
Command (m for help): t
Partition number: 2
Partition type or alias: 19      # Linux swap

# корень
Command (m for help): n
Partition number: 3
First sector: (Enter)
Last sector: (Enter)
Command (m for help): t
Partition number: 3
Partition type or alias: 23      # Linux root (x86-64)

Command (m for help): w          # сохранить
```

Разделы: `/dev/sda1` — EFI, `/dev/sda2` — swap, `/dev/sda3` — корень.

##### 4.1.2 BIOS

```bash
Command (m for help): p      # посмотреть текущую разметку
Command (m for help): o      # новая MBR-таблица (удаляет все разделы)

# swap
Command (m for help): n
Select: p
Partition number: 1
First sector: (Enter)
Last sector: +8G
Command (m for help): t
Partition number: 1
Hex code or alias: 82            # Linux swap

# корень
Command (m for help): n
Select: p
Partition number: 2
First sector: (Enter)
Last sector: (Enter)
# тип по умолчанию 83 (Linux) подходит, менять его не нужно

Command (m for help): w          # сохранить
```

Разделы: `/dev/sda1` — swap, `/dev/sda2` — корень.

> Secure Boot работает только в режиме UEFI. Для BIOS этот вариант недоступен.

#### 4.2 Файловая система корня

Выберите один вариант: ext4 (проще) или btrfs (сжатие, снапшоты, подтома).

Сначала укажите раздел корня:

```bash
ROOT=/dev/sda3   # UEFI
ROOT=/dev/sda2   # BIOS
```

##### 4.2.1 Вариант 1: ext4

```bash
mkfs.ext4 $ROOT
mount $ROOT /mnt
```

##### 4.2.2 Вариант 2: btrfs

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

#### 4.3 Загрузочный раздел и swap

##### 4.3.1 UEFI

```bash
mkfs.fat -F 32 /dev/sda1
mkswap /dev/sda2

mount --mkdir /dev/sda1 /mnt/boot
swapon /dev/sda2
```

##### 4.3.2 BIOS

```bash
mkswap /dev/sda1
swapon /dev/sda1
```

### 5 Установка системы

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

### 6 Конфигурация

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

### 7 Установка загрузчика

#### 7.1 BIOS

```bash
grub-install --target=i386-pc /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg
```

#### 7.2 UEFI

```bash
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=arch
grub-mkconfig -o /boot/grub/grub.cfg
```

#### 7.3 UEFI + Secure Boot (systemd-boot + sbctl)

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

### 8 Завершение установки

Выйдите из chroot, отмонтируйте разделы и перезагрузитесь (извлеките установочный носитель):

```bash
exit
umount -R /mnt
reboot
```

После первой загрузки войдите под созданным пользователем и переходите к разделу «Настройка чистой системы». Если выбрали вариант с Secure Boot, сначала выполните шаги из следующего раздела.

### 9 Secure Boot: ключи и подпись

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

## 10 Настройка чистой системы

Все шаги ниже описывают действия `install_caelestia.sh` и их ручные эквиваленты. Смена ядра вынесена в отдельный раздел в конце. Если ставите вручную, выполняйте шаги по порядку: AUR-пакеты, включая курсор для экрана входа, требуют `paru`.

### 10.1 Подготовка системы

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

### 10.2 AUR-хелпер paru

```bash
sudo pacman -S --needed rustup
rustup default stable
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si --noconfirm
cd .. && rm -rf paru
```

### 10.3 Hyprland и десктопное окружение

Панель, лаунчер и виджеты даёт Caelestia shell.

```bash
sudo pacman -S --needed hyprland uwsm xorg-xwayland xorg-xlsclients \
  xorg-xwininfo qt5-wayland qt6-wayland qt6-base qt6-declarative \
  qt6-imageformats qt6-shadertools glib2 glibc gcc-libs libpipewire \
  aubio libqalculate networkmanager power-profiles-daemon brightnessctl \
  ddcutil lm_sensors libnotify grim slurp swappy wl-clipboard cliphist \
  fuzzel dart-sass
```

#### 10.3.1 Звук

```bash
sudo pacman -S --needed pipewire wireplumber pipewire-pulse pavucontrol
```

#### 10.3.2 Шрифты

```bash
sudo pacman -S --needed noto-fonts noto-fonts-emoji ttf-nerd-fonts-symbols \
  ttf-jetbrains-mono-nerd ttf-cascadia-code-nerd
```

### 10.4 Экран входа: greetd + ReGreet

`cage` — минимальный Wayland-композитор, внутри которого запускается greeter. Тема и иконки ставятся системно, потому что пользователь `greeter` не видит `~/.themes` и `~/.icons`.

```bash
sudo pacman -S --needed greetd greetd-regreet cage gtk4 adw-gtk-theme \
  papirus-icon-theme nwg-look
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

При ручной настройке для фона экрана входа положите картинку в `/usr/share/backgrounds/greeter.jpg` и добавьте в начало `regreet.toml`. При запуске `install_caelestia.sh` секция добавляется автоматически, если файл уже существует.

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

### 10.5 Приложения и утилиты командной строки

```bash
sudo pacman -S --needed firefox foot fish bash neovim \
  thunar thunar-volman thunar-archive-plugin gvfs tumbler \
  xarchiver 7zip unzip \
  btop nvtop ncdu inxi fastfetch \
  fd bat eza ripgrep fzf zoxide yazi jq \
  ffmpeg poppler resvg imagemagick

# Смена оболочки
chsh -s /usr/bin/fish
```

### 10.6 Пакеты для разработки

```bash
# C++
sudo pacman -S --needed gcc clang cmake ninja make gdb lldb valgrind \
  ccache cppcheck clang-tools-extra boost fmt
# Rust
sudo pacman -S --needed rustup rust-analyzer
rustup default stable
# Web
sudo pacman -S --needed nodejs uv npm pnpm typescript \
  typescript-language-server vscode-langservers-extracted eslint prettier
# Общее
sudo pacman -S --needed github-cli tmux lazygit
# SQL
# Docker
sudo pacman -S --needed docker docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

VSCodium ставится из AUR (см. раздел AUR).

> **Для btrfs:** образы виртуальных машин лучше хранить без copy-on-write. Выполните `sudo chattr +C /var/lib/libvirt/images` на пустом каталоге до создания в нём данных.

### 10.7 Игровые пакеты

Нужен включённый multilib (см. выше).

Графические драйверы для ручной установки (выберите свою видеокарту):

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

### 10.8 Виртуальные машины

`--ask 4` автоматически соглашается заменить `iptables` на `iptables-nft`.

```bash
sudo pacman -S --needed --ask 4 qemu-full libvirt virt-manager virt-viewer \
  dnsmasq swtpm edk2-ovmf dmidecode bridge-utils iptables-nft \
  openbsd-netcat spice-vdagent
sudo systemctl enable --now libvirtd.service
sudo usermod -aG libvirt,kvm $USER
sudo virsh net-autostart default
sudo virsh net-start default || true
```

Пакеты `virtio-win`, `libguestfs`, `guestfs-tools` и `virt-top` ставятся из AUR (см. ниже).

> **Для btrfs:** отключите copy-on-write для образов дисков (на пустом каталоге): `sudo chattr +C /var/lib/libvirt/images`.

### 10.9 AUR

Менеджер `paru` уже установлен выше. Всё ставится в конце, когда зависимости из репозиториев на месте:

```bash
paru -S --needed quickshell-git gpu-screen-recorder libcava \
  vscodium-bin \
  ttf-material-symbols-variable-git ttf-rubik-vf qt6-m3shapes-git \
  virtio-win libguestfs guestfs-tools virt-top \
  caelestia-cli
```

### 10.10 Caelestia shell

Для ручной установки оболочку можно собрать из исходников (нужны `cmake`, `ninja` и `gcc` из раздела «Пакеты для разработки») и разместить в конфиге Quickshell. Скрипт `install_caelestia.sh` устанавливает `caelestia-cli`, а затем запускает `caelestia install`, поэтому приведённые команды CMake при автоматической установке выполнять не нужно.

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

После установки `caelestia-cli` завершите настройку оболочки:

```bash
caelestia install
```

#### 10.10.1 Горячие клавиши

Лаунчер

| Клавиши                      | Действие        |
| ---------------------------- | --------------- |
| `Super` (нажать и отпустить) | Открыть лаунчер |

Рабочие столы

| Клавиши                                                                                | Действие                                 |
| -------------------------------------------------------------------------------------- | ---------------------------------------- |
| `Super + 1…9, 0`                                                                       | Перейти на рабочий стол 1–10             |
| `Super + Alt + 1…9, 0`                                                                 | Переместить окно на рабочий стол 1–10    |
| `Ctrl + Super + 1…9, 0`                                                                | Перейти в группу рабочих столов (×10)    |
| `Ctrl + Super + Alt + 1…9, 0`                                                          | Переместить окно в группу рабочих столов |
| `Super + Alt + S`, `Ctrl + Super + Shift + Up`                                         | Переместить окно в special workspace     |
| `Ctrl + Super + Shift + Down`                                                          | Вынести окно из special workspace        |
| `Super + Scroll Down`, `Ctrl + Super + Right`, `Super + Page_Down`                     | Следующий рабочий стол                   |
| `Super + Scroll Up`, `Ctrl + Super + Left`, `Super + Page_Up`                          | Предыдущий рабочий стол                  |
| `Super + Alt + Scroll Down`, `Super + Alt + Page_Down`, `Ctrl + Super + Shift + Right` | Окно на следующий рабочий стол           |
| `Super + Alt + Scroll Up`, `Super + Alt + Page_Up`, `Ctrl + Super + Shift + Left`      | Окно на предыдущий рабочий стол          |
| `Ctrl + Super + Scroll Down`                                                           | Следующая группа рабочих столов          |
| `Ctrl + Super + Scroll Up`                                                             | Предыдущая группа рабочих столов         |

Группы окон

| Клавиши                    | Действие                      |
| -------------------------- | ----------------------------- |
| `Alt + Tab`                | Следующее окно в группе       |
| `Shift + Alt + Tab`        | Предыдущее окно в группе      |
| `Ctrl + Alt + Tab`         | Следующая группа              |
| `Ctrl + Shift + Alt + Tab` | Предыдущая группа             |
| `Super + U`                | Вынести окно из группы        |
| `Super + Comma`            | Включить/выключить группу     |
| `Super + Shift + Comma`    | Заблокировать активную группу |

Действия с окнами

| Клавиши                                       | Действие                             |
| --------------------------------------------- | ------------------------------------ |
| `Super + Minus`, `Super + Alt + Left`         | Сдвинуть границу сплита влево        |
| `Super + Equal`, `Super + Alt + Right`        | Сдвинуть границу сплита вправо       |
| `Super + Shift + Minus`, `Super + Alt + Up`   | Сдвинуть границу сплита вверх        |
| `Super + Shift + Equal`, `Super + Alt + Down` | Сдвинуть границу сплита вниз         |
| `Super + ←/→/↑/↓`                             | Фокус на окно в направлении          |
| `Super + Shift + ←/→/↑/↓`                     | Переместить окно в направлении       |
| `Super + ЛКМ`, `Super + Z + ЛКМ`              | Перетаскивание окна                  |
| `Super + ПКМ`, `Super + X + ЛКМ`              | Изменение размера окна               |
| `Ctrl + Super + Backslash`                    | Центрировать окно                    |
| `Ctrl + Super + Alt + Backslash`              | Размер 55×70% экрана и центрирование |
| `Super + Alt + Backslash`                     | Режим «картинка в картинке»          |
| `Super + P`                                   | Закрепить окно                       |
| `Super + F`                                   | Полноэкранный режим                  |
| `Super + Alt + F`                             | Развернуть (maximise)                |
| `Super + Alt + Space`                         | Плавающий режим                      |
| `Super + Q`                                   | Закрыть окно                         |

Специальные рабочие столы

| Клавиши                 | Действие              |
| ----------------------- | --------------------- |
| `Super + S`             | Special workspace     |
| `Ctrl + Shift + Escape` | Системный монитор     |
| `Super + M`             | Музыка                |
| `Super + D`             | Общение (мессенджеры) |
| `Super + R`             | Todo                  |

Приложения

| Клавиши          | Действие                      |
| ---------------- | ----------------------------- |
| `Super + T`      | Терминал (foot)               |
| `Super + W`      | Браузер (firefox)             |
| `Super + C`      | Редактор (codium)             |
| `Super + E`      | Файловый менеджер (thunar)    |
| `Ctrl + Alt + V` | Настройки звука (pwvucontrol) |

Утилиты

| Клавиши                   | Действие                       |
| ------------------------- | ------------------------------ |
| `Print`                   | Скриншот                       |
| `Super + Shift + S`       | Скриншот (с заморозкой экрана) |
| `Super + Shift + Alt + S` | Скриншот области               |
| `Ctrl + Alt + R`          | Запись всего экрана            |
| `Super + Alt + R`         | Запись со звуком               |
| `Super + Shift + Alt + R` | Запись области                 |
| `Super + Shift + C`       | Пипетка (выбор цвета)          |

Медиа

| Клавиши                    | Действие                   |
| -------------------------- | -------------------------- |
| `Ctrl + Super + Space`     | Пауза/воспроизведение      |
| `Ctrl + Super + Equal`     | Следующий трек             |
| `Ctrl + Super + Minus`     | Предыдущий трек            |
| `Ctrl + Super + Backspace` | Остановить воспроизведение |
| `Super + Shift + M`        | Выключить звук             |

Разное

| Клавиши               | Действие                    |
| --------------------- | --------------------------- |
| `Ctrl + Alt + Delete` | Меню сессии                 |
| `Super + N`           | Боковая панель шелла        |
| `Ctrl + Alt + C`      | Очистить уведомления        |
| `Super + K`           | Показать все панели шелла   |
| `Super + L`           | Блокировка экрана           |
| `Super + Alt + L`     | Восстановить локскрин шелла |
| `Super + Shift + L`   | Команда сна (sleep)         |

Буфер обмена и эмодзи

| Клавиши                  | Действие                        |
| ------------------------ | ------------------------------- |
| `Super + V`              | История буфера обмена           |
| `Super + Alt + V`        | История буфера (режим удаления) |
| `Ctrl + Shift + Alt + V` | Вставить последнюю запись       |
| `Super + Period`         | Выбор эмодзи                    |

Шелл

| Клавиши                    | Действие           |
| -------------------------- | ------------------ |
| `Ctrl + Super + Alt + R`   | Перезапустить шелл |
| `Ctrl + Super + Shift + R` | Остановить шелл    |

Как изменить бинды

Все бинды (кроме перезапуска и остановки шелла) переопределяются через переменные в `~/.config/caelestia/hypr-vars.lua`.

#### Локальные конфиги Hyprland

Файлы из каталога `caelestia/` репозитория являются пользовательскими настройками Caelestia. Скопируйте их в `~/.config/caelestia/`: `hypr-vars.lua` предназначен для переопределения переменных, а `hypr-user.lua` — для дополнительной конфигурации Hyprland. Не редактируйте для этого файлы в `~/.config/hypr/`.

Выполните из корня клонированного репозитория:

```bash
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/caelestia"
cp caelestia/hypr-vars.lua "${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/"
cp caelestia/hypr-user.lua "${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/"
```

После копирования перезапустите сессию Hyprland или перезагрузите компьютер.

### 10.11 Дополнительно

Повседневные приложения:

```bash
sudo pacman -S --needed obs-studio telegram-desktop qbittorrent \
  libreoffice-still okular gimp veracrypt handbrake keepassxc celluloid \
  zerotier-one hardinfo2
sudo systemctl enable --now zerotier-one
```

Пакеты AUR:

```bash
sudo pacman -S --needed libayatana-indicator
paru -S --needed marktext-bin karing-bin teamspeak uxplay modrinth-app-bin
```

### 10.12 Перезагрузка

Перезагрузитесь: применятся группы `docker`/`libvirt`/`kvm` и настройки видеодрайвера. Экран входа ReGreet будет доступен после включения `greetd.service`.

```bash
sudo reboot
```

Убедитесь, что система работает на стандартном ядре. После этого при желании можно сменить ядро (следующий раздел).

## 11 Смена ядра на CachyOS (опционально)

Выполняйте после настройки системы и перезагрузки: обычное ядро `linux` останется запасным вариантом, если что-то пойдёт не так. Смену ядра выполняют вручную.

### 11.1 Подключите репозиторий CachyOS

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

### 11.2 Выберите и установите ядро

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

### 11.3 Добавьте ядро в загрузчик

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

### 11.4 Перезагрузитесь и проверьте

Выберите новое ядро в меню загрузчика, затем:

```bash
uname -r        # в выводе должно быть cachyos
dkms status     # модули собраны под новое ядро
nvidia-smi      # для NVIDIA
```

### 11.5 Удалите старое ядро (по желанию)

Только после того, как убедились, что всё работает на новом ядре:

```bash
sudo pacman -Rns linux linux-headers
```

- GRUB: повторите `sudo grub-mkconfig -o /boot/grub/grub.cfg`.
- systemd-boot: в `loader.conf` поставьте `default cachyos.conf` и удалите `/boot/loader/entries/arch.conf`.
- Secure Boot: уберите старый файл из базы подписей: `sudo sbctl remove-file /boot/vmlinuz-linux`.

### 11.6 Откат репозитория

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
