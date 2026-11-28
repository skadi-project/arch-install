# Arch Linux + mandara: установка рядом с Windows (dual-boot)

Отдельная инструкция по установке Arch Linux на компьютер, где уже стоит Windows, и по настройке времени, чтобы оно не «слетало» при переключении между системами. Подходит для оболочки mandara (compositor `mango`): после установки Arch и загрузчика остаётся запустить `install_mandara.sh` (шаг 13). Остальные настройки системы, горячие клавиши и смена ядра описаны в основном README.

Что входит в инструкцию:

- установка Arch рядом с Windows в трёх режимах: BIOS (MBR), UEFI, UEFI + Secure Boot;
- подготовка Windows (BitLocker, быстрый запуск, свободное место);
- загрузчики: GRUB и systemd-boot (+ `sbctl` для Secure Boot);
- синхронизация времени между Windows и Linux, чтобы часы не «слетали»;
- выбор системы при загрузке, порядок загрузки, типичные неполадки.

Порядок: **сначала Windows, потом Arch.** Установщик Windows и крупные обновления могут перезаписать загрузчик и порядок загрузки. Это поправимо из live-образа Arch (chroot и переустановка загрузчика), но проще ставить Windows первой. Перед началом сделайте резервную копию важных данных.

## 0 Выберите сценарий

Arch нужно устанавливать в том же режиме, в котором загружается Windows. Windows в UEFI стоит на диске с GPT, Windows в режиме BIOS (Legacy/CSM) — на диске с MBR. Смешивать режимы нельзя: система не загрузится.

| Режим                      | Таблица разделов | Загрузчик Arch         | Windows в меню                                          |
| -------------------------- | ---------------- | ---------------------- | ------------------------------------------------------- |
| BIOS                       | MBR              | GRUB                   | `os-prober`                                             |
| UEFI, Secure Boot выключен | GPT              | GRUB или systemd-boot  | `os-prober` (GRUB) или автоматически (systemd-boot)     |
| UEFI + Secure Boot         | GPT              | systemd-boot + `sbctl` | Автоматически, нужны ключи Microsoft (`enroll-keys -m`) |

Как узнать режим Windows: `Win + R`, команда `msinfo32`, строки «Режим BIOS» (UEFI или Устаревший) и «Состояние безопасной загрузки» (Вкл./Откл.).

Windows 10 (1703) и новее можно перевести с MBR на GPT без переустановки, после чего в прошивке включается UEFI и отключается CSM. Сначала сделайте резервную копию, затем в консоли от администратора:

```
mbr2gpt /validate /allowFullOS
mbr2gpt /convert /allowFullOS
```

## 1 Подготовка Windows

Выполняется в Windows. Команды запускайте в консоли от имени администратора.

