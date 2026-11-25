# Arch Linux + mandara

## Быстрый запуск через git

Подходит, если Arch уже установлен (см. раздел «Установка Arch» ниже), создан пользователь с `sudo` и работает сеть. Скрипт `install_mandara.sh` устанавливает mandara shell с compositor `mango`, приложения, инструменты разработки, видеодрайверов, игровые пакеты и виртуализацию. Смену ядра на CachyOS он не выполняет: это отдельный необязательный шаг (раздел «Смена ядра на CachyOS» в конце).

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
chmod +x install_mandara.sh
./install_mandara.sh
```

4. После завершения перезагрузитесь, чтобы применились группы `docker`/`libvirt`/`kvm` и настройки видеодрайвера:

```bash
sudo reboot
```

Что нужно знать перед запуском:

- Скрипт устанавливает mandara shell с compositor `mango`. Hyprland, Caelestia, greetd и ReGreet скрипт не устанавливает.
- Пакеты устанавливаются с `--noconfirm`, а сборка `paru` и части AUR-пакетов может занять много времени.
- Репозиторий `multilib` скрипт включает автоматически.
- Скрипт устанавливает `unzip` и `libayatana-indicator`, последний нужен для `karing-bin`.

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
GPU_MODE=ask ./install_mandara.sh
GPU_MODE=all ./install_mandara.sh
GPU_MODE=amd ./install_mandara.sh
GPU_MODE=skip ./install_mandara.sh
```

Для запуска без терминала задайте производителя явно, используйте `skip` или `all`, если обнаруживается хотя бы один поддерживаемый GPU. Если `auto` потребует меню, установщик завершится с ошибкой.

Для NVIDIA скрипт выбирает `nvidia-open-dkms` или `nvidia-dkms` по тексту `lspci`. Совместимость модели и наличие пакета нужно проверить. Заголовки выбираются по `uname -r` с возможностью переопределения через `KERNEL_HEADERS`. Проверьте поддержку модели открытыми модулями NVIDIA. Для неподдерживаемой карты выберите `skip` и настройте подходящий драйвер вручную. Для другого ядра нужны соответствующие заголовки.

После перезагрузки выполните `vulkaninfo --summary` в графической сессии. Для NVIDIA дополнительно выполните `nvidia-smi`.

Для справки используйте `--help`. Режим `--dry-run` не является полностью безопасным предпросмотром: он не выполняет часть вызовов `pacman` и `systemctl`, но всё ещё может запросить `sudo`, изменить `multilib`, запускать внешний установщик Mandara, `rustup`, `makepkg` и `paru`. Не используйте его на системе, которую нельзя изменять.

