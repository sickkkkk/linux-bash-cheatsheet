# Arch Linux bash setup (mirrors macOS)

Instructions to replicate the interactive bash experience from macOS (`~/.bash_profile`) on Arch Linux — custom prompt, tab completion, fzf, git/k8s context in PS1, and helper functions.

**Do not copy secrets** (vault tokens, API keys, passwords) into tracked files. Use `~/.bashrc.local` on each machine.

---

### Install packages (Arch)

```bash
sudo pacman -S bash-completion fzf git
```

Optional (only if you use them):

```bash
sudo pacman -S kubectl aws-cli-cli alacritty
```

| macOS (Homebrew) | Arch |
|------------------|------|
| `brew` bash-completion | `bash-completion` → `/usr/share/bash-completion/bash_completion` |
| `brew` fzf shell scripts | `fzf` → `/usr/share/fzf/completion.bash`, `key-bindings.bash` |
| `ls -GFh` | `ls --color=auto -lh` |
| config in `~/.bash_profile` | `~/.bashrc` + source from `~/.bash_profile` |

---

### Archcraft i3 terminal

With **`archcraft-i3wm`**, alacritty is preconfigured under `~/.config/i3/alacritty/`.

| Key | Action |
|-----|--------|
| **Super+Return** | Terminal |
| **Super** | Rofi launcher |

Edit terminal: `~/.config/i3/alacritty/alacritty.toml`  
Edit keybinds: `~/.config/i3/config.d/02_keybindings.conf`  
Reload i3: **Super+Shift+C**

On old NVIDIA (T410): if alacritty fails, use `LIBGL_ALWAYS_SOFTWARE=1 alacritty` in keybindings.

---

### Paste-ready file

Copy **`scripts/.bash_profile`** to the Arch machine:

```bash
cp .bash_profile ~/.bash_profile
ln -sf ~/.bash_profile ~/.bashrc
source ~/.bash_profile
```

The symlink covers i3/alacritty sessions that start non-login shells (they read `~/.bashrc` only).

---

### `~/.bash_profile` contents (reference)

Same as `scripts/.bash_profile` in this repo:

```bash
# ~/.bashrc — adapted from macOS ~/.bash_profile

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
```

---

### Private exports (`~/.bashrc.local`)

Per-machine only — **never commit**:

```bash
nano ~/.bashrc.local
chmod 600 ~/.bashrc.local
```

Examples (add what you need from macOS):

```bash
export KUBECONFIG="$HOME/.kube/config.yaml"
export AWS_PROFILE="my-profile"
# export VAULT_ADDR=...
# ulimit -n 50000
```

---

### macOS-only items (install separately on Arch if needed)

| Feature | macOS | Arch |
|---------|-------|------|
| Node (nvm) | `NVM_DIR` in bash_profile | `yay -S nvm` or `fnm` / install from nvm.io |
| Rust | `~/.cargo/env` | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` |
| kubectl context switcher | `switcher init bash` | install switcher binary or use `kubectx` from AUR |
| Homebrew | `eval "$(brew shellenv)"` | not used on Arch |

---

### Quick one-liner install block (Arch)

```bash
sudo pacman -S bash-completion fzf git alacritty
# create ~/.bashrc and ~/.bash_profile from sections above
source ~/.bashrc
```

---

### Verify

```bash
type git_branch randpass aws_profile_switch
bind -v | grep completion-ignore-case
# Ctrl+R should search history (fzf if installed)
# Tab should cycle completions (menu-complete)
```

Prompt should show: optional `[exitcode]`, green `user`, optional `[k8s-context:namespace]`, cyan path, yellow `(branch*)`, then `$` on the next line — same layout as macOS.