**1.1 BitLocker.** Проверьте, включено ли шифрование: `manage-bde -status`. В Windows 11 оно часто включается автоматически (Device Encryption). Смена режима загрузки и ключей Secure Boot меняет измерения TPM, и Windows при следующей загрузке может потребовать ключ восстановления. Заранее сохраните ключ (<https://aka.ms/myrecoverykey>) и приостановите защиту на время установки:

```
manage-bde -protectors -disable C: -RebootCount 0
```

Когда установка завершена и обе системы грузятся, верните защиту: `manage-bde -protectors -enable C:`. Если параметр `-RebootCount 0` не поддерживается в вашей сборке Windows, расшифруйте диск на время установки.

**1.2 Быстрый запуск и гибернация.** После «выключения» с быстрым запуском Windows оставляет NTFS в состоянии гибернации. Linux смонтирует такой том только для чтения или откажется монтировать, а запись из Linux может повредить данные. Отключите гибернацию вместе с быстрым запуском:

```
powercfg /h off
```

Если гибернация нужна, отключите только быстрый запуск: «Панель управления → Электропитание → Действия кнопок питания → Изменение параметров, которые сейчас недоступны → снять «Включить быстрый запуск»».

**1.3 Свободное место.** `Win + X` → «Управление дисками» (`diskmgmt.msc`) → правый клик по тому `C:` → «Сжать том». Освободите место под корень Linux (от 50 ГБ) и swap. Оставьте область «Не распределена»: ничего в ней не создавайте и не форматируйте. Если Windows не даёт сжать том достаточно сильно, временно отключите файл подкачки и защиту системы и перезагрузитесь.

**1.4 Запишите установочный носитель Arch** на флешку и перезагрузите компьютер.

## 2 Прошивка и live-образ

**2.1 Secure Boot.** Стандартный live-образ Arch не подписан для Secure Boot. Если Secure Boot включён, на время установки отключите его в прошивке. Для сценария «UEFI + Secure Boot» вместо этого переведите прошивку в **Setup Mode**: очистите ключи («Erase / Clear Secure Boot Keys», «Custom mode») и оставьте Secure Boot выключенным. Названия пунктов зависят от производителя. В Setup Mode подписи не проверяются, поэтому live-образ и Windows загружаются.

**2.2 Загрузка в нужном режиме.** В boot-меню прошивки (`F12`, `Esc` или `F8`, зависит от производителя) для UEFI выбирайте запись флешки с приставкой `UEFI`, для BIOS — без неё. Убедитесь, что режим совпадает с режимом Windows:

```bash
[ -d /sys/firmware/efi ] && echo UEFI || echo BIOS
```

**2.3 Раскладка, сеть, время.**

```bash
loadkeys ru
```

При подключении через провод сеть поднимется сама. Wi-Fi настраивается через `iwctl` (входит в live-образ):

```bash
iwctl
```

Команды внутри `iwctl` (приглашение `[iwd]#`):

```bash
device list                         # имя адаптера, обычно wlan0
station wlan0 scan
station wlan0 get-networks
station wlan0 connect "Имя_сети"    # попросит пароль
exit
```

Если адаптер не виден или выключен: `rfkill unblock wifi`, затем `iwctl device wlan0 set-property Powered on`. Проверка:

```bash
ping -c 3 archlinux.org
timedatectl                         # System clock synchronized: yes
```

> `iwd` из live-образа в установленную систему не переносится: там сетью управляет NetworkManager (см. шаг 8).

## 3 Разметка диска

Команды `g` и `o`, которыми обычно создают новую таблицу разделов, удаляют все разделы вместе с Windows. Здесь их выполнять нельзя: новые разделы создаются только в свободном месте.

> **Arch на отдельном диске.** Если Windows стоит на одном диске, а Arch вы ставите на другой, диск с Windows не трогайте. На втором диске можно создать таблицу с нуля (`g` для UEFI, `o` для BIOS) вместе со своим ESP. Перед `g` и `o` убедитесь по `lsblk`, что выбран правильный диск. Выбирать систему можно через boot-меню прошивки (`F12`) или, с GRUB, через `os-prober`.

### 3.1 Исходные данные

Укажите диск с Windows и сохраните копию его таблицы разделов. Копия лежит в памяти live-образа и пропадёт после перезагрузки, поэтому при желании скопируйте её на другой носитель. Восстановление: `sfdisk $DISK < ~/partition-table-backup.txt`.

```bash
DISK=/dev/nvme0n1                                    # диск с Windows (для SATA: /dev/sda)
sfdisk --dump $DISK > ~/partition-table-backup.txt
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME,LABEL $DISK   # текущая разметка
```

**Только UEFI:** найдите существующий EFI-раздел Windows и узнайте его размер.

```bash
ESP=$(lsblk -prno NAME,PARTTYPENAME $DISK | awk '/EFI System/ {print $1; exit}')
echo "$ESP: $(( $(lsblk -bndo SIZE $ESP) / 1048576 )) МиБ"
```

Windows создаёт ESP на 100 МиБ (на дисках 4Kn — 260 МиБ), у некоторых производителей он больше. Ядра и образы initramfs на маленький ESP не поместятся, поэтому схема зависит от размера и загрузчика:

| Сценарий | Режим | Загрузчик    | Размер ESP            | Свои разделы Arch         |
| -------- | ----- | ------------ | --------------------- | ------------------------- |
| A        | UEFI  | GRUB         | любой                 | swap, корень              |
| B        | UEFI  | systemd-boot | от 512 МиБ            | swap, корень              |
| C        | UEFI  | systemd-boot | меньше 512 МиБ        | XBOOTLDR (1 ГиБ), swap, корень |
| D        | BIOS  | GRUB         | не используется       | swap, корень              |

Для Secure Boot подходят сценарии B и C.

Где что окажется после монтирования:

| Сценарий | `/boot`                 | `/efi`          |
| -------- | ----------------------- | --------------- |
| A        | каталог на корне        | ESP Windows     |
| B        | ESP Windows             | не используется |
| C        | XBOOTLDR                | ESP Windows     |
| D        | каталог на корне        | не используется |

### 3.2 Сценарии A и B (UEFI): swap и корень

Откройте диск в `fdisk` и создайте два раздела в области, которую вы освободили в Windows. Таблицу разделов не создавайте заново (`g` не нужен).

```bash
fdisk $DISK
```

Сначала посмотрите свободное место командой `F` и запомните начало нужной области. На шаге `First sector` значение по умолчанию (Enter) обычно верное. Если оно не совпадает с началом освобождённой области (например, `fdisk` предлагает мелкий промежуток между разделами Windows), введите начальный сектор из вывода `F`.

```
Command (m for help): p      # убедитесь, что видны разделы Windows
Command (m for help): F      # свободное место: начало и размер областей

# swap
Command (m for help): n
Partition number: (Enter)    # первый свободный номер
First sector: (Enter)        # или начальный сектор из вывода F
Last sector: +8G
Command (m for help): t
Partition number: (Enter)    # по умолчанию последний созданный раздел
Partition type or alias: 19  # Linux swap

# корень
Command (m for help): n
Partition number: (Enter)
First sector: (Enter)
Last sector: (Enter)         # весь остаток или +размер, например +80G
Command (m for help): t
Partition number: (Enter)
Partition type or alias: 23  # Linux root (x86-64)

Command (m for help): p      # проверьте итоговую таблицу
Command (m for help): w      # сохранить
```

Узнайте имена новых разделов и задайте переменные (номера зависят от вашей разметки: если у Windows разделы `p1`–`p4`, новые будут `p5` и `p6`):

```bash
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME $DISK
SWAP=/dev/nvme0n1p5          # подставьте свои имена из вывода lsblk
ROOT=/dev/nvme0n1p6
```

### 3.3 Сценарий C (UEFI): XBOOTLDR, swap и корень

Для ESP меньше 512 МиБ добавляется раздел XBOOTLDR под `/boot`. Создайте его первым, затем swap и корень. Ввод для swap и корня тот же, что в 3.2.

```bash
fdisk $DISK
```

```
Command (m for help): p
Command (m for help): F      # свободное место

# XBOOTLDR
Command (m for help): n
Partition number: (Enter)
First sector: (Enter)        # или начальный сектор из вывода F
Last sector: +1G
Command (m for help): t
Partition number: (Enter)
Partition type or alias: L   # откроется список типов: найдите «Linux extended boot»
                             # и введите его номер (в разных версиях fdisk номер отличается)

# swap (как в 3.2)
Command (m for help): n
Partition number: (Enter)
First sector: (Enter)
Last sector: +8G
Command (m for help): t
Partition number: (Enter)
Partition type or alias: 19  # Linux swap

# корень (как в 3.2)
Command (m for help): n
Partition number: (Enter)
First sector: (Enter)
Last sector: (Enter)
Command (m for help): t
Partition number: (Enter)
Partition type or alias: 23  # Linux root (x86-64)

Command (m for help): p      # проверьте итоговую таблицу
Command (m for help): w      # сохранить
```

```bash
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME $DISK
XBOOT=/dev/nvme0n1p5         # подставьте свои имена из вывода lsblk
SWAP=/dev/nvme0n1p6
ROOT=/dev/nvme0n1p7
```

### 3.4 Сценарий D (BIOS, MBR)

Работайте в `fdisk`. Сначала посмотрите, сколько основных разделов уже занято: `fdisk -l $DISK`. В MBR допускается не больше 4 основных разделов. У Windows обычно 2 («Зарезервировано системой» и `C:`), иногда 3 (с разделом восстановления). Флаг boot (active) у разделов Windows не трогайте.

**D1. Занято 2 основных раздела** (swap и корень — третий и четвёртый основные):

```bash
fdisk $DISK
```

```
Command (m for help): p      # убедитесь, что есть свободное место

# swap
Command (m for help): n
Select: p
Partition number: (Enter)
First sector: (Enter)
Last sector: +8G
Command (m for help): t
Partition number: (Enter)    # по умолчанию последний созданный раздел
Hex code or alias: 82        # Linux swap

# корень
Command (m for help): n
Select: p
Partition number: (Enter)
First sector: (Enter)
Last sector: (Enter)         # весь остаток или +размер
# тип по умолчанию 83 (Linux) подходит, менять его не нужно

Command (m for help): w      # сохранить
```

```bash
lsblk -o NAME,SIZE,FSTYPE,TYPE $DISK
SWAP=/dev/sda3               # подставьте свои имена из вывода lsblk
ROOT=/dev/sda4
```

**D2. Занято 3 основных раздела.** Свободен один слот, поэтому создайте расширенный раздел на всё свободное место, а swap и корень сделайте логическими:

```
Command (m for help): n
Select: e                    # extended
Partition number: (Enter)    # 4
First sector: (Enter)
Last sector: (Enter)         # всё свободное место

# swap (логический)
Command (m for help): n      # fdisk сам создаст логический раздел (номер 5)
First sector: (Enter)
Last sector: +8G
Command (m for help): t
Partition number: (Enter)
Hex code or alias: 82        # Linux swap

# корень (логический)
Command (m for help): n
First sector: (Enter)
Last sector: (Enter)

Command (m for help): w      # сохранить
```

```bash
lsblk -o NAME,SIZE,FSTYPE,TYPE $DISK
SWAP=/dev/sda5               # подставьте свои имена из вывода lsblk
ROOT=/dev/sda6
```

Если заняты все 4 основных раздела, свободного слота нет. Выход: удалить ненужный раздел (например, восстановления производителя) в «Управлении дисками» Windows либо перевести диск на GPT и UEFI (`mbr2gpt`, см. раздел 0).

## 4 Форматирование и монтирование

Порядок: сначала форматируется и монтируется корень (4.1 или 4.2), затем swap и загрузочные разделы по своему сценарию (4.3). **`mkfs.fat` для существующего ESP Windows не выполняйте**: форматирование сделает Windows незагружаемой. `mkfs.fat` допустим только для нового раздела XBOOTLDR (сценарий C).

### 4.1 Корень: вариант 1, ext4

```bash
mkfs.ext4 $ROOT
mount $ROOT /mnt
```

### 4.2 Корень: вариант 2, btrfs

Сжатие, снапшоты, подтома.

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

### 4.3 Swap и загрузочные разделы

Корень уже смонтирован в `/mnt`. Выполните блок своего сценария.

**Сценарий A: UEFI + GRUB, ESP любого размера** (ESP в `/efi`, ядра на корне):

```bash
mkswap $SWAP
swapon $SWAP
mount --mkdir $ESP /mnt/efi        # без mkfs.fat!
findmnt -R /mnt                    # проверка: корень и /mnt/efi
```

**Сценарий B: UEFI + systemd-boot, ESP от 512 МиБ** (ESP в `/boot`):

```bash
mkswap $SWAP
swapon $SWAP
mount --mkdir $ESP /mnt/boot       # без mkfs.fat!
df -h /mnt/boot                    # свободно должно быть не меньше ~300 МиБ
findmnt -R /mnt
```

Если свободного места на ESP не хватает, отмонтируйте его (`umount /mnt/boot`) и перейдите к сценарию C: создайте XBOOTLDR по 3.3.

**Сценарий C: UEFI + systemd-boot, ESP меньше 512 МиБ** (ESP в `/efi`, ядра на XBOOTLDR в `/boot`):

```bash
mkswap $SWAP
swapon $SWAP
mkfs.fat -F 32 -n XBOOTLDR $XBOOT  # форматируем только новый раздел
mount --mkdir $XBOOT /mnt/boot
mount --mkdir $ESP /mnt/efi        # ESP Windows, без mkfs.fat!
findmnt -R /mnt
```

**Сценарий D: BIOS + GRUB** (отдельных загрузочных разделов нет, `/boot` лежит на корне):

```bash
mkswap $SWAP
swapon $SWAP
findmnt -R /mnt
```

## 5 Установка базовой системы

Замените `amd-ucode` на `intel-ucode`, если у вас процессор Intel.

```bash
pacstrap -K /mnt base base-devel linux linux-firmware dosfstools \
  e2fsprogs pciutils usbutils amd-ucode nano man-db man-pages

# Только btrfs:
pacstrap -K /mnt btrfs-progs
# Только Secure Boot:
pacstrap -K /mnt sbctl
```

## 6 Конфигурация

```bash
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot -S /mnt

# Найти временную зону: ls /usr/share/zoneinfo/Europe
ln -sf /usr/share/zoneinfo/Europe/Ulyanovsk /etc/localtime
hwclock --systohc               # RTC хранит UTC, настройка Windows под это описана в разделе 10

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
```

Проверьте `/etc/fstab`: в нём должны быть корень (для btrfs — строки с `subvol=@`, `subvol=@home` и т.д.) и ESP (`/efi` или `/boot`), при необходимости XBOOTLDR. Разделы Windows в fstab добавлять не нужно.

Для systemd-boot в строках ESP и XBOOTLDR замените `fmask=0022,dmask=0022` на `umask=0077`: иначе `bootctl` предупредит, что файл случайного числа доступен всем. Это влияет только на права доступа в Linux и не затрагивает Windows.

Пакеты зависят от загрузчика:

```bash
# GRUB (BIOS и UEFI). Для BIOS efibootmgr можно не ставить
pacman -S networkmanager grub efibootmgr os-prober ntfs-3g

# systemd-boot (UEFI, с Secure Boot или без)
pacman -S networkmanager efibootmgr
```

`os-prober` и `ntfs-3g` нужны GRUB, чтобы найти Windows. `efibootmgr` пригодится для исправления порядка загрузки.

## 7 Загрузчик

В chroot переменные из live-окружения не сохраняются, поэтому разделы указывайте явно (или задайте переменные заново).

### 7.1 BIOS + GRUB

В `/etc/default/grub` раскомментируйте или добавьте строку (с версии GRUB 2.06 поиск других систем по умолчанию выключен):

```
GRUB_DISABLE_OS_PROBER=false
```

```bash
grub-install --target=i386-pc /dev/sda    # диск целиком, не раздел
grub-mkconfig -o /boot/grub/grub.cfg
```

В выводе `grub-mkconfig` должна появиться строка `Found Windows ...`.

### 7.2 UEFI + GRUB

В `/etc/default/grub` задайте `GRUB_DISABLE_OS_PROBER=false`, затем:

```bash
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=arch
grub-mkconfig -o /boot/grub/grub.cfg
```

Если Windows в выводе не найдена (внутри chroot `os-prober` иногда не работает), перезагрузитесь в Arch и выполните `sudo grub-mkconfig -o /boot/grub/grub.cfg` ещё раз.

> GRUB с Secure Boot здесь не рассматривается: ему нужен shim или отдельная сборка с подписью, что заметно сложнее. Для Secure Boot используйте systemd-boot (7.3).

### 7.3 UEFI + systemd-boot (в том числе с Secure Boot)

Установка загрузчика:

```bash
# сценарий B: ESP от 512 МиБ, смонтирован в /boot
bootctl install

# сценарий C: ESP меньше 512 МиБ, отдельный XBOOTLDR (ESP в /efi, /boot на XBOOTLDR)
bootctl --esp-path=/efi --boot-path=/boot install
```

Узнайте UUID корня:

```bash
blkid -s UUID -o value /dev/nvme0n1p6   # раздел корня (в chroot переменная ROOT не сохраняется)
```

Файл `loader.conf` лежит на ESP: `/boot/loader/loader.conf` (сценарий B) или `/efi/loader/loader.conf` (сценарий C):

```
default arch.conf
timeout 3
console-mode max
editor no
```

Опция `editor no` важна: иначе в меню загрузчика можно изменить параметры ядра и обойти защиту.

Запись загрузчика `/boot/loader/entries/arch.conf` (в сценариях B и C; замените `amd-ucode` на `intel-ucode` при необходимости):

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

Включите обновление загрузчика вместе с системой:

```bash
systemctl enable systemd-boot-update.service
```

Windows появится в меню автоматически (запись `auto-windows`), если её загрузчик лежит на том же ESP. Проверка после первой загрузки: `bootctl list`. Если Windows установлена на другом диске и использует свой ESP, автоопределения не будет: выбирайте систему через boot-меню прошивки (`F12`) или скопируйте каталог `EFI/Microsoft` со старого ESP на ESP Arch (после обновлений загрузчика Windows копию придётся обновить вручную).

Для сценария с Secure Boot Secure Boot пока остаётся выключенным (Setup Mode), ключи добавляются после первой загрузки (раздел 9).

## 8 Завершение установки и первая загрузка

Выйдите из chroot, отмонтируйте разделы и перезагрузитесь (извлеките установочный носитель):

```bash
exit
umount -R /mnt
reboot
```

В меню загрузчика должны быть Arch и Windows. Войдите в Arch под созданным пользователем и включите сеть и синхронизацию времени:

```bash
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now systemd-timesyncd
nmcli device wifi list                         # только для Wi-Fi
nmcli device wifi connect "Имя_сети" --ask     # либо интерактивно: nmtui
```

Если вы выбрали сценарий без Secure Boot, перейдите к разделу 10. Для Secure Boot сначала выполните раздел 9.

## 9 Secure Boot: ключи и подпись

Нужно только для сценария «UEFI + Secure Boot», после первой загрузки в установленную систему. Прошивка должна быть в Setup Mode.

**9.1 Ключи.** Флаг `-m` добавляет ключи Microsoft. Для dual-boot он **обязателен**: загрузчик Windows подписан Microsoft, и без этих ключей она не загрузится при включённом Secure Boot.

```bash
sudo sbctl status                 # Setup Mode: Enabled
sudo sbctl create-keys
sudo sbctl enroll-keys -m
```

**9.2 Подпись.** Пути зависят от точки монтирования ESP. Сценарий B (ESP в `/boot`):

```bash
sudo sbctl sign -s /boot/EFI/systemd/systemd-bootx64.efi
sudo sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
sudo sbctl sign -s /boot/vmlinuz-linux
sudo sbctl verify                 # всё своё должно быть подписано
```

Сценарий C (ESP в `/efi`, ядро на XBOOTLDR в `/boot`):

```bash
sudo sbctl sign -s /efi/EFI/systemd/systemd-bootx64.efi
sudo sbctl sign -s /efi/EFI/BOOT/BOOTX64.EFI
sudo sbctl sign -s /boot/vmlinuz-linux
sudo sbctl verify
```

Файлы в `EFI/Microsoft/...` подписаны Microsoft, их через `sbctl` подписывать не нужно, даже если `sbctl verify` покажет их как неподписанные.

Флаг `-s` сохраняет файл в базу sbctl, и pacman-хук пакета `sbctl` автоматически переподписывает его после обновлений ядра и загрузчика. Периодически проверяйте `sudo sbctl verify`.

**9.3 Включите Secure Boot** в прошивке и перезагрузитесь. Проверка в Arch:

```bash
sudo sbctl status                 # Secure Boot: Enabled
bootctl status
```

Затем загрузитесь в Windows. Если она запросит ключ BitLocker, введите его. После этого верните защиту (`manage-bde -protectors -enable C:`) и проверьте в `msinfo32`, что «Состояние безопасной загрузки» — «Вкл.».

> Модули NVIDIA (`nvidia-open-dkms`) подписывать не нужно: на Arch по умолчанию ядро не требует подписи модулей. Если позже установите другое ядро (например, CachyOS), его тоже нужно подписать: `sudo sbctl sign -s /boot/vmlinuz-<имя ядра>`.

> Некоторые игры с античитом (например, Valorant с Vanguard) требуют включённого Secure Boot. Это одна из причин использовать именно этот сценарий.

## 10 Синхронизация времени с Windows

По умолчанию Linux хранит в аппаратных часах (RTC) время в UTC, а Windows — местное. Каждая ОС при загрузке читает RTC по-своему, поэтому время «слетает» на величину часового пояса. Для Ульяновска (UTC+4): после работы в Linux Windows показывает время на 4 часа меньше, а после работы в Windows Linux спешит на 4 часа, пока не исправит время по сети.

Linux уже хранит UTC (`hwclock --systohc` в шаге 6), `systemd-timesyncd` синхронизирует системные часы по сети (шаг 8). Осталось сделать так, чтобы обе системы одинаково трактовали RTC.

### Вариант 1 (рекомендуется): Windows хранит UTC

1. В Arch убедитесь, что время верное, и запишите его в RTC:

```bash
timedatectl                       # System clock synchronized: yes, NTP service: active, RTC in local TZ: no
sudo timedatectl set-ntp true
sudo hwclock --systohc
```

2. В Windows в консоли от администратора:

```
reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /d 1 /t REG_DWORD /f
```

3. Перезагрузите Windows. Часовой пояс в ней оставьте местным («(UTC+04:00) Ульяновск»). Сразу после изменения Windows покажет неверное время: откройте «Параметры → Время и язык → Дата и время» и нажмите «Синхронизировать» (включите «Установить время автоматически»).

4. Проверьте: поочерёдно загрузитесь в Linux и Windows несколько раз, включая холодный старт. Время должно совпадать. В Linux:

```bash
timedatectl
cat /etc/adjtime                  # последняя строка: UTC
```

Откат в Windows: `reg delete "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /f`. Если время снова начало «уезжать» (например, после крупного обновления Windows), проверьте значение: `reg query "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal`. Тип должен быть `REG_DWORD`, значение `0x1`.

### Вариант 2: Linux хранит местное время

Подходит, если не хотите менять реестр Windows:

```bash
sudo timedatectl set-local-rtc 1 --adjust-system-clock
```

`timedatectl` предупредит, что режим не рекомендуется: пока обе ОС выключены, Linux не может учесть переход на летнее/зимнее время. Для часовых поясов без перехода на сезонное время, как у Ульяновска, это почти незаметно. Вернуть UTC в RTC: `sudo timedatectl set-local-rtc 0 --adjust-system-clock` (тогда Windows снова нужно настроить по варианту 1).

## 11 Порядок загрузки и выбор системы

Перезагрузка в Windows из Linux без ожидания меню (systemd-boot):

```bash
systemctl reboot --boot-loader-entry=auto-windows
systemctl reboot --firmware-setup     # в настройки прошивки
```

Если после обновления Windows перестала показываться Arch и сразу грузится Windows, прошивка сменила порядок загрузки. Загрузитесь в Arch через boot-меню прошивки и поправьте порядок:

```bash
sudo efibootmgr                       # найдите номера записей: «Linux Boot Manager» (systemd-boot) или «arch» (GRUB)
sudo efibootmgr -o 0001,0000          # подставьте свои номера, Arch первой
```

Если запись Arch исчезла из прошивки совсем (сброс NVRAM), загрузитесь с live-образа, смонтируйте разделы по схеме из шага 4, выполните `arch-chroot -S /mnt` и повторите установку загрузчика (шаг 7).

Доступ к разделам Windows из Linux (при отключённом быстром запуске):

```bash
lsblk -f                              # найти NTFS-раздел
sudo mkdir -p /mnt/win
sudo mount -t ntfs3 /dev/nvme0n1p3 /mnt/win
```

Если Linux пишет, что том находится в состоянии гибернации, загрузитесь в Windows, полностью завершите работу и повторите (см. шаг 1.2). Не монтируйте такой том на запись принудительно.

## 12 Если что-то не работает

| Симптом                                           | Причина и решение                                                                                                                       |
| ------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Windows нет в меню GRUB                           | Проверьте `GRUB_DISABLE_OS_PROBER=false` и наличие `os-prober`. Выполните `grub-mkconfig` после первой загрузки в установленную систему |
| Windows нет в меню systemd-boot                   | Windows на другом ESP: скопируйте `EFI/Microsoft` или выбирайте через boot-меню прошивки. Проверьте `bootctl list`                      |
| Сразу грузится Windows                            | Порядок загрузки сменила прошивка или обновление Windows: `efibootmgr -o`                                                               |
| Live-образ не загружается                         | Включён Secure Boot: отключите его или переведите прошивку в Setup Mode на время установки                                              |
| Windows не загружается при включённом Secure Boot | Ключи Microsoft не добавлены. Снова переведите прошивку в Setup Mode, очистите ключи и выполните `sbctl enroll-keys -m`                 |
| Windows просит ключ BitLocker                     | Введите ключ восстановления. Перед изменением прошивки приостанавливайте защиту: `manage-bde -protectors -disable C: -RebootCount 0`   |
| Linux не монтирует NTFS (гибернация, read-only)   | Отключите быстрый запуск и гибернацию (`powercfg /h off`), полностью завершите работу Windows                                           |
| Время в ОС отличается на несколько часов          | См. раздел 10                                                                                                                           |

Проблемы, связанные с самим Mandara (например, не работают встроенные скриншоты), описаны в отдельном файле: [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## 13 Установка оболочки

Когда Arch загружается рядом с Windows, время настроено и обе системы работают, установите mandara скриптом из репозитория. Скрипт ставит mandara shell с compositor `mango`, приложения, инструменты разработки, видеодрайверы, игровые пакеты и виртуализацию. Он рассчитан на уже установленный Arch с пользователем, `sudo` и работающей сетью. Разметка и загрузчик в его задачи не входят: они настроены выше.

```bash
sudo pacman -S --needed git
git clone https://github.com/skadi-project/arch-install.git
cd arch-install
chmod +x install_mandara.sh
./install_mandara.sh
```

Запускайте скрипт от обычного пользователя, не от root (`sudo` он вызовет сам). Перед установкой он предложит выбрать файловый менеджер, терминал, оболочку, браузер и редакторы. Для запуска без вопросов задайте переменные `FILE_MANAGER`, `TERMINAL`, `USER_SHELL`, `BROWSER`, `TEXT_EDITORS`; выбор видеодрайвера задаётся переменной `GPU_MODE` (`auto`, `ask`, `amd`, `intel`, `nvidia`, `all`, `skip`). После завершения перезагрузитесь: применятся группы `docker`/`libvirt`/`kvm` и настройки видеодрайвера. Подробности о скрипте и ручной установке смотрите в основном README.

Если после установки что-то работает не так (например, не делаются скриншоты), загляните в [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Документация

- [Arch Wiki: Dual boot with Windows](https://wiki.archlinux.org/title/Dual_boot_with_Windows)
- [Arch Wiki: systemd-boot](https://wiki.archlinux.org/title/Systemd-boot)
- [Arch Wiki: EFI system partition](https://wiki.archlinux.org/title/EFI_system_partition)
- [Arch Wiki: GRUB, поиск других ОС](https://wiki.archlinux.org/title/GRUB#Detecting_other_operating_systems)
- [Arch Wiki: Secure Boot](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot)
- [Arch Wiki: System time](https://wiki.archlinux.org/title/System_time)
- [sbctl](https://github.com/Foxboron/sbctl)
