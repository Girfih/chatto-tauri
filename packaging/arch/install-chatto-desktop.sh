#!/usr/bin/env bash
set -Eeuo pipefail

readonly APP_NAME='Chatto Desktop'
readonly PACKAGE_NAME='chatto-desktop'
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PACKAGE_GLOB="${PACKAGE_NAME}-*.pkg.tar.*"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  readonly C_RESET=$'\033[0m'
  readonly C_BOLD=$'\033[1m'
  readonly C_DIM=$'\033[2m'
  readonly C_GREEN=$'\033[32m'
  readonly C_CYAN=$'\033[36m'
  readonly C_YELLOW=$'\033[33m'
  readonly C_RED=$'\033[31m'
else
  readonly C_RESET='' C_BOLD='' C_DIM='' C_GREEN='' C_CYAN='' C_YELLOW='' C_RED=''
fi

usage() {
  cat <<'EOF'
Установка Chatto Desktop на Arch Linux.

Использование:
  ./install-chatto-desktop.sh
  ./install-chatto-desktop.sh /path/to/chatto-desktop-0.7.0-1-x86_64.pkg.tar.zst
  ./install-chatto-desktop.sh --check
  ./install-chatto-desktop.sh --locate-only
EOF
}

fail() {
  printf '%sОшибка:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2
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
  package="$(find "$SCRIPT_DIR" -type f -name "$PACKAGE_GLOB" ! -name '*-debug-*' -printf '%T@\t%p\n' 2>/dev/null | sort -t $'\t' -k1,1nr | head -n1 | cut -f2- || true)"
  [[ -n "$package" ]] || fail "рядом со скриптом не найден пакет $PACKAGE_GLOB"
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
    --locate-only)
      find_package
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

  info "${C_CYAN}${C_BOLD}Chatto Desktop${C_RESET}"
  info "${C_DIM}Arch Linux • x86_64 • установка пакета${C_RESET}"
  info ""
  info "${C_BOLD}Пакет:${C_RESET} $package"
  info "${C_BOLD}Установка:${C_RESET} $APP_NAME"
  sudo pacman -U --needed --noconfirm -- "$package"

  # pacman normally runs this hook itself; this also covers custom Arch setups.
  if command -v update-ca-trust >/dev/null 2>&1; then
    sudo update-ca-trust
  fi

  verify_installation
  info ""
  info "${C_GREEN}${C_BOLD}Готово.${C_RESET} Запуск: ${C_BOLD}chatto-desktop${C_RESET}"
  info "${C_DIM}Приложение также доступно в меню рабочего стола.${C_RESET}"
}

main "$@"
