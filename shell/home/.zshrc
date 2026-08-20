# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi


. "$HOME/.local/bin/env"


# history
: "${HISTFILE:=${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history}"
mkdir -p "${HISTFILE:h}"
setopt share_history
setopt hist_ignore_dups
HISTSIZE=10000
SAVEHIST=10000

# powerlevel10k
source ~/.config/zsh/powerlevel10k/powerlevel10k.zsh-theme


# completion
# zsh-autocomplete loads compinit and zsh/complist.

# plugins 

## shift select
source ~/Code/git-clone/zsh-shift-select/zsh-shift-select.plugin.zsh

## autocomplete
# Keep the history/completion menus, but avoid long redraw stalls while typing.
zstyle ':autocomplete:*' delay 0.15
zstyle ':autocomplete:*' timeout 0.35
source /usr/share/zsh/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh

### shift tab completion menu
bindkey '^[[Z' menu-select
bindkey '^I' menu-select

### tab and shift tab work in menu
bindkey -M menuselect              '^I'         menu-complete
bindkey -M menuselect "$terminfo[kcbt]" reverse-menu-complete

### up arrow history menu
bindkey '^[[A' history-incremental-search-backward

## autosuggestions
#source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
#ZSH_AUTOSUGGEST_STRATEGY=(history completion)

#right arrow
#bindkey '^[[C' _right_autosuggest_or_forward



# key handling
bindkey -e


# alias
alias CD='cd'
alias ls='exa --color=auto --icons=auto --across --group-directories-first  '
alias LS='ls'
alias icat='kitty +kitten icat '
alias fastfetch='fastfetch --logo none'
alias m='micro'
alias cpwd='printf "%s" "$PWD" | wl-copy'
alias cd..="cd .."
alias codex="codex --yolo"
alias ns='notify-send'
alias bin='gio trash'

cpfile() {
    print -rn -- "${1:A}" | wl-copy
}

cpss() {
    local files=(~/Pictures/Screenshots/*(.Nom))
    print -rn -- "$files[1]" | wl-copy
    print 'Copied.'
}


# git alias
alias gs='git status --short'
alias gsw='git switch '
alias g='git'
gacp() {
  g add .
  g commit -m "$*"
  g push
}
#zen
alias zen="zen-browser"
#ytdaily
alias yt="ytdaily open"


# java
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk

# for vesktop
export XDG_CONFIG_HOME="$HOME/.config"
export GLOW_STYLE="$XDG_CONFIG_HOME/glow/blox-theme.json"



# zoxide
eval "$(zoxide init zsh)"

# cd * opens in new tab if multiple directories are given, otherwise cd as normal
cd() {
  # Globs like `cd *` expand before this function runs. If that expansion
  # produces multiple arguments, open one Kitty tab for each directory and
  # ignore files from the same glob.
  if (( $# > 1 )); then
    local dir
    local -a dirs

    for dir in "$@"; do
      [[ -d "$dir" ]] && dirs+=("$dir")
    done

    if (( ${#dirs} > 0 )); then
      for dir in "${dirs[@]}"; do
        kitty @ launch --type=tab --tab-title="${dir:t}" --cwd="${dir:a}" >/dev/null
      done
      return
    fi
  fi

  # Keep normal path navigation literal, including quoted special names like
  # `cd '*'` when a directory named `*` exists.
  if (( $# == 1 )) && [[ -d "$1" ]]; then
    builtin cd -- "$1"
    return
  fi

  # otherwise use zoxide
  z "$@"
}

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Support for Ctrl+Arrow keys (Left/Right) to jump words
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# (Optional) Support for Ctrl+Delete and Ctrl+Backspace/Insert if they aren't working
bindkey '^[[3;5~' kill-word              # Ctrl+Delete
bindkey '^H' backward-kill-word          # Ctrl+Backspace (standard)
bindkey '^[[2;5~' copy-region-as-kill    # Ctrl+Insert

#zstyle ':autocomplete:*' override-complete no


#right arrow accept autosuggest fallback to cursor move
_right_autosuggest_or_forward() {
  if [[ -n $ZSH_AUTOSUGGEST_BUFFER ]]; then
    zle autosuggest-accept
  else
    zle forward-char
  fi
}
zle -N _right_autosuggest_or_forward



# fix terminal issues in IDEs
if [[ "$TERMINAL_EMULATOR" == "JetBrains-JediTerm" || "$TERM_PROGRAM" == "vscode" ]]; then
  typeset -g POWERLEVEL9K_DISABLE_RPROMPT=true
  unset RPROMPT
fi


# make multi-char emoji render correctly
setopt COMBINING_CHARS
export ANDROID_HOME=/opt/android-sdk
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
