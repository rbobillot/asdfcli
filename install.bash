#!/bin/bash

# --- Strict Mode ---
set -euo pipefail
IFS=$'\n\t'

# --- Configuration ---
REPO_OWNER="rbobillot"
REPO_NAME="asdfcli"
BRANCH="main"
SCRIPT_NAME="asdfcli.bash"
GITHUB_RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/refs/heads/${BRANCH}/${SCRIPT_NAME}"
INSTALL_DIR="${HOME}"
INSTALL_PATH="${INSTALL_DIR}/.${SCRIPT_NAME}"
RC_FILE_COMMENT_START="# asdfcli-start"
RC_FILE_COMMENT_END="# asdfcli-end"
RC_FILE_ENTRY="
${RC_FILE_COMMENT_START}
[[ -f ${INSTALL_PATH} ]] && source ${INSTALL_PATH}
${RC_FILE_COMMENT_END}
"

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

find_rc_file() {
  local shell_name=$(basename "$SHELL")
  local rc_file=""

  case "$shell_name" in
  "bash")
    if [[ -f "${HOME}/.bashrc" ]]; then
      rc_file="${HOME}/.bashrc"
    elif [[ -f "${HOME}/.bash_profile" ]]; then
      rc_file="${HOME}/.bash_profile"
    fi
    ;;
  "zsh")
    if [[ -f "${HOME}/.zshrc" ]]; then
      rc_file="${HOME}/.zshrc"
    fi
    ;;
  # Add more shells if needed, e.g., fish, ksh
  *)
    log_warn "Unsupported shell: $shell_name. Attempting to use .bashrc or .profile."
    if [[ -f "${HOME}/.bashrc" ]]; then
      rc_file="${HOME}/.bashrc"
    elif [[ -f "${HOME}/.profile" ]]; then
      rc_file="${HOME}/.profile"
    fi
    ;;
  esac

  if [[ -z "$rc_file" ]]; then
    log_error "Could not find a suitable shell RC file in your home directory."
    log_error "Please manually add 'source ${INSTALL_PATH}' to your shell's startup file."
    return 1
  fi
  echo "$rc_file"
  return 0
}

install_asdfcli() {
  log_info "Starting asdfcli installation..."

  local rc_file
  rc_file=$(find_rc_file) || return 1

  log_info "Using RC file: ${rc_file}"

  log_info "Downloading ${SCRIPT_NAME} from ${GITHUB_RAW_URL} to ${INSTALL_PATH}..."
  if curl -sL "${GITHUB_RAW_URL}" -o "${INSTALL_PATH}"; then
    log_info "Download complete."
  else
    log_error "Failed to download ${SCRIPT_NAME}. Please check your internet connection or the URL."
    return 1
  fi

  log_info "Checking if ${rc_file} needs updating..."
  if grep -qF "${RC_FILE_COMMENT_START}" "${rc_file}"; then
    log_warn "asdfcli entry already exists in ${rc_file}. Skipping modification."
  else
    log_info "Adding asdfcli source entry to ${rc_file}..."
    printf "%s\n" "${RC_FILE_ENTRY}" >>"${rc_file}"
    log_info "Entry added. Please restart your shell or run 'source ${rc_file}' to load asdfcli."
  fi

  log_info "${SCRIPT_NAME} installation complete!"
  echo ""
  log_info "To use asdfcli functions, please restart your terminal or run: ${YELLOW}source ${rc_file}${NC}"
  echo ""
  log_info "To uninstall asdfcli, simply run the following command:"
  log_info "${YELLOW}./install_asdfcli.bash --uninstall${NC}"
}

uninstall_asdfcli() {
  log_info "Starting asdfcli uninstallation..."

  local rc_file
  rc_file=$(find_rc_file) || return 1

  log_info "Using RC file: ${rc_file}"

  if grep -qF "${RC_FILE_COMMENT_START}" "${rc_file}"; then
    log_info "Removing asdfcli entry from ${rc_file}..."
    sed -i "/${RC_FILE_COMMENT_START}/,/${RC_FILE_COMMENT_END}/d" "${rc_file}"
    log_info "Entry removed. Please restart your shell to unload asdfcli."
  else
    log_warn "asdfcli entry not found in ${rc_file}. Skipping RC file modification."
  fi

  if [[ -f "${INSTALL_PATH}" ]]; then
    log_info "Removing ${INSTALL_PATH}..."
    rm "${INSTALL_PATH}"
    log_info "File removed."
  else
    log_warn "asdfcli script file not found at ${INSTALL_PATH}. Skipping file removal."
  fi

  log_info "${SCRIPT_NAME} uninstallation complete!"
  echo ""
  log_info "To ensure asdfcli is fully unloaded, please restart your terminal."
}

if [[ "$#" -gt 0 && "$1" == "--uninstall" ]]; then
  uninstall_asdfcli
else
  install_asdfcli
fi
