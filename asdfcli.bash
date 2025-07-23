#!/bin/bash

# --- Logging Setup ---
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;33m'
CYAN='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# --- Helper Functions ---

_asdfcli_usage() {
  echo -e "${YELLOW}asdfcli${NC} - A friendly command-line wrapper for asdf-vm"
  echo
  echo -e "${YELLOW}USAGE:${NC}"
  echo -e "  ${GREEN}asdfcli${NC} [command] [plugin_name]"
  echo
  echo -e "${YELLOW}COMMANDS:${NC}"
  echo -e "  ${GREEN}<plugin_name>${NC}                # Interactively install a version of a plugin."
  echo -e "  ${GREEN}l, latest${NC} [plugin_name]      # Add a new plugin and install its 'latest' version."
  echo -e "  ${GREEN}u, update${NC} [plugin_name]      # Update an existing plugin to its 'latest' version."
  echo -e "  ${GREEN}r, remove${NC} [plugin_name]      # Remove a plugin and all its installed versions."
  echo -e "  ${GREEN}h, help, -h, --help${NC}          # Display this help menu."
  echo
  echo -e "${YELLOW}NOTES:${NC}"
  echo -e "  • If no [plugin_name] is provided for a command, an interactive selector will appear."
  echo -e "  • Running '${GREEN}asdfcli${NC}' with no command starts the interactive installation."
  echo
  echo -e "${YELLOW}EXAMPLES:${NC}"
  echo -e "  ${GREEN}asdfcli${NC}                      # Interactively find and install a new plugin"
  echo -e "  ${GREEN}asdfcli ${MAGENTA}nodejs${NC}               # Interactively choose a version of nodejs to install"
  echo -e "  ${GREEN}asdfcli ${CYAN}latest ${MAGENTA}python${NC}        # Install the latest version of python"
  echo -e "  ${GREEN}asdfcli ${CYAN}update ${MAGENTA}nodejs${NC}        # Update your installed nodejs to the latest version"
}

