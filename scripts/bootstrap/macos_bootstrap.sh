#!/bin/zsh
# vim: set ft=sh:
# shellcheck shell=bash

# environment variables for great justice
export XDG_CONFIG_HOME="$HOME/.config"
export GNUPGHOME="$XDG_CONFIG_HOME/gnupg"
export TRUSTED_GPGKEY_FINGREPRINT="77D8616541A323FF03E6639947BEA857F03AFE90"
export pinentry-program="/opt/homebrew/bin/pinentry-mac"
export GIT_HIGHLANDER="https://raw.githubusercontent.com/mkearns87/dotfiles/init/scripts/bootstrap/highlander.asc"
export TEMP_HIGHLANDER="/tmp/highlander.asc"
export WORKING_HIGHLANDER="/tmp/highlander.sh"

# OS Name
OS_NAME="$(uname)"
ARCH="$(uname -m)"
BREW="/opt/homebrew/bin/brew"

RED="\033[1;31m"
GREEN="\033[1;32m"
NOCOLOR="\033[0m"

print_with_color() {
  local color="$1"
  local message="$2"
  echo -e "${color}$message${NOCOLOR}"
  echo -e "\n"
  sleep 3
}

print_error() {
  local message="$1"
  print_with_color "$RED" "$message"
}

print_message() {
  local message="$1"
  print_with_color "$GREEN" "$message"
}

install_homebrew() {
  if [[ ! -f "$BREW" ]]; then
    print_message "Installing homebrew ... follow the prompts"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
}

bootstrap_brew_env() {
  # shellcheck disable=SC2046,SC1091
  eval $($BREW shellenv zsh)
  $BREW install --force chezmoi rcmdnk/file/brew-file
  # shellcheck disable=SC1091
  if [[ -f "$HOMEBREW_PREFIX/etc/brew-wrap" ]]; then
    export HOMEBREW_BREWFILE_ON_REQUEST=1
    source "$HOMEBREW_PREFIX/etc/brew-wrap"
  fi
}

setup_gnupg() {
  # shellcheck disable=2154
  $BREW install --force gnupg pinentry-mac git-crypt
  mkdir -p $GNUPGHOME
  chmod 700 $GNUPGHOME
  touch "$GNUPGHOME/gpg-agent.conf"
  echo "enable-ssh-support" > "$GNUPGHOME/gpg-agent.conf"
  gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "$TRUSTED_GPGKEY_FINGREPRINT"
  echo "$TRUSTED_GPGKEY_FINGREPRINT:6:" | gpg --import-ownertrust
  gpg --card-status
  gpg --list-secret-keys
}

link-ssh-auth-sock() {
if [[ -S $GNUPGHOME/S.gpg-agent.ssh ]]; then
  print_message "gpg-agent present, linking ssh listener."
  /bin/ln -sf $GNUPGHOME/S.gpg-agent.ssh $SSH_AUTH_SOCK
else
  print_error "Error: missing gpg-agent"
fi
}

decrypt_files() {
  gitattributes_file="$PWD/.gitattributes"
  [[ ! -f "$gitattributes_file" ]] && return
  if grep "git-crypt" "$gitattributes_file" &>/dev/null; then
    git-crypt unlock || (
      print_error "Error: Could not decrypt files"
      exit 1
    )
  fi
}

curl_highlander () {
  if [[ ! -f $TEMP_HIGHLANDER ]]; then
  echo "Obtaining highlander file."
  /usr/bin/curl -o $TEMP_HIGHLANDER $GIT_HIGHLANDER
  else
    echo "file already present."
  fi
}

there_can_be_only_one () {
  print_with_color $RED "THERE CAN BE ONLY ONE!!!"
  print_with_color $GREEN "DON'T FORGET TO TOUCH YUBIKEY!"
  gpg --decrypt $TEMP_HIGHLANDER > $WORKING_HIGHLANDER
  chmod +x $WORKING_HIGHLANDER
  echo "Running highlander script."
  $WORKING_HIGHLANDER
}

install_homebrew
bootstrap_brew_env
setup_gnupg
link-ssh-auth-sock
curl_highlander
there_can_be_only_one


# chezmoi init https://github.com/mkearns87/dotfiles.git --apply

# to do for private
# have chezmoi clone down encyrpted versions of cpe config and aws-okta; then
# chezmoi init mkearns87
# decrypt_files
# chezmoi apply
# also remove line 96 of this script