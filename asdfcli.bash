#!/bin/bash

_asdfcli_usage() {
  echo 'usage:'
  echo '  asdfcli [h | help   | -h | --help]                  # display help menu'
  echo
  echo '  asdfcli [l | latest | -l | --latest] [plugin_name]  # install package with asdf'
  echo '  asdfcli [u | update | -u | --update] [plugin_name]  # update package with asdf'
  echo '  asdfcli [r | remove | -r | --remove] [plugin_name]  # remove package with asdf'
}

_semver_ge() {
  local v1_parts
  local v2_parts
  IFS='.' read -ra v1_parts <<<"$1"
  IFS='.' read -ra v2_parts <<<"$2"

  local i
  local max_len="${#v1_parts[@]}"

  if (("${#v2_parts[@]}" > max_len)); then
    max_len="${#v2_parts[@]}"
  fi

  for ((i = 0; i < max_len; i++)); do
    local v1_segment_str="${v1_parts[i]:-0}"
    local v2_segment_str="${v2_parts[i]:-0}"

    printf -v v1_segment_dec "%d" "$v1_segment_str"
    printf -v v2_segment_dec "%d" "$v2_segment_str"

    if ((v1_segment_dec > v2_segment_dec)); then
      return 0
    elif ((v1_segment_dec < v2_segment_dec)); then
      return 1
    fi
  done

  return 0
}

# Returns 1 if VERSION < 0.16.0
#
# As some commands change name/behaviour from 0.16.0 (global->set, list...)
# this function is necessary to handle asdfcli across multiple asdf versions
_asdfcli_check_asdf_version() {
  local asdf_version_output
  local parsed_version
  local required_version="0.16.0"

  asdf_version_output=$(asdf --version 2>&1 || true)

  if [[ "$asdf_version_output" =~ ^v([0-9]+\.[0-9]+\.[0-9]+.*)$ ]]; then
    parsed_version="${BASH_REMATCH[1]}"
    parsed_version="${parsed_version%%-*}"
  elif [[ "$asdf_version_output" =~ ^asdf\ version\ v?([0-9]+\.[0-9]+\.[0-9]+.*)$ ]]; then
    parsed_version="${BASH_REMATCH[1]}"
    parsed_version="${parsed_version%%-*}"
  else
    echo "Error: Could not parse asdf version output: '$asdf_version_output'" >&2
    return 1
  fi

  if [[ -z "$parsed_version" ]]; then
    echo "Error: Parsed an empty asdf version string." >&2
    return 1
  fi

  return $(_semver_ge "$parsed_version" "$required_version")
}

_asdfcli_select_plugin() {
  asdf plugin list all | sed '1!G;h;$!d' | fzf | awk '{print $1}'
}

_asdfcli_install_plugin() {
  local ASDF_PLUGIN=$1
  local SHIM_VERSION=$2
  local SET_GLOBAL="set"

  _asdfcli_check_asdf_version || SET_GLOBAL="global"

  asdf install $ASDF_PLUGIN $SHIM_VERSION &&
    asdf $SET_GLOBAL $ASDF_PLUGIN $SHIM_VERSION
}

_asdfcli_remove_plugin() {
  local ASDF_PLUGIN="$1"

  if [[ -z "$ASDF_PLUGIN" ]]; then
    echo "No plugin specified. Please select one to remove:"
    ASDF_PLUGIN=$(asdf plugin list | sed '1!G;h;$!d' | fzf --exit-0)
    if [[ -z "$ASDF_PLUGIN" ]]; then
      echo "No plugin selected. Aborting removal." >&2
      return 1
    fi
  fi

  echo "Removing '$ASDF_PLUGIN' plugin..."
  if asdf plugin remove "$ASDF_PLUGIN"; then
    echo "Plugin '$ASDF_PLUGIN' removed successfully."
    return 0
  else
    echo "Error: Failed to remove '$ASDF_PLUGIN' plugin." >&2
    return 1
  fi
}

_asdfcli_update_plugin() {
  local OK_SIGN="\033[92m\xE2\x9c\x93\033[0m"
  local KO_SIGN="\033[91m\xE2\x9C\x97\033[0m"
  local ASDF_PLUGIN

  echo "Please select a plugin to update:"
  ASDF_PLUGIN=$(asdf plugin list | sed '1!G;h;$!d' | fzf --exit-0)

  if [[ -z "$ASDF_PLUGIN" ]]; then
    echo "No plugin selected. Aborting update." >&2
    return 1
  fi

  local SHIM_VERSION="latest"

  echo -e "Attempting to update '\033[93m$ASDF_PLUGIN\033[0m' to '$SHIM_VERSION'..."
  if _asdfcli_install_plugin "$ASDF_PLUGIN" "$SHIM_VERSION"; then
    echo -e "${OK_SIGN} Successfully updated '$ASDF_PLUGIN'."
    return 0
  else
    echo -e "${KO_SIGN} Failed to update '$ASDF_PLUGIN'." >&2
    return 1
  fi
}

_asdfcli_add_and_install_plugin() {
  local ASDF_PLUGIN=$1
  local SHIM_VERSION=$2
  local OK_SIGN="\033[92m\xE2\x9c\x93\033[0m"

  [[ -z $ASDF_PLUGIN ]] && ASDF_PLUGIN=$(_asdfcli_select_plugin)

  echo -e "Adding '\033[93m$ASDF_PLUGIN\033[0m' plugin..."

  if [[ -n $SHIM_VERSION ]]; then
    asdf plugin add $ASDF_PLUGIN &&
      _asdfcli_install_plugin $ASDF_PLUGIN $SHIM_VERSION
  else
    asdf plugin add $ASDF_PLUGIN &&
      echo -e $OK_SIGN &&
      SHIM_VERSION=$(asdf list all $ASDF_PLUGIN | sed '1!G;h;$!d' | fzf) &&
      _asdfcli_install_plugin $ASDF_PLUGIN $SHIM_VERSION
  fi

  # Remove plugin if not installed
  if [[ -z $SHIM_VERSION ]]; then
    if _asdfcli_check_asdf_version; then
      asdf list $ASDF_PLUGIN &>/dev/null || _asdfcli_remove_plugin $ASDF_PLUGIN
    else
      [[ $(asdf list zola 2>&1 >/dev/null) =~ "No versions installed" ]] &&
        _asdfcli_remove_plugin $ASDF_PLUGIN
    fi
  fi
}

_check_requested_bins() {
  local REQUESTED_BINS=("asdf" "fzf" "sed" "awk")
  local MISSING_BIN=0

  for bin in ${REQUESTED_BINS[*]}; do
    if ! command -v "$bin" &>/dev/null; then
      MISSING_BIN=$(($MISSING_BIN + 1))
      [[ $MISSING_BIN -eq 1 ]] && echo "Please install missing binaries:"
      [[ $MISSING_BIN -ne 0 ]] && echo " - $bin"
    fi
  done

  return $MISSING_BIN
}

asdfcli() {
  local OPT="$1"
  local ASDF_PLUGIN="$2"

  _check_requested_bins || return 1

  case "$OPT" in
  "")
    echo "No command specified. Selecting a plugin to add/install..."
    ASDF_PLUGIN=$(_asdfcli_select_plugin)
    if [[ -n "$ASDF_PLUGIN" ]]; then
      _asdfcli_add_and_install_plugin "$ASDF_PLUGIN"
    else
      echo "No plugin selected. Exiting." >&2
      return 1
    fi
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
