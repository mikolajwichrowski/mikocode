#!/usr/bin/env bash
# Shared UI helpers for the MikoCode installer.
# Sourced by install.sh. Requires TOTAL_STEPS to be set by the caller.

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
  BOLD="$(tput bold)"
  DIM="$(tput dim)"
  RED="$(tput setaf 1)"
  GREEN="$(tput setaf 2)"
  BLUE="$(tput setaf 4)"
  RESET="$(tput sgr0)"
else
  BOLD=""
  DIM=""
  RED=""
  GREEN=""
  BLUE=""
  RESET=""
fi

CURRENT_STEP=0
HAVE_GUM=0

ui_detect_gum() {
  if command -v gum >/dev/null 2>&1 && [[ -t 0 ]] && [[ -t 1 ]]; then
    HAVE_GUM=1
  else
    HAVE_GUM=0
  fi
}
ui_detect_gum

title() {
  if [[ "$HAVE_GUM" == "1" ]]; then
    gum style --bold --foreground 212 "$1"
  else
    printf "%s%s%s\n" "$BOLD" "$1" "$RESET"
  fi
}

subtitle() {
  if [[ "$HAVE_GUM" == "1" ]]; then
    gum style --faint "$1"
  else
    printf "%s%s%s\n" "$DIM" "$1" "$RESET"
  fi
}

step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  if [[ "$HAVE_GUM" == "1" ]]; then
    gum style --foreground 39 --bold "[$CURRENT_STEP/$TOTAL_STEPS] $1"
  else
    printf "\n%s[%d/%d]%s %s\n" "${BLUE}${BOLD}" "$CURRENT_STEP" "$TOTAL_STEPS" "$RESET" "$1"
  fi
}

ok() {
  printf "%s  -> %s%s\n" "$GREEN" "$1" "$RESET"
}

warn() {
  printf "%s  -> %s%s\n" "$RED" "$1" "$RESET"
}

run_with_spinner() {
  local label="$1"
  shift

  if [[ "$HAVE_GUM" == "1" ]]; then
    gum spin --spinner dot --title "$label" -- "$@"
  else
    "$@"
  fi
}

confirm_continue() {
  local prompt="$1"

  if [[ "${ASSUME_YES:-0}" == "1" ]]; then
    return 0
  fi

  if [[ "$HAVE_GUM" == "1" ]]; then
    gum confirm "$prompt"
    return
  fi

  if [[ -t 0 ]]; then
    printf "%s [Y/n] " "$prompt"
    read -r answer
    [[ -z "${answer:-}" || "$answer" =~ ^[Yy]$ ]]
    return
  fi

  return 0
}