
# Table of Contents

1.  [outline](#orgfa3c894)
    1.  [Install vterm](#org865bcd8)
    2.  [Fish shell optimize](#orge1f8941)

> vterm cloud not been available on windows  
> So windows user could use eshell as downgrade plan.  


<a id="orgfa3c894"></a>

# outline


<a id="org865bcd8"></a>

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


<a id="orge1f8941"></a>

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