_semver_ge() {
  local v1_parts v2_parts
  IFS='.' read -ra v1_parts <<<"$1"
  IFS='.' read -ra v2_parts <<<"$2"

  local i max_len="${#v1_parts[@]}"
  ((${#v2_parts[@]} > max_len)) && max_len="${#v2_parts[@]}"

  for ((i = 0; i < max_len; i++)); do
    local v1_segment_dec v2_segment_dec
    printf -v v1_segment_dec "%d" "${v1_parts[i]:-0}"
    printf -v v2_segment_dec "%d" "${v2_parts[i]:-0}"

    if ((v1_segment_dec > v2_segment_dec)); then
      return 0
    elif ((v1_segment_dec < v2_segment_dec)); then
      return 1
    fi
  done
  return 0
}

# Returns 1 if VERSION < 0.16.0
_asdfcli_check_asdf_version() {
  local asdf_version_output parsed_version
  local required_version="0.16.0"

  asdf_version_output=$(asdf --version 2>&1 || true)

  if [[ "$asdf_version_output" =~ ^v([0-9]+\.[0-9]+\.[0-9]+.*)$ ]]; then
    parsed_version="${BASH_REMATCH[1]%%-*}"
  elif [[ "$asdf_version_output" =~ ^asdf\ version\ v?([0-9]+\.[0-9]+\.[0-9]+.*)$ ]]; then
    parsed_version="${BASH_REMATCH[1]%%-*}"
  else
    log_error "Could not parse asdf version from output: '$asdf_version_output'"
    return 1
  fi

  if [[ -z "$parsed_version" ]]; then
    log_error "Parsed an empty asdf version string."
    return 1
  fi

  _semver_ge "$parsed_version" "$required_version"
}

_asdfcli_select_plugin() {
  asdf plugin list all | sed '1!G;h;$!d' | fzf | awk '{print $1}'
}

# --- Core Logic Functions ---

_asdfcli_install_plugin() {
  local ASDF_PLUGIN=$1
  local SHIM_VERSION=$2
  local SET_GLOBAL="set"

  _asdfcli_check_asdf_version || SET_GLOBAL="global"

  if asdf install "$ASDF_PLUGIN" "$SHIM_VERSION" && asdf "$SET_GLOBAL" "$ASDF_PLUGIN" "$SHIM_VERSION"; then
    log_info "Successfully installed and set '${YELLOW}$ASDF_PLUGIN $SHIM_VERSION${NC}'."
    return 0
  else
    log_error "Failed to install '${YELLOW}$ASDF_PLUGIN $SHIM_VERSION${NC}'."
    return 1
  fi
}

_asdfcli_remove_plugin() {
  local ASDF_PLUGIN="$1"

  if [[ -z "$ASDF_PLUGIN" ]]; then
    log_info "No plugin specified. Please select one to remove:"
    ASDF_PLUGIN=$(asdf plugin list | sed '1!G;h;$!d' | fzf --exit-0)
    if [[ -z "$ASDF_PLUGIN" ]]; then
      log_warn "No plugin selected. Aborting removal."
      return 1
    fi
  fi

  log_info "Removing '${YELLOW}$ASDF_PLUGIN${NC}' plugin..."
  if asdf plugin remove "$ASDF_PLUGIN"; then
    log_info "Plugin '${YELLOW}$ASDF_PLUGIN${NC}' removed successfully."
    return 0
  else
    log_error "Failed to remove '${YELLOW}$ASDF_PLUGIN${NC}' plugin."
    return 1
  fi
}

_asdfcli_update_plugin() {
  local ASDF_PLUGIN="$1"

  if [[ -z "$ASDF_PLUGIN" ]]; then
    log_info "Please select a plugin to update:"
    ASDF_PLUGIN=$(asdf plugin list | sed '1!G;h;$!d' | fzf --exit-0)
  fi

  if [[ -z "$ASDF_PLUGIN" ]]; then
    log_warn "No plugin selected. Aborting update."
    return 1
  fi

  log_info "Attempting to update '${YELLOW}$ASDF_PLUGIN${NC}' to latest version..."
  if _asdfcli_install_plugin "$ASDF_PLUGIN" "latest"; then
    log_info "Successfully updated '${YELLOW}$ASDF_PLUGIN${NC}'."
    return 0
  else
    log_error "Failed to update '${YELLOW}$ASDF_PLUGIN${NC}'."
    return 1
  fi
}

_asdfcli_add_and_install_plugin() {
  local ASDF_PLUGIN=$1
  local SHIM_VERSION=$2

  [[ -z $ASDF_PLUGIN ]] && ASDF_PLUGIN=$(_asdfcli_select_plugin)
  [[ -z $ASDF_PLUGIN ]] && {
    log_warn "No plugin selected. Aborting."
    return 1
  }

  log_info "Adding '${YELLOW}$ASDF_PLUGIN${NC}' plugin repository..."

  if asdf plugin add "$ASDF_PLUGIN"; then
    log_info "Plugin repo added. Now installing..."
  else
    log_error "Failed to add plugin repository for '${YELLOW}$ASDF_PLUGIN${NC}'."
    return 1
  fi

  if [[ -z "$SHIM_VERSION" ]]; then
    log_info "Please select a version of '${YELLOW}$ASDF_PLUGIN${NC}' to install:"
    SHIM_VERSION=$(asdf list all "$ASDF_PLUGIN" | sed '1!G;h;$!d' | fzf --exit-0)
  fi

  if [[ -n "$SHIM_VERSION" ]]; then
    _asdfcli_install_plugin "$ASDF_PLUGIN" "$SHIM_VERSION"
  else
    log_warn "No version selected for '${YELLOW}$ASDF_PLUGIN${NC}'. Cleaning up added plugin."
    # Auto-remove the plugin if no version was installed
    _asdfcli_remove_plugin "$ASDF_PLUGIN" >/dev/null
  fi
}

_check_dependencies() {
  local -a MISSING_BINS=()
  for bin in "asdf" "fzf" "sed" "awk"; do
    if ! command -v "$bin" &>/dev/null; then
      MISSING_BINS+=("$bin")
    fi
  done

  if ((${#MISSING_BINS[@]} > 0)); then
    log_error "Missing required command(s): ${YELLOW}${MISSING_BINS[*]}${NC}"
    log_error "Please install them to continue."
    return 1
  fi
  return 0
}

# --- Main Function ---

asdfcli() {
  local OPT="$1"
  local ASDF_PLUGIN="$2"

  _check_dependencies || return 1

  case "$OPT" in
  "")
    log_info "No command specified. Starting interactive install..."
    _asdfcli_add_and_install_plugin
    ;;
  h | help | -h | --help)
    _asdfcli_usage
    ;;
  l | latest | -l | --latest)
    _asdfcli_add_and_install_plugin "$ASDF_PLUGIN" "latest"
    ;;
  u | update | -u | --update)
    _asdfcli_update_plugin "$ASDF_PLUGIN"
    ;;
  r | remove | -r | --remove)
    _asdfcli_remove_plugin "$ASDF_PLUGIN"
    ;;
  *)
    ASDF_PLUGIN="$OPT"
    _asdfcli_add_and_install_plugin "$ASDF_PLUGIN"
    ;;
  esac
}

# If the script is executed directly, call the main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  asdfcli "$@"
fi
