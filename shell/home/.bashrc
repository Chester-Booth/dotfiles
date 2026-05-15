#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Only load Liquid Prompt in interactive shells
[[ $- = *i* ]] && {
    source /usr/bin/liquidprompt
    source ~/Documents/liquidprompt-powerline/powerline.theme
    lp_theme powerline_full
}


alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk

. "$HOME/.local/bin/env"



