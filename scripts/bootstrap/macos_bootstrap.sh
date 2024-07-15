#!/bin/zsh
# vim: set ft=sh:
# shellcheck shell=bash

# environment variables for great justice
export XDG_CONFIG_HOME="$HOME/.config"
export GNUPGHOME="$XDG_CONFIG_HOME/gnupg"
export TRUSTED_GPGKEY_FINGREPRINT="77D8616541A323FF03E6639947BEA857F03AFE90"
export pinentry_program="/opt/homebrew/bin/pinentry-mac"
export GIT_HIGHLANDER="https://raw.githubusercontent.com/mkearns87/dotfiles/init/scripts/bootstrap/highlander.asc"
export TEMP_HIGHLANDER="/tmp/highlander.asc"
export WORKING_HIGHLANDER="/tmp/highlander.sh"
export TEMP_PUBKEY="/tmp/pubkey.asc"
export GIT_PUBKEY="https://raw.githubusercontent.com/mkearns87/dotfiles/init/scripts/bootstrap/77D8616541A323FF03E6639947BEA857F03AFE90.asc"
export TOUCH_ID_TEMPLATE_FILE="/etc/pam.d/sudo_local.template"
export TOUCH_ID_AUTH_FILE="/etc/pam.d/sudo_local"

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

curl_pubkey(){
  if [[ ! -f $TEMP_PUBKEY ]]; then
  echo "pubkey doesn't exist- curling."
  /usr/bin/curl -o $TEMP_PUBKEY $GIT_PUBKEY
  else
    echo "file already present."
  fi
}

setup_gnupg() {
  # shellcheck disable=2154
  $BREW install --force gnupg pinentry-mac git-crypt
  mkdir -p $GNUPGHOME
  chmod 700 $GNUPGHOME
  touch "$GNUPGHOME/gpg-agent.conf"
  echo "enable-ssh-support" > "$GNUPGHOME/gpg-agent.conf"
  echo "standard-resolver" >  "$GNUPGHOME/dirmngr.conf"
  pkill dirmngr
  sleep 3
  gpg --keyserver hkps://keys.openpgp.org --recv-keys "$TRUSTED_GPGKEY_FINGREPRINT"
  # gpg --import $TEMP_PUBKEY
  echo "$TRUSTED_GPGKEY_FINGREPRINT:6:" | gpg --import-ownertrust
  gpg --card-status
  gpg --list-secret-keys
}

link-ssh-auth-sock() {
if [[ -S $GNUPGHOME/S.gpg-agent.ssh ]]; then
  print_message "gpg-agent present, linking ssh listener."
  /bin/ln -sf $GNUPGHOME/S.gpg-agent.ssh $SSH_AUTH_SOCK
  print_message "restarting gpg agent to reflect changes"
  gpg-connect-agent updatestartuptty /bye
else
  print_error "Error: missing gpg-agent"
fi
}

kill_TALLogoutSavesState() {
  print_message "Disabling macOS reopen windows on login."
  /usr/bin/defaults write com.apple.loginwindow -bool false
}

touch_id_sudo() {
    if [[ ! -f "$TOUCH_ID_AUTH_FILE" ]]; then
        echo "Setting up Touch ID for sudo, you might need to authenticate"
        sudo /bin/cp "$TOUCH_ID_TEMPLATE_FILE" "$TOUCH_ID_AUTH_FILE"
        sudo sed -i '' -e 's,#auth       sufficient     pam_tid.so,auth       sufficient     pam_tid.so,g' "$TOUCH_ID_AUTH_FILE"
        sudo /usr/sbin/chown root:wheel "$TOUCH_ID_AUTH_FILE"
        sudo /bin/chmod 555 "$TOUCH_ID_AUTH_FILE"
    else
        echo "$TOUCH_ID_AUTH_FILE already exists."
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
kill_TALLogoutSavesState
touch_id_sudo
curl_pubkey
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
