#!/usr/bin/env bash
#
# Configure the GitLab HTTP backend for Terraform and initialise the working
# directory.
#
# The personal access token is never written to disk: it only lives in the
# shell environment and is gone when the terminal is closed.
#
# Usage:
#   source scripts/tf-env.sh     # keeps the backend config for the whole shell
#   make state-setup             # one-shot, same prompts
#
# Note: this file is sourced, so it must not use `set -e` or `set -u`.
# Those options would leak into the caller's interactive shell.

GITLAB_HOST="${GITLAB_HOST:-gitlab.com}"
GITLAB_PROJECT="${GITLAB_PROJECT:-WhiteMuush/simplon-kubernetes-velero-azure}"
GITLAB_USER="${GITLAB_USER:-WhiteMuush}"
TF_STATE_NAME="${TF_STATE_NAME:-aks-velero}"
TF_ROOT_DIR="${TF_ROOT_DIR:-terraform}"

# Detect whether this file was sourced rather than executed. Exports made by a
# child process would never reach the caller's shell, so executing it is a bug.
gitlab_backend_is_sourced() {
  if [ -n "$ZSH_VERSION" ]; then
    case "$ZSH_EVAL_CONTEXT" in
      *:file*) return 0 ;;
      *) return 1 ;;
    esac
  fi

  # Plain "${BASH_SOURCE-}" instead of "${BASH_SOURCE[0]}": the array subscript
  # is a parse error in dash, which reads the whole function up front even
  # though this branch never runs there.
  if [ -n "$BASH_VERSION" ]; then
    [ "${BASH_SOURCE-}" != "$0" ] && return 0
    return 1
  fi

  # Unknown shell: assume sourced rather than blocking the user.
  return 0
}

# GitLab addresses projects by URL-encoded path, so "group/project" becomes
# "group%2Fproject".
gitlab_backend_encode_project() {
  printf '%s' "$1" | sed 's|/|%2F|g'
}

# Print the GitLab username owning the token, or fail if GitLab rejects it.
# Showing the owner rather than a masked secret tells the user which token is
# loaded without leaking any part of it.
gitlab_backend_token_owner() {
  local token="$1"
  local response

  response=$(curl -sf \
    -H "PRIVATE-TOKEN: ${token}" \
    "https://${GITLAB_HOST}/api/v4/user") || return 1

  printf '%s' "$response" | sed -n 's/.*"username":"\([^"]*\)".*/\1/p'
}

# A valid token is not enough: it also needs access to this specific project.
gitlab_backend_has_project_access() {
  local token="$1"
  local encoded_project="$2"

  curl -sf -o /dev/null \
    -H "PRIVATE-TOKEN: ${token}" \
    "https://${GITLAB_HOST}/api/v4/projects/${encoded_project}"
}

# Read a token without echoing it to the terminal and without leaving it in the
# shell history.
gitlab_backend_prompt_token() {
  local token=""

  printf 'GitLab PAT (api scope, input hidden): ' >&2
  stty -echo 2>/dev/null
  read -r token
  stty echo 2>/dev/null
  printf '\n' >&2

  printf '%s' "$token"
}

# Ask whether the token already loaded should be replaced. Anything other than
# an explicit yes keeps the current one.
gitlab_backend_confirm_replace() {
  local answer=""

  printf 'Replace it? [y/N] ' >&2
  read -r answer

  case "$answer" in
    [yY] | [yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

# Report on the token already present in the environment, if any, and say
# whether it can be reused as is.
gitlab_backend_inspect_current_token() {
  local encoded_project="$1"
  local owner

  if [ -z "$TF_HTTP_PASSWORD" ]; then
    printf 'No token loaded in this shell.\n' >&2
    return 1
  fi

  owner=$(gitlab_backend_token_owner "$TF_HTTP_PASSWORD")
  if [ -z "$owner" ]; then
    printf 'A token is loaded but GitLab rejects it (revoked or expired).\n' >&2
    return 1
  fi

  if ! gitlab_backend_has_project_access "$TF_HTTP_PASSWORD" "$encoded_project"; then
    printf 'Token of "%s" is valid but has no access to %s.\n' \
      "$owner" "$GITLAB_PROJECT" >&2
    return 1
  fi

  printf 'A token is already loaded, owned by "%s", valid for %s.\n' \
    "$owner" "$GITLAB_PROJECT" >&2
  return 0
}

# Return a token that is known to work against this project, either the one
# already loaded or a freshly entered one.
gitlab_backend_resolve_token() {
  local encoded_project="$1"
  local token owner

  if gitlab_backend_inspect_current_token "$encoded_project"; then
    if ! gitlab_backend_confirm_replace; then
      printf '%s' "$TF_HTTP_PASSWORD"
      return 0
    fi
  fi

  if [ ! -t 0 ]; then
    printf 'No usable token and no terminal to prompt on. ' >&2
    printf 'Export TF_HTTP_PASSWORD before running this.\n' >&2
    return 1
  fi

  token=$(gitlab_backend_prompt_token)
  if [ -z "$token" ]; then
    printf 'No token provided, aborting.\n' >&2
    return 1
  fi

  owner=$(gitlab_backend_token_owner "$token")
  if [ -z "$owner" ]; then
    printf 'GitLab rejected the token. Check that it has the "api" scope.\n' >&2
    return 1
  fi

  if ! gitlab_backend_has_project_access "$token" "$encoded_project"; then
    printf 'Token of "%s" has no access to %s.\n' "$owner" "$GITLAB_PROJECT" >&2
    return 1
  fi

  printf 'Token accepted for "%s".\n' "$owner" >&2
  printf '%s' "$token"
}

# Terraform reads TF_HTTP_* automatically for the http backend, which keeps the
# backend block in main.tf empty and free of any credential.
gitlab_backend_export_config() {
  local token="$1"
  local encoded_project="$2"
  local base_url="https://${GITLAB_HOST}/api/v4/projects/${encoded_project}/terraform/state/${TF_STATE_NAME}"

  export TF_HTTP_ADDRESS="$base_url"
  export TF_HTTP_LOCK_ADDRESS="${base_url}/lock"
  export TF_HTTP_UNLOCK_ADDRESS="${base_url}/lock"
  export TF_HTTP_LOCK_METHOD="POST"
  export TF_HTTP_UNLOCK_METHOD="DELETE"
  export TF_HTTP_USERNAME="$GITLAB_USER"
  export TF_HTTP_PASSWORD="$token"
  export TF_HTTP_RETRY_WAIT_MIN="5"
}

gitlab_backend_setup() {
  local encoded_project token

  if ! command -v curl >/dev/null 2>&1; then
    printf 'curl is required but not installed.\n' >&2
    return 1
  fi

  encoded_project=$(gitlab_backend_encode_project "$GITLAB_PROJECT")

  token=$(gitlab_backend_resolve_token "$encoded_project") || return 1

  gitlab_backend_export_config "$token" "$encoded_project"

  printf 'Backend ready: state "%s" on %s\n' "$TF_STATE_NAME" "$GITLAB_PROJECT" >&2
  terraform -chdir="$TF_ROOT_DIR" init
}

if ! gitlab_backend_is_sourced; then
  printf 'Error: run it with "source %s"\n' "$0" >&2
  exit 1
fi

gitlab_backend_setup
