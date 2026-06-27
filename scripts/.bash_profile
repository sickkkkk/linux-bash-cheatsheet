# Arch Linux ~/.bash_profile — mirrors macOS interactive bash setup
#
# Install on Arch:
#   cp .bash_profile ~/.bash_profile
#   ln -sf ~/.bash_profile ~/.bashrc
#
# Packages: sudo pacman -S bash-completion fzf git
# Secrets:  ~/.bashrc.local (chmod 600) — see scripts/README.MD

# --- prompt helpers ---
git_branch() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return
  local b dirty=""
  b=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null) || return
  git diff --quiet --ignore-submodules --cached 2>/dev/null || dirty="*"
  git diff --quiet --ignore-submodules 2>/dev/null || dirty="*"
  printf "%s%s" "$b" "$dirty"
}

RESET=$'\e[0m'
BOLD=$'\e[1m'
GREEN=$'\e[32m'
CYAN=$'\e[36m'
YELLOW=$'\e[33m'
MAGENTA=$'\e[35m'
RED=$'\e[31m'

EXIT_SEG=""
K8S_SEG=""

__update_exit_seg() {
  if [ -n "$ec" ] && [ "$ec" -ne 0 ]; then
    EXIT_SEG="[${ec}] "
  else
    EXIT_SEG=""
  fi
}

__update_k8s_seg() {
  K8S_SEG=""
  command -v kubectl >/dev/null 2>&1 || return
  local raw ctx ns
  raw="$(kubectl config current-context 2>/dev/null || true)" || true
  [ -z "$raw" ] && return
  [[ "$raw" == arn:aws:eks:*:cluster/* ]] && ctx="${raw##*/}" || ctx="$raw"
  ns="$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null || true)"
  [ -z "$ns" ] && ns="default"
  K8S_SEG="[${ctx}:${ns}] "
}

case "$PROMPT_COMMAND" in
  *"__update_exit_seg"* ) : ;;
  ""                    ) PROMPT_COMMAND="__update_exit_seg" ;;
  *                     ) PROMPT_COMMAND="__update_exit_seg; $PROMPT_COMMAND" ;;
esac
case "$PROMPT_COMMAND" in
  *"__update_k8s_seg"* ) : ;;
  ""                   ) PROMPT_COMMAND="__update_k8s_seg" ;;
  *                    ) PROMPT_COMMAND="__update_k8s_seg; $PROMPT_COMMAND" ;;
esac
PROMPT_COMMAND='ec=$?; '"$PROMPT_COMMAND"

PS1="\[${RESET}\]\[${RED}\]\${EXIT_SEG}\[${RESET}\]\[${BOLD}${GREEN}\]\u\[${RESET}\] \
\[${MAGENTA}\]\${K8S_SEG}\[${RESET}\] \
\[${CYAN}\]\w\[${RESET}\] \
\[${YELLOW}\]\$(git rev-parse --is-inside-work-tree >/dev/null 2>&1 && printf '(' && git_branch && printf ')')\[${RESET}\]\n\\$ "

# --- aliases (Linux; macOS used ls -GFh) ---
alias grep='grep --color=auto'
alias ls='ls --color=auto -lh'
export CLICOLOR=1

# --- completion ---
if [ -f /usr/share/bash-completion/bash_completion ]; then
  . /usr/share/bash-completion/bash_completion
fi

if [ -f /usr/share/fzf/completion.bash ]; then
  . /usr/share/fzf/completion.bash
fi
if [ -f /usr/share/fzf/key-bindings.bash ]; then
  . /usr/share/fzf/key-bindings.bash
fi

if command -v kubectl >/dev/null 2>&1; then
  alias k=kubectl
  complete -o default -F __start_kubectl k
fi

# --- readline / tab completion (same as macOS) ---
bind 'set completion-ignore-case on'
bind 'set show-all-if-ambiguous on'
bind 'set menu-complete-display-prefix on'
bind 'set page-completions off'
bind 'TAB:menu-complete'
bind '"\e[Z": reverse-menu-complete'
bind 'set colored-completion-prefix on'
bind 'set colored-stats on'
bind 'set mark-symlinked-directories on'

export TERM=xterm-256color
export PATH="$HOME/.local/bin:$PATH"

# --- helpers ---
randpass() {
  local length=${1:-16}
  if ! [[ $length =~ ^[1-9][0-9]*$ ]]; then
    echo "Usage: randpass <length>" >&2
    return 1
  fi
  LC_ALL=C openssl rand -base64 $(( length * 2 )) \
    | LC_ALL=C tr -dc 'A-Za-z0-9' \
    | head -c "$length"
  printf '\n'
}

get_repo_root() {
  local root
  if root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    printf '%s\n' "$root"
    declare -g REPO_ROOT="$root"
    export REPO_ROOT
  else
    printf '%s\n' "$PWD"
  fi
}

aws_profile_switch() {
  command -v aws >/dev/null 2>&1 || { echo "aws CLI not found." >&2; return 1; }
  local -a profiles=()
  mapfile -t profiles < <(aws configure list-profiles 2>/dev/null)
  (( ${#profiles[@]} )) || { echo "No AWS profiles found."; return 1; }
  local selected
  if command -v fzf >/dev/null 2>&1; then
    selected=$(printf '%s\n' "${profiles[@]}" | fzf --prompt="AWS profile > " --height=40%)
    [[ -z "$selected" ]] && { echo "Cancelled."; return 1; }
  else
    local i choice
    for (( i=0; i<${#profiles[@]}; i++ )); do printf "%2d) %s\n" "$((i+1))" "${profiles[i]}"; done
    read -r -p "Select [1-${#profiles[@]}]: " choice
    selected="${profiles[choice-1]}"
  fi
  export AWS_PROFILE="$selected" AWS_DEFAULT_PROFILE="$selected"
  echo "AWS_PROFILE set to: $AWS_PROFILE"
}

# Machine-specific secrets and exports (not in git)
[[ -f ~/.bashrc.local ]] && . ~/.bashrc.local
