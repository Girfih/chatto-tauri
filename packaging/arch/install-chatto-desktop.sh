#!/usr/bin/env bash
set -Eeuo pipefail

readonly APP_NAME='Chatto Desktop'
readonly PACKAGE_NAME='chatto-desktop'
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Установка Chatto Desktop на Arch Linux.

Использование:
  ./install-chatto-desktop.sh
  ./install-chatto-desktop.sh /path/to/chatto-desktop-0.7.0-1-x86_64.pkg.tar.zst
  ./install-chatto-desktop.sh --check
EOF
}

fail() {
  printf 'Ошибка: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '%s\n' "$*"
}

find_package() {
  local requested="${1:-}"

  if [[ -n "$requested" ]]; then
    [[ -f "$requested" ]] || fail "файл пакета не найден: $requested"
    printf '%s\n' "$(realpath -- "$requested")"
    return
  fi

  local package
  package="$(
    find "$SCRIPT_DIR" -maxdepth 1 -type f \\
      -name "${PACKAGE_NAME}-*.pkg.tar.*" \\
      ! -name '*-debug-*' \\
      -print -quit
  )"
  [[ -n "$package" ]] || fail "положите пакет ${PACKAGE_NAME}-*.pkg.tar.* рядом со скриптом или передайте его путь"
  printf '%s\n' "$(realpath -- "$package")"
}

check_system() {
  command -v pacman >/dev/null 2>&1 || fail 'pacman не найден: нужен Arch Linux или совместимый дистрибутив'
  command -v realpath >/dev/null 2>&1 || fail 'необходима команда realpath'

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ "${ID:-}" == 'arch' || "${ID_LIKE:-}" == *arch* ]] || \
      fail "обнаружена ОС ${PRETTY_NAME:-unknown}; скрипт рассчитан на Arch Linux"
  fi

  local machine package_arch
  machine="$(uname -m)"
  [[ "$machine" == 'x86_64' ]] || fail "пакет собран для x86_64, текущая архитектура: $machine"

  package_arch="$(pacman-conf Architecture 2>/dev/null || true)"
  [[ -z "$package_arch" || "$package_arch" == 'x86_64' || "$package_arch" == 'auto' ]] || \
    fail "pacman сообщает неподдерживаемую архитектуру: $package_arch"
}

verify_installation() {
  pacman -Q "$PACKAGE_NAME" >/dev/null 2>&1 || fail 'pacman не подтвердил установку пакета'
  command -v chatto-desktop >/dev/null 2>&1 || fail 'файл /usr/bin/chatto-desktop не найден после установки'
  [[ -f /usr/share/applications/chatto.desktop ]] || fail 'desktop-файл не установлен'
  [[ -f /etc/ca-certificates/trust-source/anchors/chatto-root-ca.crt ]] || \
    fail 'CA-сертификат Chatto не установлен'
}

main() {
  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    --check)
      check_system
      info 'Проверка пройдена: Arch Linux x86_64 и pacman доступны.'
      exit 0
      ;;
    --*)
      usage >&2
      exit 2
      ;;
  esac

  check_system
  local package
  package="$(find_package "${1:-}")"

  info "Пакет: $package"
  info "Установка $APP_NAME..."
  sudo pacman -U --needed --noconfirm -- "$package"

  # pacman normally runs this hook itself; this also covers custom Arch setups.
  if command -v update-ca-trust >/dev/null 2>&1; then
    sudo update-ca-trust
  fi

  verify_installation
  info "Готово. Запуск: chatto-desktop"
  info "Приложение также доступно в меню рабочего стола."
}

main "$@"
