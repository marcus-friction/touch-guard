#!/usr/bin/env bash
set -euo pipefail

uuid='touch-guard@marcus-friction.github.io'
helper_path='/usr/local/libexec/touch-guard-helper'
policy_path='/usr/share/polkit-1/actions/org.marcusfriction.touchguard.policy'

gnome-extensions disable "$uuid" || true
gnome-extensions uninstall "$uuid"
sudo rm -f -- "$helper_path" "$policy_path"
printf 'Touch Guard has been uninstalled.\n'
