
# Table of Contents

1.  [outline](#org53f109d)
    1.  [Install vterm](#orge2e6139)
    2.  [Fish shell optimize](#orged39c82)
    3.  [git push for proxy](#orga6e817b)
    4.  [shell path](#org4e7b978)

> vterm cloud not been available on windows  
> So windows user could use eshell as downgrade plan.  


<a id="org53f109d"></a>

# outline


<a id="orge2e6139"></a>

## Install vterm

If vterm complie failed in emacs, we could complie it manually.  

    cd .emacs.d/.local/straight/build/vterm/
    mkdir -p build
    # install cmake and libtool-bin
    brew install cmake, brew install libtool
    mkdir -p build
    cd build
    cmake ..
    make


<a id="orged39c82"></a>

## Fish shell optimize

If you are using fish shell ,fortunately there have some optimize config prepared for you.  

-   feature:  
    -   use fish shell on emacs vterm.
    -   use command \`ff\` %anyfile% on vterm will open %anyfile% in a new emacs buffer.It&rsquo;s very useful.

    function vterm_printf;
        if begin; [  -n "$TMUX" ]  ; and  string match -q -r "screen|tmux" "$TERM"; end
            # tell tmux to pass the escape sequences through
            printf "\ePtmux;\e\e]%s\007\e\\" "$argv"
        else if string match -q -- "screen*" "$TERM"
            # GNU screen (screen, screen-256color, screen-256color-bce)
            printf "\eP\e]%s\007\e\\" "$argv"
        else
            printf "\e]%s\e\\" "$argv"
        end
    end
    if [ "$INSIDE_EMACS" = 'vterm' ]
        function clear
            vterm_printf "51;Evterm-clear-scrollback";
            tput clear;
        end
    end
    
    
    function vterm_cmd --description 'Run an Emacs command among the ones been defined in vterm-eval-cmds.'
        set -l vterm_elisp ()
        for arg in $argv
            set -a vterm_elisp (printf '"%s" ' (string replace -a -r '([\\\\"])' '\\\\\\\\$1' $arg))
        end
        vterm_printf '51;E'(string join '' $vterm_elisp)
    end
    function ff
        set -q argv[1]; or set argv[1] "."
        vterm_cmd find-file (realpath "$argv")
    end


<a id="orga6e817b"></a>

## git push for proxy

<https://juejin.cn/post/7095575058705285151>  

    Host github.com
        ProxyCommand nc -x 127.0.0.1:1089 %h %p


<a id="org4e7b978"></a>

## shell path

doom emacs make exec-path sync from your shell path automatically. You could use \`(exec-path)\` to check it out.  
when you change your shell $PATH , use doom sync to reload it .  

