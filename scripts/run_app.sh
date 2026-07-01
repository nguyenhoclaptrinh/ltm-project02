#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-menu}"
VENV_DIR="$ROOT_DIR/.venv"
VENV_ACTIVATE="$VENV_DIR/bin/activate"
PYTHON_BIN=""

find_terminal_emulator() {
  local candidate
  for candidate in xterm xfce4-terminal konsole gnome-terminal x-terminal-emulator; do
    if command -v "$candidate" >/dev/null 2>&1; then
      case "$candidate" in
        gnome-terminal|x-terminal-emulator)
          continue
          ;;
        *)
          echo "$candidate"
          return 0
          ;;
      esac
    fi
  done

  for candidate in gnome-terminal x-terminal-emulator; do
    if command -v "$candidate" >/dev/null 2>&1; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

TERMINAL_EMULATOR="$(find_terminal_emulator || true)"

bootstrap_venv() {
  if [[ ! -d "$VENV_DIR" ]]; then
    if ! command -v python3 >/dev/null 2>&1; then
      echo "Khong tim thay python3 de tao virtual environment."
      exit 1
    fi
    echo "[setup] Tao virtual environment tai .venv..."
    python3 -m venv "$VENV_DIR"
  fi

  if [[ ! -f "$VENV_ACTIVATE" ]]; then
    echo "Khong tim thay script activate trong .venv. Hay tao lai virtual environment."
    exit 1
  fi

  # shellcheck disable=SC1090
  source "$VENV_ACTIVATE"
  PYTHON_BIN="$(command -v python)"

  if ! python - <<'CHECK' >/dev/null 2>&1
import cv2
import numpy
CHECK
  then
    echo "[setup] Cai dependency tu requirements.txt..."
    python -m pip install --upgrade pip
    python -m pip install -r "$ROOT_DIR/requirements.txt"
  fi
}

bootstrap_venv

usage() {
  cat <<'USAGE'
run_app.sh

Standard mode from the requirement:
  The script will create `./.venv`, activate it, and install `requirements.txt` automatically if needed.

  ./scripts/run_app.sh server [mjpeg_file]
  ./scripts/run_app.sh client
  ./scripts/run_app.sh open-server [mjpeg_file]
  ./scripts/run_app.sh open-client
  ./scripts/run_app.sh open-demo [mjpeg_file]

Test-only mode:
  ./scripts/run_app.sh test [loss_percent]
  ./scripts/run_app.sh test-client [loss_percent]
  ./scripts/run_app.sh open-test [loss_percent]
  ./scripts/run_app.sh open-test-client [loss_percent]
USAGE
}

require_terminal_emulator() {
  if [[ -z "$TERMINAL_EMULATOR" ]]; then
    echo "Khong tim thay terminal emulator de mo cua so rieng."
    echo "Hay dung mode chay truc tiep trong terminal hien tai."
    exit 1
  fi
}

open_terminal() {
  local label="$1"
  local command="$2"
  require_terminal_emulator

  local shell_cmd="cd '$ROOT_DIR'; echo '[$label]'; $command; echo; echo 'Nhan Enter de dong cua so...'; read"

  case "$(basename "$TERMINAL_EMULATOR")" in
    gnome-terminal)
      nohup "$TERMINAL_EMULATOR" -- bash -lc "$shell_cmd" >/dev/null 2>&1 &
      ;;
    xfce4-terminal)
      nohup "$TERMINAL_EMULATOR" --hold -e bash -lc "$shell_cmd" >/dev/null 2>&1 &
      ;;
    konsole)
      nohup "$TERMINAL_EMULATOR" --noclose -e bash -lc "$shell_cmd" >/dev/null 2>&1 &
      ;;
    xterm|x-terminal-emulator)
      nohup "$TERMINAL_EMULATOR" -e bash -lc "$shell_cmd" >/dev/null 2>&1 &
      ;;
    *)
      nohup "$TERMINAL_EMULATOR" -e bash -lc "$shell_cmd" >/dev/null 2>&1 &
      ;;
  esac
}

run_server() {
  local video_file="${1:-movie.Mjpeg}"
  exec "$PYTHON_BIN" "$ROOT_DIR/Server.py" "$ROOT_DIR/$video_file"
}

run_client() {
  exec "$PYTHON_BIN" "$ROOT_DIR/Client.py"
}

