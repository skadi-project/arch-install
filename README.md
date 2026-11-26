# Arch Linux + [Caelestia|Mandara]

Набор установочных скриптов для Arch Linux. Проект подготавливает рабочую систему с Wayland-окружением, видеодрайверами, инструментами разработки, играми и виртуализацией.

## Варианты окружения

### Caelestia + Hyprland

![Caelestia shell](https://github.com/user-attachments/assets/0840f496-575c-4ca6-83a8-87bb01a85c5f)

Caelestia — оболочка на базе Quickshell для Hyprland. Она объединяет панель, лаунчер, виджеты, быстрые настройки, медиауправление и интеграцию с системными сервисами. Установщик также настраивает greetd/ReGreet, шрифты, звук, инструменты разработки, Docker, игровые пакеты и libvirt.

```bash
git clone https://github.com/skadi-project/arch-install.git
cd arch-install
chmod +x install_caelestia.sh
./install_caelestia.sh
```

Подробная инструкция — [README_caelestia.md](README_caelestia.md). Установка рядом с Windows — [README_caelestia_dualboot.md](README_caelestia_dualboot.md).

### Mandara + Mango

![Mandara desktop](https://thehamdiz.github.io/mandara/docs/screenshots/hero.webp)

Mandara — готовая desktop shell с compositor Mango. Она предоставляет панель, часы, список задач, календарь, виджеты, док, launcher и системные панели. Установщик дополнительно ставит приложения, инструменты разработки, видеодрайверы, Docker, игровые пакеты, libvirt и AUR-пакеты.

```bash
git clone https://github.com/skadi-project/arch-install.git
cd arch-install
chmod +x install_mandara.sh
./install_mandara.sh
```

Подробная инструкция — [README_mandara.md](README_mandara.md). Установка рядом с Windows — [README_mandara_dualboot.md](README_mandara_dualboot.md).

## Установка рядом с Windows (dual-boot)

Для компьютеров, где Arch ставится рядом с уже установленной Windows, есть отдельные пошаговые инструкции для каждой оболочки. Они описывают только dual-boot и синхронизацию времени, а затем отправляют на запуск установочного скрипта.

| Оболочка  | Инструкция                                                         |
| --------- | ------------------------------------------------------------------ |
| Caelestia | [README_caelestia_dualboot.md](README_caelestia_dualboot.md)       |
| Mandara   | [README_mandara_dualboot.md](README_mandara_dualboot.md)           |

Что в них разобрано:

- режимы BIOS (MBR), UEFI и UEFI + Secure Boot, выбор сценария по размеру ESP Windows;
- подготовка Windows: BitLocker, быстрый запуск и гибернация, освобождение места;
- явные команды разметки (`fdisk`), форматирования и монтирования без потери данных Windows;
- загрузчики GRUB и systemd-boot (в том числе с `sbctl` и ключами Microsoft);
- синхронизация времени между Windows и Linux, чтобы часы не «слетали»;
- выбор системы при загрузке, порядок загрузки и типичные неполадки.

Установочные скрипты разметкой и загрузчиком не занимаются: сначала установите Arch по dual-boot инструкции, затем запустите скрипт своей оболочки.

## Выбор видеодрайвера

Оба установщика определяют производителей видеокарт по PCI ID и поддерживают интерактивный выбор.

```bash
# Автоопределение
./install_caelestia.sh

# Явный выбор NVIDIA
GPU_MODE=nvidia ./install_mandara.sh

# Гибридная графика, например Intel + NVIDIA
GPU_MODE=all ./install_caelestia.sh

# Пропустить установку видеодрайверов
GPU_MODE=skip ./install_mandara.sh
```

Поддерживаются режимы `auto`, `ask`, `amd`, `intel`, `nvidia`, `all` и `skip`. Для NVIDIA скрипт выбирает `nvidia-open-dkms` или `nvidia-dkms` по тексту `lspci`. Проверьте совместимость модели и доступность пакета.

## Дополнительные режимы

`--dry-run` не является полностью безопасным предпросмотром: он не выполняет часть вызовов `pacman` и `systemctl`, но всё ещё может запросить `sudo`, изменить `multilib`, запускать `rustup`, `makepkg`, `paru`, `caelestia install` и внешний установщик Mandara. Не используйте его на системе, которую нельзя изменять.

```bash
# Показать справку
./install_caelestia.sh --help
```

Установщики запускаются от обычного пользователя с правами `sudo`. Подробный журнал сохраняется в `~/arch-install-<дата-время>.log`.

## Состав проекта

- [install_caelestia.sh](install_caelestia.sh) — установка Caelestia и Hyprland.
- [install_mandara.sh](install_mandara.sh) — установка Mandara и Mango.
- [README_caelestia.md](README_caelestia.md) — подробная инструкция для Caelestia.
- [README_mandara.md](README_mandara.md) — подробная инструкция для Mandara.
- [README_caelestia_dualboot.md](README_caelestia_dualboot.md) — установка Arch рядом с Windows и синхронизация времени (Caelestia).
- [README_mandara_dualboot.md](README_mandara_dualboot.md) — установка Arch рядом с Windows и синхронизация времени (Mandara).
- [caelestia/](caelestia/) — локальные конфигурационные файлы Caelestia (`hypr-vars.lua`, `hypr-user.lua`); копируются в `~/.config/caelestia/` (подробности в [README_caelestia.md](README_caelestia.md)).
- [mandara/](mandara/) — конфигурационные файлы Mandara; `mandara/foot/foot.ini` копируется в `~/.config/foot/foot.ini` (существующий файл сохраняется в резервную копию, подробности в [README_mandara.md](README_mandara.md)).

## Общие возможности

- автоматическое включение `multilib`;
- выбор драйверов AMD, Intel и NVIDIA;
- поддержка гибридной графики;
- Hyprland, Wayland и системные компоненты;
- greetd/ReGreet в варианте Caelestia;
- инструменты C++, Rust и Web-разработки;
- Docker в обоих вариантах;
- Steam, Wine, Lutris, Gamescope и MangoHud;
- QEMU/KVM, libvirt и virt-manager;
- AUR-пакеты через `paru`;
- инструкции по установке рядом с Windows (BIOS, UEFI, Secure Boot);
- ZeroTier, синхронизация времени (`systemd-timesyncd`) и периодический TRIM.

## Ссылки

- [Caelestia shell](https://github.com/caelestia-dots/shell)
- [Mandara](https://github.com/theHamdiz/mandara)
- [Hyprland](https://github.com/hyprwm/Hyprland)
- [Arch Linux Installation Guide](https://wiki.archlinux.org/title/Installation_guide)
- [Arch Wiki: Dual boot with Windows](https://wiki.archlinux.org/title/Dual_boot_with_Windows)
