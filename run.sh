#!/usr/bin/env bash
# Run the AAP Configuration-as-Code dispatch through the execution environment
# defined in ansible-navigator.yml (EE image, inventory, vars, vault password and
# stdout mode are all configured there — no CLI flags needed).
#
# Why `env -u SSH_AUTH_SOCK`: on macOS, ansible-navigator tries to bind-mount the
# host SSH-agent socket (a launchd path like /var/run/com.apple.launchd.*/Listeners)
# into the podman VM, which doesn't exist inside that VM -> "statfs ... no such
# file". Unsetting SSH_AUTH_SOCK skips that mount. This is a host-shell fix that
# cannot be expressed in ansible-navigator.yml.
#
# Usage:
#   ./run.sh                 # applies the demo (dispatch_config.yml)
#   ./run.sh cleanup.yml     # tears it down (overrides the default playbook)
#   ./run.sh --pull-policy always   # any extra args pass straight through
set -euo pipefail
cd "$(dirname "$0")"
exec env -u SSH_AUTH_SOCK ansible-navigator run "$@"
