export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket"

# Editor settings
export EDITOR=micro
export VISUAL=micro
export SUDO_EDITOR=micro

# codex improvements

if [[ ! -o interactive &&
      ( -n ${CLAUDECODE:-} || -n ${CODEX_THREAD_ID:-} ) ]]; then
    setopt SH_WORD_SPLIT NO_NOMATCH NO_EQUALS
fi