```bash
# Показать справку
./install_mandara.sh --help
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

##### 4.1.1. UEFI

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

Ниже приведены шаги ручной настройки и дополнительные варианты. `install_mandara.sh` рассчитан на уже работающую сеть. Команды для AMD, Intel и смены оболочки на fish приведены для ручной настройки.

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

### 10.2 Mandara и Mango

`install_mandara.sh` скачивает установщик Mandara по HTTPS во временный файл, запускает его с аргументами `--compositor mango` и удаляет файл. Состав графического окружения определяет внешний установщик. Для ручной установки используйте инструкцию проекта [Mandara](https://thehamdiz.github.io/mandara/).

#### 10.2.1 Горячие клавиши

**Основные клавиши Mandara**

| Комбинация            | Действие                         |
| --------------------- | -------------------------------- |
| `Super + Space`       | Открыть или закрыть launcher     |
| `Super + Alt + Space` | Открыть или закрыть launcher     |
| `Super + B`           | Показать или скрыть sidebar      |
| `Super + Shift + E`   | Открыть меню сессии и питания    |
| `Ctrl + Alt + Delete` | Открыть меню сессии и питания    |
| `Alt + Tab`           | Переключиться на следующее окно  |
| `Alt + Shift + Tab`   | Переключиться на предыдущее окно |

**Скриншоты**

| Комбинация          | Действие                      |
| ------------------- | ----------------------------- |
| `Print`             | Снимок всего экрана           |
| `Ctrl + Print`      | Выбрать область для скриншота |
| `Alt + Print`       | Снимок текущего окна          |
| `Super + Shift + S` | Выбрать область для скриншота |

**Буфер обмена**

| Комбинация          | Действие                                  |
| ------------------- | ----------------------------------------- |
| `Super + Shift + V` | Открыть или закрыть историю буфера обмена |
| `Alt + V`           | Открыть или закрыть историю буфера обмена |

**Внешний вид**

| Комбинация          | Действие                          |
| ------------------- | --------------------------------- |
| `Super + Shift + T` | Переключить светлую и тёмную тему |
| `Ctrl + Shift + W`  | Открыть или закрыть выбор обоев   |

**Звук**

| Клавиша                | Действие                        |
| ---------------------- | ------------------------------- |
| `XF86AudioMute`        | Выключить или включить звук     |
| `XF86AudioRaiseVolume` | Увеличить громкость             |
| `XF86AudioLowerVolume` | Уменьшить громкость             |
| `XF86AudioMicMute`     | Выключить или включить микрофон |

**Яркость**

| Клавиша                 | Действие          |
| ----------------------- | ----------------- |
| `XF86MonBrightnessUp`   | Увеличить яркость |
| `XF86MonBrightnessDown` | Уменьшить яркость |

Яркость внешнего монитора также может управляться через DDC/CI, если установлен `i2c-tools` и монитор это поддерживает.

**Управление медиа**

| Клавиша          | Действие                  |
| ---------------- | ------------------------- |
| `XF86AudioPlay`  | Воспроизведение или пауза |
| `XF86AudioPause` | Воспроизведение или пауза |
| `XF86AudioNext`  | Следующий трек            |
| `XF86AudioPrev`  | Предыдущий трек           |

На некоторых ноутбуках мультимедийные клавиши находятся на `F4–F6` и работают через `Fn`.

### 10.3 AUR-хелпер paru

Если `paru` уже работает, скрипт пропускает этот шаг. Для сборки из исходников сначала настройте Rust.

```bash
sudo pacman -S --needed rustup
rustup default stable
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si --noconfirm
cd .. && rm -rf paru
```

### 10.4 Выбор приложений и утилиты командной строки

При обычном запуске `install_mandara.sh` перед установкой открываются выборы:

| Категория | По умолчанию | Доступные варианты |
| --- | --- | --- |
| Файловый менеджер | `nautilus` | `thunar`, `nemo`, `pcmanfm-qt`, `yazi` |
| Терминал | `foot` | `kitty`, `alacritty`, `wezterm`, `ghostty` |
| Оболочка | `fish` | `bash`, `zsh`, `nushell` |
| Браузер | `firefox` | `chromium`, `brave`, `google-chrome`, `librewolf`, `qutebrowser` |
| Текстовые редакторы | `vscodium` и `neovim` | `helix`, `emacs`, `kate`, `gedit`, `micro`; выбрать один или оба |

Enter принимает значение по умолчанию. Для автоматического запуска задайте переменные:

```bash
FILE_MANAGER=nautilus \
TERMINAL=foot \
USER_SHELL=fish \
BROWSER=firefox \
TEXT_EDITORS='vscodium neovim' \
./install_mandara.sh
```

`TEXT_EDITORS` принимает один или несколько вариантов: `vscodium`, `neovim`, `helix`, `emacs`, `kate`, `gedit`, `micro`. При неинтерактивном запуске все пять переменных нужно задать явно. VSCodium устанавливается из AUR как `vscodium-bin`. `brave`, `google-chrome` и `librewolf` также устанавливаются из AUR; остальные выбранные приложения — из репозиториев Arch. Выбор `yazi` устанавливает терминальный файловый менеджер, а не GUI-приложение.

Пример с альтернативами:

```bash
FILE_MANAGER=nemo TERMINAL=alacritty USER_SHELL=zsh \
BROWSER=librewolf TEXT_EDITORS='helix neovim' \
./install_mandara.sh
```

Конфиг Foot из `mandara/foot/foot.ini` копируется в `${XDG_CONFIG_HOME:-$HOME/.config}/foot/foot.ini`. Перед заменой существующего файла создаётся резервная копия с суффиксом `.backup.<дата-время>`.

Остальные утилиты устанавливаются без выбора:

```bash
sudo pacman -S --needed 7zip unzip \
  btop nvtop ncdu inxi fastfetch \
  fd bat eza ripgrep fzf zoxide yazi jq \
  ffmpeg poppler resvg imagemagick \
  github-cli tmux lazygit nwg-look \
  obs-studio telegram-desktop qbittorrent \
  libreoffice-still okular gimp veracrypt handbrake keepassxc celluloid \
  zerotier-one hardinfo2
```

Скрипт не меняет login shell автоматически. Для ручной смены оболочки:

```bash
chsh -s /usr/bin/fish
```

### 10.5 Пакеты для разработки

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
# Docker
sudo pacman -S --needed docker docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

### 10.6 Игровые пакеты

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

При ручной настройке NVIDIA добавьте строку ниже в `/etc/modprobe.d/nvidia.conf`. При выборе NVIDIA скрипт создаёт `/etc/modprobe.d/arch-install-nvidia.conf`, если этого файла и `/etc/modprobe.d/nvidia.conf` ещё нет.

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
# С gamescope (полезно при проблемах с масштабированием в Wayland):
gamescope -W 2560 -H 1440 -r 144 -f -- gamemoderun mangohud %command%
```

### 10.7 Виртуальные машины

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

Скрипт и эта ручная команда продолжают работу при ошибке `virsh net-start default`, в том числе если сеть уже запущена.

Пакеты `virtio-win`, `libguestfs`, `guestfs-tools` и `virt-top` ставятся из AUR (см. ниже).

> **Для btrfs:** отключите copy-on-write для образов дисков (на пустом каталоге): `sudo chattr +C /var/lib/libvirt/images`.

### 10.8 AUR

Установите пакеты AUR после основных пакетов. `libayatana-indicator` устанавливается отдельно для Karing.

```bash
paru -S --needed \
  vscodium-bin \
  virtio-win libguestfs guestfs-tools virt-top \
  marktext-bin karing-bin teamspeak uxplay modrinth-app-bin
sudo pacman -S --needed libayatana-indicator
```

### 10.9 ZeroTier

```bash
sudo systemctl enable --now zerotier-one
```

### 10.10 Перезагрузка

Перезагрузитесь: применятся группы `docker`/`libvirt`/`kvm`, настройки видеодрайвера.

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

Ядра отличаются планировщиком (BORE или EEVDF) и способом сборки. Для игр и NVIDIA подойдёт `linux-cachyos` или `linux-cachyos-bore`.

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

### Графическое окружение

- [Mandara](https://thehamdiz.github.io/mandara/)
- [foot](https://codeberg.org/dnkl/foot)

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
