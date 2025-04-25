
# Table of Contents

1.  [outline](#org93c38ba)
    1.  [Install vterm](#org6626bfd)
    2.  [Fish shell optimize](#orgf1b9f1e)
    3.  [git push for proxy](#org3729e46)
    4.  [shell path](#orgb1d2fdc)

> vterm cloud not been available on windows  
> So windows user could use eshell as downgrade plan.  


<a id="org93c38ba"></a>

# outline


<a id="org6626bfd"></a>

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


<a id="orgf1b9f1e"></a>

## Fish shell optimize

If you are using fish shell ,fortunately there have some optimize config prepared for you.  

-   feature:  
    -   use fish shell on emacs vterm.
    -   use command \`ff\` %anyfile% on vterm will open %anyfile% in a new emacs buffer.It&rsquo;s very useful.

     1  function vterm_printf;
     2      if begin; [  -n "$TMUX" ]  ; and  string match -q -r "screen|tmux" "$TERM"; end
     3          # tell tmux to pass the escape sequences through
     4          printf "\ePtmux;\e\e]%s\007\e\\" "$argv"
     5      else if string match -q -- "screen*" "$TERM"
     6          # GNU screen (screen, screen-256color, screen-256color-bce)
     7          printf "\eP\e]%s\007\e\\" "$argv"
     8      else
     9          printf "\e]%s\e\\" "$argv"
    10      end
    11  end
    12  if [ "$INSIDE_EMACS" = 'vterm' ]
    13      function clear
    14          vterm_printf "51;Evterm-clear-scrollback";
    15          tput clear;
    16      end
    17  end
    18  
    19  
    20  function vterm_cmd --description 'Run an Emacs command among the ones been defined in vterm-eval-cmds.'
    21      set -l vterm_elisp ()
    22      for arg in $argv
    23          set -a vterm_elisp (printf '"%s" ' (string replace -a -r '([\\\\"])' '\\\\\\\\$1' $arg))
    24      end
    25      vterm_printf '51;E'(string join '' $vterm_elisp)
    26  end
    27  function ff
    28      set -q argv[1]; or set argv[1] "."
    29      vterm_cmd find-file (realpath "$argv")
    30  end


<a id="org3729e46"></a>

## git push for proxy

<https://juejin.cn/post/7095575058705285151>  

    Host github.com
        ProxyCommand nc -x 127.0.0.1:1089 %h %p


<a id="orgb1d2fdc"></a>

## shell path

doom emacs make exec-path sync from your shell path automatically. You could use \`(exec-path)\` to check it out.  
when you change your shell $PATH , use doom sync to reload it .  