run_test() {
  if [[ $# -ge 1 && -n "${1:-}" ]]; then
    exec "$PYTHON_BIN" "$ROOT_DIR/test_multicast.py" "$1"
  else
    exec "$PYTHON_BIN" "$ROOT_DIR/test_multicast.py"
  fi
}

run_test_client() {
  local loss_percent="${1:-10}"
  exec "$PYTHON_BIN" "$ROOT_DIR/Client.py" "$loss_percent"
}

open_server() {
  local video_file="${1:-movie.Mjpeg}"
  open_terminal "SERVER" "source '$VENV_ACTIVATE' >/dev/null 2>&1; exec python '$ROOT_DIR/Server.py' '$ROOT_DIR/$video_file'"
}

open_client() {
  open_terminal "CLIENT" "source '$VENV_ACTIVATE' >/dev/null 2>&1; exec python '$ROOT_DIR/Client.py'"
}

open_test() {
  if [[ $# -ge 1 && -n "${1:-}" ]]; then
    open_terminal "TEST" "source '$VENV_ACTIVATE' >/dev/null 2>&1; exec python '$ROOT_DIR/test_multicast.py' '$1'"
  else
    open_terminal "TEST" "source '$VENV_ACTIVATE' >/dev/null 2>&1; exec python '$ROOT_DIR/test_multicast.py'"
  fi
}

open_test_client() {
  local loss_percent="${1:-10}"
  open_terminal "TEST CLIENT" "source '$VENV_ACTIVATE' >/dev/null 2>&1; exec python '$ROOT_DIR/Client.py' '$loss_percent'"
}

open_demo() {
  local video_file="${1:-movie.Mjpeg}"
  open_server "$video_file"
  sleep 1
  open_client
}

prompt_video_file() {
  local default_value="movie.Mjpeg"
  local input
  read -r -p "Nhap ten file MJPEG [${default_value}]: " input
  if [[ -z "$input" ]]; then
    echo "$default_value"
  else
    echo "$input"
  fi
}

prompt_loss_percent() {
  local default_value="10"
  local input
  read -r -p "Nhap loss percent cho test [${default_value}]: " input
  if [[ -z "$input" ]]; then
    echo "$default_value"
  else
    echo "$input"
  fi
}

show_menu() {
  while true; do
    cat <<MENU
================ Run App Menu ================
Dang dung terminal mo cua so rieng: ${TERMINAL_EMULATOR:-khong co}

Mode chuan theo de bai:
1. Mo terminal rieng chay Server
2. Mo terminal rieng chay Client
3. Mo 2 terminal: Server + Client
4. Chay Server trong terminal hien tai
5. Chay Client trong terminal hien tai

Mode test bo sung:
6. Mo terminal rieng chay Test receiver
7. Mo terminal rieng chay Test client co loss simulation
8. Chay Test receiver trong terminal hien tai
9. Chay Test client co loss simulation trong terminal hien tai

10. Xem huong dan su dung
0. Thoat
==============================================
MENU

    read -r -p "Chon option: " choice
    case "$choice" in
      1)
        video_file="$(prompt_video_file)"
        open_server "$video_file"
        ;;
      2)
        open_client
        ;;
      3)
        video_file="$(prompt_video_file)"
        open_demo "$video_file"
        ;;
      4)
        video_file="$(prompt_video_file)"
        run_server "$video_file"
        ;;
      5)
        run_client
        ;;
      6)
        open_test
        ;;
      7)
        loss_percent="$(prompt_loss_percent)"
        open_test_client "$loss_percent"
        ;;
      8)
        run_test
        ;;
      9)
        loss_percent="$(prompt_loss_percent)"
        run_test_client "$loss_percent"
        ;;
      10)
        usage
        ;;
      0)
        exit 0
        ;;
      *)
        echo "Option khong hop le. Hay chon lai."
        ;;
    esac
    echo
  done
}

case "$MODE" in
  menu)
    show_menu
    ;;
  server)
    run_server "${2:-movie.Mjpeg}"
    ;;
  client)
    run_client
    ;;
  test)
    run_test "${2:-}"
    ;;
  test-client)
    run_test_client "${2:-10}"
    ;;
  open-server)
    open_server "${2:-movie.Mjpeg}"
    ;;
  open-client)
    open_client
    ;;
  open-test)
    open_test "${2:-}"
    ;;
  open-test-client)
    open_test_client "${2:-10}"
    ;;
  open-demo)
    open_demo "${2:-movie.Mjpeg}"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
