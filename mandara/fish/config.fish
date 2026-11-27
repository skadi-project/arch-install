if status is-interactive
    command -v starship &> /dev/null && starship init fish | source

    command -v zoxide &> /dev/null && zoxide init fish --cmd cd | source

    command -v eza &> /dev/null && alias ls='eza --icons --group-directories-first -1'

    abbr gd 'git diff'
    abbr ga 'git add .'
    abbr gc 'git commit -am'
    abbr gl 'git log'
    abbr gs 'git status'
    abbr gst 'git stash'
    abbr gsp 'git stash pop'
    abbr gp 'git push'
    abbr gpl 'git pull'
    abbr gsw 'git switch'
    abbr gsm 'git switch main'
    abbr gb 'git branch'
    abbr gbd 'git branch -d'
    abbr gco 'git checkout'
    abbr gsh 'git show'

    abbr l 'ls'
    abbr ll 'ls -l'
    abbr la 'ls -a'
    abbr lla 'ls -la'

    set -g fish_greeting

    bind ctrl-left backward-word
    bind ctrl-right forward-word
    bind ctrl-backspace backward-kill-word
    bind ctrl-delete kill-word

    function mark_prompt_start --on-event fish_prompt
        echo -en "\e]133;A\e\\"
    end

    command -v fastfetch &> /dev/null && fastfetch
end
