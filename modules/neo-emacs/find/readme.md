
# Table of Contents

1.  [conflict with toggle-input-method](#org3915be3)
2.  [most wanted](#org3f6a029)
    1.  [code advice](#org842f29c)



<a id="org3915be3"></a>

# conflict with toggle-input-method

In the mini search buffer `C-;`  is binding to \`embark-act\`. It&rsquo;s conflict with [toggle-input-method](file:///Users/van/.doom.d/modules/neo-emacs/rime/config.el).  

-   There have two solution:  
    -   Disable short cut `C-;` ,we need chage file here in [vertico/config.el](file:///Users/van/.emacs.d/modules/completion/vertico/config.el).  
        
            1     (map! [remap describe-bindings] #'embark-bindings
            2          ;; "C-;"               #'embark-act  ; to be moved to :config default if accepted
            3          (:map minibuffer-local-map
            4           ;; "C-;"               #'embark-act
    -   The short cut `C-SPC` seems more popular for \`toogle-input-method\`, cause windows have a default setting for `C-SPC`.So a better way is binding `C-SPC` to \`toogle-input-method\`


<a id="org3f6a029"></a>

# TODO most wanted


<a id="org842f29c"></a>

## code advice

Automatically to evil normal mode when \`J\` \`K\` be clicked.  
It&rsquo;s actually a advice regard to \`+workspace/switch-right\` and \`+workspace/switch-right\`.  

    (map! :n "K"                  '+workspace/switch-right               )
    (map! :n "J"                  '+workspace/switch-left                )

