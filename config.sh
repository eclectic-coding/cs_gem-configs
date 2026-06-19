#!/usr/bin/env bash

CONFIG_FILE="$HOME/.gem_setuprc"

expand_tilde() {
  case "$1" in
    "~/"*) echo "$HOME/${1#"~/"}" ;;
    "~")   echo "$HOME" ;;
    *)     echo "$1" ;;
  esac
}

load_config() {
  if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
  fi
}

prompt_value() {
  local prompt="$1" current="$2"
  if [ -n "$current" ]; then
    read -rp "$prompt [$current]: " value
    value="${value:-$current}"
  else
    read -rp "$prompt: " value
  fi
  echo "$value"
}

save_config() {
  BASE_DIR="$(expand_tilde "$BASE_DIR")"
  cat > "$CONFIG_FILE" << EOF
BASE_DIR="$BASE_DIR"
GITHUB_USERNAME="$GITHUB_USERNAME"
EOF
}

run_config_prompt() {
  BASE_DIR="$(prompt_value "Base directory for gems" "$BASE_DIR")"
  GITHUB_USERNAME="$(prompt_value "GitHub username" "$GITHUB_USERNAME")"
  save_config
  echo "Config saved to $CONFIG_FILE"
}

show_config() {
  echo "Current config ($CONFIG_FILE):"
  echo "  Base directory:    $BASE_DIR"
  echo "  GitHub username:   $GITHUB_USERNAME"
}

ensure_config() {
  load_config

  if [ -z "$BASE_DIR" ] || [ -z "$GITHUB_USERNAME" ]; then
    echo "First-time setup — configuring defaults."
    echo ""
    run_config_prompt
    return
  fi

  show_config
  echo ""
  read -rp "Update config? [y/N]: " answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    run_config_prompt
  fi
}