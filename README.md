
# Table of Contents

1.  [About](#org7ee58d1)
2.  [How to install](#orgcccf78a)
    1.  [Install emacs](#org4a1c5c2)
    2.  [Clone project](#orgc479598)
    3.  [Doom Install](#orgd858a27)
3.  [How to update](#org9eb7068)
4.  [Private setting](#orgdf0fe6d)
5.  [Neoemacs modules](#org3603277)
    1.  [Restclient](#orga46391b)
    2.  [Company box customize](#org4cced6d)
    3.  [Eredis Usage](#org9bb5eef)
    4.  [Bookmark](#org03c73d5)
    5.  [Libvterm Usage](#org9608975)
    6.  [Elpa Offline](#orgd6d6867)
    7.  [FZF Config](#org6bd0351)
6.  [Org mode](#org42c5908)
    1.  [Doom org style](#org66925a6)
    2.  [Dot sketchviz](#orgd327271)
    3.  [Latex PDF setting](#orgba37786)
7.  [Alfred](#org5fcdcab)
8.  [Questions](#org4502196)
    1.  [install ffmpeg](#org1db3bba)
    2.  [how to install all-the-icons?](#org4cc401d)
    3.  [how to install rime ?](#org353ecc0)
    4.  [how to install vterm?](#orgca205a0)
    5.  [lsp-springboot](#orgbeed206)
    6.  [useful key setting](#org31edc6b)
    7.  [why message showed could not load undo-tree history](#orgd0fce8b)
    8.  [File mode specification error: (file-missing Doing vfork No such file or directory)](#orgf96ee2d)
    9.  [image dir](#org377a36c)
9.  [About Logo](#org2d85697)
10. [Dependencies](#org9045d76)

![img](./image-use.png)  
![img](./logo.png)  


<a id="org7ee58d1"></a>

# About

Neo emacs is a configuration framework for GNU Emacs which is based on doom emacs and focuses on the java web application coding environment. Neo emacs has the following features:  

-   Code completion: Lsp-java supports maven and gradle project.
-   Program debugging: Dap-java supports program debugging.
-   Http client: Rest-client is a tool to manually explore and test HTTP REST webservices just like Postman.
-   SQL client: Ejc-sql turns Emacs into a simple SQL client which supports various databases.
-   Redis client: Eredis Non-blocking Redis client with focus on performance and robustness.
-   Terminal emulator: Emacs-libvterm (vterm) is fully-fledged terminal emulator inside GNU Emacs based on libvterm.
-   Knowledge management system: Org-roam borrows principles from the Zettelkasten method, providing a solution for non-hierarchical note-taking.
-   [onlinedoc](http://1.117.167.195/doc/neo-emacs.html)


<a id="orgcccf78a"></a>

# How to install


<a id="org4a1c5c2"></a>

## Install emacs

There have many emacs distribution,just choose one and install it.  

-   [gnu-emacs](https://www.gnu.org/software/emacs/) is the official emacs client.
-   [emacs-plus](https://github.com/d12frosted/homebrew-emacs-plus) which I used for a long time.
-   Building Emacs form source  
    
    building emacs with with source code  
    
        1    git clone git://git.savannah.gnu.org/emacs.git
        2    cd emacs
        3    git checkout emacs-28
        4    brew install  libxml2
        5    make configure
        6    ./configure --with-native-compilation --with-modern-papirus-icon --with-no-titlebar
        7    make -j4
        8    make install
        9    open nextstep/Emacs.app
-   EmacsPorts  
    
    EmacsPorts is the best choice to run NeoEmcas on macos.  
    
        brew install emacs-mac --with-natural-title-bar --with-mac-metal
        --with-librsvg --with-starter --with-emacs-big-sur-icon --with-native-comp
        defaults write org.gnu.Emacs TransparentTitleBar DARK
        defaults write org.gnu.Emacs HideDocumentIcon kES

After emacs installation, set environment variables which names EMACS ,this depends on your emacs exec path.  

    export EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs,


<a id="orgc479598"></a>

## Clone project

clone doom-emacs and neo-emacs from github.  

    git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.emacs.d
    git clone --depth 1 https://github.com/vanniuner/neo-emacs.git ~/.doom.d/


<a id="orgd858a27"></a>

## Doom Install

Set up a vpn if you need it.  

    export http_proxy="ip:port"
    export https_proxy="ip:port"

Set your emacs cmd for doom install.  

    export EMACS= $YOUR EMACS CMD PATH$

At last run below, this will take few minutes. And it depends on the quality of your network.  

    ~/.emacs.doom/bin/doom install


<a id="org9eb7068"></a>

# How to update

    export EMACS=/Applications/Emacs.app/Contents/MacOS/EMACS
    sh ~/.emacs.d/bin/doom upgrade
    sh ~/.emacs.d/bin/doom install
    sh ~/.emacs.d/bin/doom sync


<a id="orgdf0fe6d"></a>

# Private setting

Customize your private setting config in the config.el ;  
kse `setq`  

    (setq fd-exec-path                   "/opt/homebrew/bin/fd"
          rg-exec-path                   "/opt/homebrew/bin/rg")

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">
<caption class="t-bottom"><span class="table-number">Table 1:</span> neo-emacs basic setting</caption>

<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<tbody>
<tr>
<td class="org-left">emacs-module-root</td>
<td class="org-left">/opt/homebrew/opt/emacs-plus@28/include</td>
<td class="org-left">emcas module root</td>
</tr>


<tr>
<td class="org-left">rg-exec-path</td>
<td class="org-left">&ldquo;/opt/homebrew/bin/rg&rdquo;</td>
<td class="org-left">rg            exec path</td>
</tr>


<tr>
<td class="org-left">fd-exec-path</td>
<td class="org-left">&ldquo;/opt/homebrew/bin/fd&rdquo;</td>
<td class="org-left">fd            exec path</td>
</tr>


<tr>
<td class="org-left">dot-exec-path</td>
<td class="org-left">&ldquo;/opt/homebrew/bin/dot&rdquo;</td>
<td class="org-left">dot           exec path</td>
</tr>


<tr>
<td class="org-left">pdflatex-exec-path</td>
<td class="org-left">&ldquo;/Library/TeX/texbin/pdflatex&rdquo;</td>
<td class="org-left">pdflatex      exec path</td>
</tr>


<tr>
<td class="org-left">node-bin-dir</td>
<td class="org-left">&ldquo;~/node-v16.14.0/bin&rdquo;</td>
<td class="org-left">node exec path</td>
</tr>


<tr>
<td class="org-left">lsp-java-jdt-download-url</td>
<td class="org-left"><a href="http://1.117.167.195/download">http://1.117.167.195/download</a></td>
<td class="org-left">jdt-server URL</td>
</tr>


<tr>
<td class="org-left">lsp-java-java-path</td>
<td class="org-left">&#xa0;</td>
<td class="org-left">java11        exec path</td>
</tr>


<tr>
<td class="org-left">lsp-maven-path</td>
<td class="org-left">&ldquo;~/.m2/settings.xml&rdquo;</td>
<td class="org-left">maven setting path</td>
</tr>


<tr>
<td class="org-left">org-directory</td>
<td class="org-left">&ldquo;~/org/&rdquo;</td>
<td class="org-left">org           root path</td>
</tr>


<tr>
<td class="org-left">org-roam-directory</td>
<td class="org-left">&ldquo;~/org/org-roam&rdquo;</td>
<td class="org-left">org roam      root path</td>
</tr>


<tr>
<td class="org-left">display-line-numbers-type</td>
<td class="org-left">nil</td>
<td class="org-left">show line number</td>
</tr>


<tr>
<td class="org-left">rime-user-data-dir</td>
<td class="org-left">&ldquo;~/Library/Rime/&rdquo;</td>
<td class="org-left">rime config input</td>
</tr>


<tr>
<td class="org-left">rime-librime-root</td>
<td class="org-left">&ldquo;~/.doom.d/myconfig/rime-macos/dist&rdquo;</td>
<td class="org-left">emacs-rime/blob/master/</td>
</tr>
</tbody>
</table>


<a id="org3603277"></a>

# Neoemacs modules



<a id="orga46391b"></a>

## Restclient

Restclient provide a test suite for HTTP REST in Emacs.The official repository here [restclient.el](https://github.com/pashky/restclient.el).  
Yea, a pretty old old project.Fortunately doom emacs have integrated it.We just need open it with `(rest +jq)`.  
**+jq** makes restclient have the ability to parse a particular response which Content-Type equalable application/json.  
The amazing feature is restclient support set variables or make a part of response being a variables which one could as a request part for another HTTP REST.  

Here we take the value from results as a variables which named count.  

    GET https://www.zhihu.com/api/v3/oauth/sms/supported_countries
    -> jq-set-var :count .count

> Only **jq-set-var** could works when the content-type equal to application/json MIME type  

Fortunately we have solution for other mime type, it&rsquo;s restclient-set-var, you could use elisp to parse the response;  

    GET https://www.baidu.com/sugrec
    -> run-hook (restclient-set-var ":queryid" (cdr (assq 'queryid (json-read))))
    Content-Type: application/x-www-form-urlencoded; charset=utf-8

About the variables infomation in current buffer, we could use `C-c Tab` to show them.  


<a id="org4cced6d"></a>

## Company box customize

-   use \`M-x all-the-icons-material\` for checking icon
-   company-icon icon config file: ~/.emacs.d/modules/completion/company/config.el


<a id="org9bb5eef"></a>

## Eredis Usage

1.  config

    Use eredis firstly we could writen a funtion for a particular redis connection like this.  
    
        (use-package eredis)
        (defun redis-tencent-dev (dbnum)
          (interactive)
          (setq redis-tencent-dev (eredis-connect "tencent.local" 6379))
          (eredis-auth "yourpassword" redis-tencent-dev)
          (eredis-select dbNum)
        )
    
    Then you could use **M-x** ielm execution any redis command.  
    
        (redis-tencent-dev 1)
        (eredis-get "center-bpm:flow-list-count")

2.  send redis command on org mode

    key binding C-c C-c  
    
        ;; select database
        (eredis-select 1)
        ;; query center-bpm:flow-list-count
        (eredis-get "center-bpm:flow-list-count")
        (eredis-org-table-from-keys '("center-bpm:flow-list-count" ))
    
    <table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">
    
    
    <colgroup>
    <col  class="org-left" />
    
    <col  class="org-right" />
    
    <col  class="org-left" />
    </colgroup>
    <tbody>
    <tr>
    <td class="org-left">Key</td>
    <td class="org-right">Value(s)</td>
    <td class="org-left">Type</td>
    </tr>
    
    
    <tr>
    <td class="org-left">center-bpm:flow-list-count</td>
    <td class="org-right">1</td>
    <td class="org-left">string</td>
    </tr>
    </tbody>
    </table>


<a id="org03c73d5"></a>

## Bookmark

-   set a particular location for bookmark  
    
        (setq bookmark-default-file "~/org/org-roam/command/doom/config/bookmark")
-   key binding  
    
    <table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">
    
    
    <colgroup>
    <col  class="org-left" />
    
    <col  class="org-left" />
    </colgroup>
    <tbody>
    <tr>
    <td class="org-left">key</td>
    <td class="org-left">binding</td>
    </tr>
    
    
    <tr>
    <td class="org-left">Spc-Ent</td>
    <td class="org-left">select a bookmark</td>
    </tr>
    
    
    <tr>
    <td class="org-left">Spc b m</td>
    <td class="org-left">set a bookmark</td>
    </tr>
    
    
    <tr>
    <td class="org-left">Spc b M</td>
    <td class="org-left">delete a bookmark</td>
    </tr>
    </tbody>
    </table>


<a id="org9608975"></a>

## Libvterm Usage

-   Configuration  
    
    -   fish shell configuration
    
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
-   Ubuntu  
    
        sudo apt install cmake
        sudo apt install libtool-bin
-   MacOs  
    
        sudo brew install cmake libtool
-   Being with eshell  
    Eshell have a most wanted feature was **quickrun-eshell** which have a fast reload function after shell is runinng,you just use `C-c C-c` to stop it and use **r** to rerun you shell.It&rsquo;s pretty convenient.
-   Key Binding  
    
    <table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">
    
    
    <colgroup>
    <col  class="org-left" />
    
    <col  class="org-left" />
    
    <col  class="org-left" />
    </colgroup>
    <tbody>
    <tr>
    <td class="org-left">KEY</td>
    <td class="org-left">FUNCTION</td>
    <td class="org-left">DESCRIPTION</td>
    </tr>
    
    
    <tr>
    <td class="org-left">SPC v v</td>
    <td class="org-left">projectile-run-vterm</td>
    <td class="org-left">open vterm window base on the project root path</td>
    </tr>
    
    
    <tr>
    <td class="org-left">SPC v p</td>
    <td class="org-left">vterm-send-start</td>
    <td class="org-left">enable vterm screen roll</td>
    </tr>
    
    
    <tr>
    <td class="org-left">SPC v s</td>
    <td class="org-left">vterm-send-stop</td>
    <td class="org-left">disable vterm screen roll</td>
    </tr>
    </tbody>
    </table>


<a id="orgd6d6867"></a>

## Elpa Offline

rsync -avz rsync://mirrors.tuna.tsinghua.edu.cn/elpa ~/soft/emacs-elpa  

    (setq configuration-layer--elpa-archives
          '(("melpa-cn" . "/soft/emacs-elpa/melpa/")
            ("org-cn"   . "/soft/emacs-elpa/org/")
            ("gnu-cn"   . "/soft/emacs-elpa/gnu/")
            ("marmalade-cn"   . "/soft/emacs-elpa//marmalade/")))


<a id="org6bd0351"></a>

## FZF Config

1.  fish config

        set -x FZF_DEFAULT_OPTS "--preview-window 'right:57%'
            --preview 'bat --style=numbers --line-range :300 {}'
            --bind ctrl-y:preview-up,ctrl-e:preview-down,ctrl-b:preview
            -page-up,ctrl-f:preview-page-down,ctrl-u:preview-half-page-
            up,ctrl-d:preview-half-page-down,shift-up:preview-top,shift
            -down:preview-bottom,alt-up:half-page-up,
            alt-down:half-page-down"
        set -x FZF_DEFAULT_COMMAND  'fd --type f --hidden --follow
            --exclude ".git" .
            ".idea" . ".vscode" . "node_modules" .
            "build" . "target" . "classes" . "out" . "class" .
            "*.svg" . "*.puml" . "*.orgids" . "*.css" . "*.DS_Store" '

2.  how to ignore files

    -   add ~/.fdignore  
        
            .DS_Store
            .orgids
            *.svg
            *.puml
            *.css
            *.class
            *.attach
            *.~undo-tree~
            crpt


<a id="org42c5908"></a>

# Org mode


<a id="org66925a6"></a>

## Doom org style

A vairty of template about org mode code which one referenced the doom doc style [Preview](http://1.117.167.195/doc/doomorgstyle.html)  
How to use? <https://github.com/vanniuner/doom-org-style>  


<a id="orgd327271"></a>

## Dot sketchviz

    cd ~/.doom.d/neoemacs/sketchviz/sketch.js
    npm install --save roughjs
    npm i jsdom

-   usage  
    
    ![img](dotsk-demo.svg)


<a id="orgba37786"></a>

## Latex PDF setting

1.  install [mactex](https://tug.org/mactex/)
2.  put [elegantpaper.cls](https://github.com/ElegantLaTeX/ElegantPaper/blob/master/elegantpaper.cls) under the org file dir
3.  add the code in the head of your org mode file  
    
        #+LATEX_COMPILER: xelatex
        #+LATEX_CLASS: elegantpaper
        #+OPTIONS: prop:t

4.  [more info](https://www.sheerwill.live/posts/main/20220723211325-vanilla_emacs_with_purcell/)


<a id="org5fcdcab"></a>

# Alfred

Alfred repeat item  
perference -> Advanced -> Rebuild macOS Metadata.  
alfred -> reload  


<a id="org4502196"></a>

# Questions


<a id="org1db3bba"></a>

## install ffmpeg

-   brew install ffmpeg


<a id="org4cc401d"></a>

## how to install all-the-icons?

-   M-x install-package all-the-icons
-   M-x all-the-icons-install-fonts


<a id="org353ecc0"></a>

## how to install rime ?

-   M-x install-package rime

unzip rime-1.5.3-osx.zip -d ~/.emacs.d/librime  


<a id="orgca205a0"></a>

## how to install vterm?

    cd .emacs.d/.local/straight/build/vterm/
    mkdir -p build
    # install cmake and libtool-bin
    brew install cmake, brew install libtool
    mkdir -p build
    cd build
    cmake ..
    make


<a id="orgbeed206"></a>

## lsp-springboot

    mvn -Djdt.js.server.root=/Users/van/.emacs.d/.local/etc/.cache/
    lsp/eclipse.jdt.ls/server/ -Djunit.runner.root=
    /Users/van/.emacs.d/.local/etc/eclipse.jdt.ls/test-runner/
    -Djunit.runner.fileName=junit-platform-console-standalone.jar
    -Djava.debug.root=/Users/van/.emacs.d/.local/etc/.cache/lsp/
    eclipse.jdt.ls/server/bundles clean package
    -Djdt.download.url=http://download.eclipse.org/jdtls/snapshots/
    jdt-language-server-latest.tar.gz -f lsp-java-server-build.pom


<a id="org31edc6b"></a>

## useful key setting

-   Change caps\_lock to control if pressed with other keys, to escape if pressed alone.  
    ![img](key-change.png)


<a id="orgd0fce8b"></a>

## why message showed could not load undo-tree history

    brew install watchexec


<a id="orgf96ee2d"></a>

## File mode specification error: (file-missing Doing vfork No such file or directory)

When open a Java file this error happen.  
It&rsquo;s because the environment do not content on your GUI Emacs.  
It works well on your termianl environment with start Emacs by Emacs -nw.  
So the solution is change the execution file with the below shell script on MacOs  

-   emacs-plus cp to application dir

    cp -rf /opt/homebrew/opt/emacs-plus@28/Emacs.app/ /Applications/
    mv /Applications/Emacs.app/Contents/MacOS/Emacs Emacs.old

-   /Applications/Emacs.app/Contents/MacOS/Emacs

    #!/usr/local/bin/fish
    /Applications/Emacs.app/Contents/MacOS/Emacs.old


<a id="org377a36c"></a>

## image dir

    ln -s ~/org/org-roam/image any_where/image


<a id="org2d85697"></a>

# About Logo

edit with: [online-ps-editor](https://ps.gaoding.com/#/), [psd file](./logo.psd)  


<a id="org9045d76"></a>

# Dependencies

<https://github.com/hlissner/doom-emacs/blob/master/docs/getting_started.org>  

<https://github.com/BurntSushi/ripgrep>  

<https://github.com/junegunn/fzf>  

<https://github.com/kostafey/ejc-sql>  

<https://leiningen.org/>  

<https://plantuml.com/>  

<https://github.com/emacs-lsp/lsp-java>  

<https://projectlombok.org/>  

<https://github.com/DogLooksGood/emacs-rime>  

<https://github.com/be5invis/Sarasa-Gothic>  

<https://github.com/akicho8/string-inflection>  

<https://raw.githubusercontent.com/alibaba/p3c/master/p3c-formatter/eclipse-codestyle.xml>  

<https://www.tug.org/mactex/>  

