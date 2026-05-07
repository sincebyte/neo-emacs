
# Table of Contents

1.  [About](#org8d997d1)
2.  [How to install](#orgd8167ff)
    1.  [Install emacs](#org61539e5)
    2.  [Clone project](#org3eaf695)
    3.  [Doom Install](#org37bd251)
3.  [How to update](#org43bdcef)
    1.  [For brew](#orga381644)
    2.  [For doom project](#orge00d5af)
4.  [Patches](#org72b286e)
    1.  [transparent patch](#org1bd8a4e)
    2.  [cursor animation](#orgc390afb)
    3.  [how to](#org8ccec92)
5.  [Private setting](#orgf59fc7c)
    1.  [Font setting](#org57bcbae)
    2.  [Basic setting](#org0f44e09)
6.  [Neoemacs modules](#org099f564)
    1.  [Lsp Java](#orge7e05f6)
    2.  [Aidermacs](#org72ce4f0)
    3.  [Vterm Shell](#orgdf2390b)
    4.  [Clutch Sql](#org25e13ba)
    5.  [Input method](#orga2a4d4b)
    6.  [Org mode](#org51581c7)
    7.  [Verb](#orge90bfc3)
    8.  [Iredis](#orgbcd501c)
    9.  [Bookmark](#org97652c2)
    10. [Elpa Offline](#org13c1d2a)
    11. [Vue](#org584213a)
    12. [startup workspace](#org73e5ae5)
7.  [About the Release](#org5ac449c)
8.  [Customize Farther](#org60f8f7f)

![img](https://img.shields.io/badge/neo_emacs-v3.1-green.svg)  ![img](https://img.shields.io/badge/based_on-doom_emacs-red.svg?color=3152A0)  ![img](https://img.shields.io/badge/macos-full_supported-red.svg?logo=macos&color=55C2E1) ![img](https://img.shields.io/badge/windows-almost_supported-red.svg?logo=windows&color=3498DB)  
![img](https://img.shields.io/badge/eclipse-jdt_1.27.1-red.svg?logo=eclipse&color=2C2255) ![img](https://img.shields.io/badge/supports-Emacs_27.1_to_31.0-red.svg?logo=gnuemacs&color=7F5AB6)  

![img](./images/image-use.png)  


<a id="org8d997d1"></a>

# About

Neo emacs is a configuration framework for GNU Emacs which is based on doom emacs and focuses on the java web application coding environment. Neo emacs has the following features:  

-   Code completion: Lsp-java supports maven and gradle project.
-   Agent-shell: A native Emacs shell to interact with LLM agents powered by ACP
-   Http client: verb a package for Emacs which allows you to organize and send HTTP requests.
-   SQL client: clutch — Interactive Database Client for Emacs.
-   Redis client: [IRedis](https://github.com/laixintao/iredis) is a terminal client for redis with auto-completion and syntax highlighting.
-   Terminal emulator: Emacs-libvterm (vterm) is fully-fledged terminal emulator inside GNU Emacs based on libvterm.
-   Knowledge management system: Org-roam borrows principles from the Zettelkasten method, providing a solution for non-hierarchical note-taking.


<a id="orgd8167ff"></a>

# How to install


<a id="org61539e5"></a>

## Install emacs

> Most of the time, for safety you should install emacs by brew or complie it from source ,that will give you a better compatibility.  
> In other words, try not to install emacs throuht Free installation package like Gnu Emacs below.  

There have many emacs distribution,just choose one and install it.  

-   [EmacsPorts](https://github.com/railwaycat/homebrew-emacsmacport) is the best choice to run NeoEmcas on macos now.  
    
        brew tap railwaycat/emacsmacport
        brew install emacs-mac --with-natural-title-bar --with-mac-metal \
        --with-librsvg --with-starter --with-emacs-big-sur-icon --with-native-comp \
        defaults write org.gnu.Emacs TransparentTitleBar DARK \
        defaults write org.gnu.Emacs HideDocumentIcon kES
-   [Emacs-plus](https://github.com/d12frosted/homebrew-emacs-plus) which I used for a long time once.  
    
        brew tap d12frosted/emacs-plus
        brew install emacs-mac --with-natural-title-bar \
        --with-mac-metal --with-librsvg --with-starter \
        --with-emacs-big-sur-icon --
-   [Gnu-Emacs](https://www.gnu.org/software/emacs/) is the official emacs client which I used for windows platform.
-   [Source Code](https://git.savannah.gnu.org/cgit/emacs.git) Building form source which I use rarely.  
    building emacs with with source code  
    
        1    git clone git://git.savannah.gnu.org/emacs.git
        2    cd emacs
        3    git checkout emacs-28
        4    brew install libxml2
        5    make configure
        6    ./configure --with-native-compilation --with-modern-papirus-icon --with-no-titlebar
        7    make -j4
        8    make install
        9    open nextstep/Emacs.app

After emacs installation, set environment variables which names EMACS ,this depends on your emacs exec path.  

    export EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs


<a id="org3eaf695"></a>

## Clone project

clone doom-emacs and neo-emacs from github.  

    git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs
    git clone --depth 1 https://github.com/vanniuner/neo-emacs.git ~/.doom.d/


<a id="org37bd251"></a>

## Doom Install

Set up a vpn if you need it.  

    export http_proxy="ip:port"
    export https_proxy="ip:port"

Set your emacs cmd for doom install.  

    export EMACS= $YOUR EMACS CMD PATH$

Make sure there have Cmake lib or install it.  

-   Ubuntu  
    
        sudo apt install cmake
        sudo apt install libtool-bin
-   MacOs  
    
        brew install cmake libtool gnuplot d2 ripgrep fzf terrastruct/tap/tala graphviz vips

At last run below, this will take few minutes. And it depends on the quality of your network.  

    ~/.emacs.doom/bin/doom install
    ~/.emacs.doom/bin/doom.cmd install


<a id="org43bdcef"></a>

# How to update


<a id="orga381644"></a>

## For brew

    brew upgrade
    brew update && brew upgrade emacs-mac && brew cleanup emacs-mac


<a id="orge00d5af"></a>

## For doom project

    export EMACS=/Applications/Emacs.app/Contents/MacOS/EMACS
    sh ~/.emacs.d/bin/doom upgrade
    sh ~/.emacs.d/bin/doom install
    sh ~/.emacs.d/bin/doom sync


<a id="org72b286e"></a>

# Patches


<a id="org1bd8a4e"></a>

## transparent patch

It offer a window transparent solution which could transparent background but the font not.Note after install the patch, here have a alternative package to control the transparent value.  

    (use-package transwin
      :config
      (setq transwin-delta-alpha 5)
      (setq transwin-parameter-alpha 'alpha-background)
      :bind
      ("C-M-=" . transwin-inc)
      ("C-M--" . transwin-dec)
      ("C-M-0" . transwin-toggle))


<a id="orgc390afb"></a>

## cursor animation

The awesome patch could make cursor more funny.But there have a bug,If you shift to full screen from a window state , there will remain a shadow of the current cursor which will stay here forever.I will make cursor in replace mode before shifting to full screen.This might makes it effect less more.  


<a id="org8ccec92"></a>

## how to

Here have a [tutorial](https://neoemacs.com/posts/emacs-patches/) to apply patch if you are using emacs plus.  

1.  Put the patches file under to \`/opt/homebrew/Library/Taps/d12frosted/homebrew-emacs-plus/patches/emacs-30\`
2.  Modify \`/opt/homebrew/Library/Taps/d12frosted/homebrew-emacs-plus/Formula/emacs-plus@30.rb\`, around <span class="underline">local\_patch</span>.  
    There only have two terms to be filled in, one is patch name which referenced to the pathches directory, another is the pathchs \`sha256\` value.  
    
        #
        # Patches
        #
        opoo "The option --with-no-frame-refocus is not required anymore in emacs-plus@30." if build.with? "no-frame-refocus"
        local_patch "fix-window-role", sha: "1f8423ea7e6e66c9ac6dd8e37b119972daa1264de00172a24a79a710efcb8130"
        local_patch "system-appearance", sha: "9eb3ce80640025bff96ebaeb5893430116368d6349f4eb0cb4ef8b3d58477db6"
        local_patch "poll", sha: "31b76d6a2830fa3b6d453e3bbf5ec7259b5babf1d977b2bf88a6624fa78cb3e6" if build.with? "poll"
        local_patch "round-undecorated-frame", sha: "7451f80f559840e54e6a052e55d1100778abc55f98f1d0c038a24e25773f2874"
        local_patch "cursor-animation", sha: "812a934bd45dd4ee3311c1bc6681605364193bbd14ec05b9b847f9488bf989e2"
        local_patch "ns-alpha-background", sha: "6c174aff2602b64255ce8952f91302ede51e213be090f1b39e06913bbe0b086b"
    
    > Notic: above sha value is out of date
3.  Just install emacs plus, you could use \`brew reinstall\`


<a id="orgf59fc7c"></a>

# Private setting

Customize your private setting config in the config.el ; use `setq`  


<a id="org57bcbae"></a>

## Font setting

Before start up,install fonts in the <./neoemacs/font> directory firstly.  
Cause different platform have different font name,after font installed there need a adjustment based on the fact.  

1.  setting on macos

        (setq doom-font (font-spec :family "victor Mono" :size 19 ))
        (defun init-cjk-fonts()
          (dolist (charset '(kana han cjk-misc bopomofo))
            (set-fontset-font (frame-parameter nil 'font)
              charset (font-spec :family "HYXinRenWenSongW" :size 20))))
        (add-hook 'doom-init-ui-hook 'init-cjk-fonts)

2.  setting on windows

        (setq doom-font (font-spec :family "victor Mono Medium" :size 24))
        (defun init-cjk-fonts()
          (dolist (charset '(kana han cjk-misc bopomofo))
            (set-fontset-font (frame-parameter nil 'font)
              charset (font-spec :family "汉仪新人文宋W" :size 26))))
        (add-hook 'doom-init-ui-hook 'init-cjk-fonts)

3.  install all-the-icons

    For the icons font, we need do below  
    
    -   M-x install-package all-the-icons
    -   M-x all-the-icons-install-fonts
    -   M-x nerd-icons-install-fonts

4.  font sepcify by mode

    Use different font is a funny thing.The main idea to change font family is use `after-change-major-mode-hook`,unfortunately the implement do not fit doom big font.  
    
        (defun my-set-font-for-mode ()
          (cond
           ((derived-mode-p 'dired-mode)
            (setq-local face-remapping-alist '((default (:family "M PLUS Code Latin 50" :height 180) default))))
           ((derived-mode-p 'vterm-mode)
            (setq-local face-remapping-alist '((default (:family "Kode Mono" :height 160) default))))
           ))
        (add-hook 'after-change-major-mode-hook #'my-set-font-for-mode)
        
        (defun my-set-font-for-minibuffer ()
          (setq-local face-remapping-alist '((default (:family "M PLUS Code Latin 50" :height 170) default)))
          (redraw-frame (selected-frame)))
        (add-hook 'minibuffer-setup-hook #'my-set-font-for-minibuffer)

5.  require fonts

    Cause we are using multiple fonts ,here they are.  
    
    <table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">
    
    
    <colgroup>
    <col  class="org-left" />
    
    <col  class="org-left" />
    </colgroup>
    <tbody>
    <tr>
    <td class="org-left">FONT NAME</td>
    <td class="org-left">USED</td>
    </tr>
    
    <tr>
    <td class="org-left">M PLUS Code Latin 50</td>
    <td class="org-left">dired mode</td>
    </tr>
    
    <tr>
    <td class="org-left">Kode Mono</td>
    <td class="org-left">vterm mode</td>
    </tr>
    
    <tr>
    <td class="org-left">JetBrains Mono</td>
    <td class="org-left">lsp mode</td>
    </tr>
    
    <tr>
    <td class="org-left">IBM Plex Mono</td>
    <td class="org-left">mode line which key</td>
    </tr>
    </tbody>
    </table>


<a id="org0f44e09"></a>

## Basic setting

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">
<caption class="t-bottom"><span class="table-number">Table 1:</span> neo-emacs basic setting</caption>

<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<tbody>
<tr>
<td class="org-left">variable</td>
<td class="org-left">default value</td>
<td class="org-left">config location</td>
<td class="org-left">description</td>
</tr>

<tr>
<td class="org-left">emacs-module-root</td>
<td class="org-left">/opt/homebrew/opt/emacs-plus@28/include</td>
<td class="org-left">config.el</td>
<td class="org-left">emcas module root</td>
</tr>

<tr>
<td class="org-left">display-line-numbers-type</td>
<td class="org-left">nil</td>
<td class="org-left">config.el</td>
<td class="org-left">show line number</td>
</tr>

<tr>
<td class="org-left">org-directory</td>
<td class="org-left">~/org/</td>
<td class="org-left">config.el</td>
<td class="org-left">org           root path</td>
</tr>

<tr>
<td class="org-left">rg-exec-path</td>
<td class="org-left">system path</td>
<td class="org-left">-</td>
<td class="org-left">-</td>
</tr>

<tr>
<td class="org-left">fd-exec-path</td>
<td class="org-left">system path</td>
<td class="org-left">-</td>
<td class="org-left">-</td>
</tr>

<tr>
<td class="org-left">dot-exec-path</td>
<td class="org-left">/opt/homebrew/bin/dot</td>
<td class="org-left">modules/neo-emacs/org/config.el</td>
<td class="org-left">dot           exec path</td>
</tr>

<tr>
<td class="org-left">pdflatex-exec-path</td>
<td class="org-left">/Library/TeX/texbin/pdflatex</td>
<td class="org-left">modules/neo-emacs/org/config.el</td>
<td class="org-left">pdflatex      exec path</td>
</tr>

<tr>
<td class="org-left">org-roam-directory</td>
<td class="org-left">~/org/org-roam</td>
<td class="org-left">modules/neo-emacs/org/config.el</td>
<td class="org-left">org roam      root path</td>
</tr>

<tr>
<td class="org-left">lsp-java-jdt-download-url</td>
<td class="org-left"><a href="http://1.117.167.195/download">http://1.117.167.195/download</a></td>
<td class="org-left">modules/neo-emacs/java/config.el</td>
<td class="org-left">jdt-server URL</td>
</tr>

<tr>
<td class="org-left">lsp-java-java-path</td>
<td class="org-left">&nbsp;</td>
<td class="org-left">modules/neo-emacs/java/config.el</td>
<td class="org-left">java11        exec path</td>
</tr>

<tr>
<td class="org-left">lsp-maven-path</td>
<td class="org-left">~/.m2/settings.xml</td>
<td class="org-left">modules/neo-emacs/java/config.el</td>
<td class="org-left">maven setting path</td>
</tr>

<tr>
<td class="org-left">rime-user-data-dir</td>
<td class="org-left">~/Library/Rime/</td>
<td class="org-left">modules/neo-emacs/rime/config.el</td>
<td class="org-left">rime config input</td>
</tr>

<tr>
<td class="org-left">rime-librime-root</td>
<td class="org-left">~/.doom.d/myconfig/rime-macos/dist</td>
<td class="org-left">modules/neo-emacs/rime/config.el</td>
<td class="org-left">emacs-rime/blob/master/</td>
</tr>
</tbody>
</table>

> recentfile save default dir: ~/.emacs.d/.local/cache/recentf  


<a id="org099f564"></a>

# Neoemacs modules


<a id="orge7e05f6"></a>

## Lsp Java

[futher more java readme](./modules/neo-emacs/java/readme.md)  
Neo-Emacs will automatically download the jdtls from \`lsp-java-jdt-download-url\`, and now it&rsquo;s located at [jdt-language-server-1.22.0](https://www.eclipse.org/downloads/download.php?file=/jdtls/milestones/1.22.0/jdt-language-server-1.22.0-202304131553.tar.gz).After that you could use all the features powered by eclipse.  

-   Generate eclipse files  
    Execute mvn command for generate eclipse .project & .classpath files on your project root path.  
    
        mvn eclipse:clean eclipse:eclipse
-   Support projectlombok plugin  
    There have a default lombok.jar in `doom-user-dir/neoemacs` which you could replace by yourself.  
    
        (setq  lombok-jar-path (expand-file-name (concat doom-user-dir "neoemacs/lombok.jar")
-   Shotcuts/Key binding  
    
    <table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">
    <caption class="t-bottom"><span class="table-number">Table 2:</span> java mode key binding</caption>
    
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
    <td class="org-left">SPC c i</td>
    <td class="org-left">find-implementations</td>
    <td class="org-left">find where sub class definition</td>
    </tr>
    
    <tr>
    <td class="org-left">SPC c I</td>
    <td class="org-left">lsp-java-open-super-implementation</td>
    <td class="org-left">find where sub class definition</td>
    </tr>
    
    <tr>
    <td class="org-left">SPC t e</td>
    <td class="org-left">lsp-treemacs-java-deps-list</td>
    <td class="org-left">find projects referenced libs</td>
    </tr>
    
    <tr>
    <td class="org-left">SPC c f</td>
    <td class="org-left">formart buffer/region</td>
    <td class="org-left">goto type definition</td>
    </tr>
    
    <tr>
    <td class="org-left">SPC c a</td>
    <td class="org-left">lsp-execute-code-action</td>
    <td class="org-left">code action</td>
    </tr>
    
    <tr>
    <td class="org-left">SPC c d</td>
    <td class="org-left">lsp-jump-definition</td>
    <td class="org-left">jump to where symbol definition</td>
    </tr>
    
    <tr>
    <td class="org-left">SPC c D</td>
    <td class="org-left">lsp-jump-reference</td>
    <td class="org-left">jump to where symbol referenced</td>
    </tr>
    
    <tr>
    <td class="org-left">SPC c o</td>
    <td class="org-left">lsp-java-organize-imports</td>
    <td class="org-left">import require package</td>
    </tr>
    
    <tr>
    <td class="org-left">SPC t s</td>
    <td class="org-left">lsp-workspace-restart</td>
    <td class="org-left">restart lsp server</td>
    </tr>
    </tbody>
    </table>
-   How to upgrade jdtls  
    1.  Customization your own eclipse jdtls project version by replace it&rsquo;s binary pacage.
    2.  Download the lastest jdt-language-server from <https://download.eclipse.org/jdtls/milestones>.
    3.  Replace file to ~/.emacs.d/.local/etc/lsp/eclipse.jdt.ls.


<a id="org72ce4f0"></a>

## Aidermacs

aidermacs a code editing assistant through llm.  
Start through &rsquo;space d&rsquo; and display using vterm.  
use aider-ce  

    alias aider="aider-ce"

config aider  

    model: deepseek/deepseek-chat
    auto-commits: false
    max-chat-history: 6
    read:
      - ~/CONVENTIONS.md
    aiderignore: .aiderignore
    auto-lint: false
    test: false
    pretty: true
    
    # for aider-ce
    check-update: false
    enable-context-compaction: true
    debug: false
    use-enhanced-map: true
    tui: false
    context-compaction-max-tokens: 64000
    agent-config:
      large_file_token_threshold: 12500
      skip_cli_confirmations: true

config mcp tool  

    {
      "mcpServers": {
        "context7": {
          "transport": "http",
          "url": "https://mcp.context7.com/mcp",
          "headers": {
            "CONTEXT7_API_KEY": "ctx7sk-d8ff275f-5c0a-4abf-b6e4-b9ef5ab53aac"
          }
        },
        "skytechdb-test-readonly": {
          "command": "uv",
          "args": [
            "run",
            "mysql_mcp_server"
          ],
          "env": {
            "MYSQL_HOST": "your host",
            "MYSQL_PORT": "3306",
            "MYSQL_USER": "mcp_readonly_user",
            "MYSQL_PASSWORD": "mcp_readonly_password",
            "MYSQL_DATABASE": "skytech"
          }
        },
        "kubernetes-zhongying": {
          "command": "npx",
          "args": [
            "-y",
            "mcp-server-kubernetes"
          ]
        }
      }
    }


<a id="orgdf2390b"></a>

## Vterm Shell

You&rsquo;d better install vterm in a terminal environment case there might have error incompatible architecture.  

<div class="notice-warning" id="org88b78c6">
<p>
Vterm is not available on windows.<br />
Thus windows user have to use eshell as a downgrade plan.<br />
</p>

</div>

1.  Install vterm

    You&rsquo;d better install vterm in a terminal environment case there might have error incompatible architecture.  
    If vterm complie failed in emacs, we could complie it manually.  
    
        cd .emacs.d/.local/straight/build/vterm/
        mkdir -p build
        # install cmake and libtool-bin
        brew install cmake libtool
        mkdir -p build
        cd build
        cmake ..
        make

2.  Fish shell optimize

    If you are using fish shell ,fortunately there have some optimize config prepared for you.  
    
    -   feature:  
        -   use fish shell on emacs vterm.
        -   use command \`ff\` %anyfile% on vterm will open %anyfile% in a new emacs buffer.It&rsquo;s very useful.  
            
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
    -   http proxy  
        In fact there have two different config ,first one for vterm and another for emacs inner plugins.  
        In vterm the http proxy be effected by \`~/.config/fish/config.fish\`,you could config it like this.  
        
            set -x http_proxy       http://vpn.local.com:10887
            set -x https_proxy      http://vpn.local.com:10887
            set -x no_proxy         ".aliyun.com,192.168.0.0/16,137.239.155.184"
        
        When you are using emacs lisp program such as restclient, you could config proxy like this.  
        The difference is wildcard  
        
            (defun convert-to-regex (str)
            (let* ((joined (replace-regexp-in-string "," "\\\\|" str))
                    (wrapped (concat "^\\(" joined "\\)")))
            wrapped))
            (setq url-proxy-services `(("http" ."vpn.local.com:10887")
                                    ("https" ."vpn.local.com:10887")
                                    ("no_proxy" . ,(convert-to-regex ".*aliyun.com,192.168.0.0/16,137.239.155.184"))))
    -   display command&rsquo;s time  
        
            funced fish_right_prompt -i
            function fish_right_prompt
                echo -n (date +"%H:%M:%S ")
            end
            funcsave fish_right_prompt

3.  Usage

    -   Being with eshell  
        Eshell have a most wanted feature was **quickrun-eshell** which have a fast reload function after shell is runinng,you just use `C-c C-c` to stop it and use **r** to return you shell script file.It&rsquo;s pretty convenient.
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


<a id="org25e13ba"></a>

## Clutch Sql

-   The privacy configuration  
    In here you could save any connections in your setting config.  
    But where should the setting located especially for our Emacs config project with a public github repository? There have a privacy path which is excluded in the public repository named **user-private-dir**, You could config your connection&rsquo;s account/password here for safely.  
    There default load a db-work module which having your privacy config .  
    
        (add-to-list 'load-path user-private-dir )
        (use-package! db-work                    )
-   Config your particular db connection  
    
         (setq clutch-connection-alist
               '(("test"  . (:backend mysql
                                   :host "127.0.0.1" :port 3306
                                   :user "root" :password "****"
                                   :database "test"
                                   :connect-timeout 5
                                   :read-idle-timeout 60))))
        (provide 'db-work)
-   Write Sql file  
    Before try to use clutch , firstly create a sql file which named with a suffix **.sql**, cause emacs will turn on the clutch-mode so that clutch could works well. And then use `SPC e c` to connect a particular database which you have configurated. Emacs will popup a minibuffer listing candidates which show you the **connection-name**.  
    Secondarily, write your testing sql content which surrounded by a tag, cause we have configurated **:separator** by a syntax meaning tag in order to execute a single sql rather than to choose it.For sure you could make any comment with the tag&rsquo;s schema.  
    Further more, you could use delimiter sign for batch execution. the delimiter could customization by any character.  
    Finnaly, use `C-c C-c` to execute it. It&rsquo;s just execute the content which surrounded by a tag in your cusor.  
    
        1     <SELECT name='select all org'>
        2     SELECT * FROM TABLE_ORG
        3     </SELECT>
        4     <SELECT>
        5     delimiter ;
        6     COMMENT ON COLUMN TABLE_ORG.PROJECT_CODE IS '项目编码';
        7     COMMENT ON COLUMN TABLE_ORG.PERIOD IS '期间';
        8     </SELECT>
-   key binding  
    
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
    <td class="org-left">description</td>
    </tr>
    
    <tr>
    <td class="org-left">SPC e c</td>
    <td class="org-left">clutch-connection</td>
    <td class="org-left">choose connection with ivy</td>
    </tr>
    
    <tr>
    <td class="org-left">C-c C-c</td>
    <td class="org-left">my-clutch-exec-xml-inner</td>
    <td class="org-left">execute the sql</td>
    </tr>
    
    <tr>
    <td class="org-left">?</td>
    <td class="org-left">clutch-dispatch</td>
    <td class="org-left">clutch menu</td>
    </tr>
    </tbody>
    </table>


<a id="orga2a4d4b"></a>

## Input method

[shift system input method on macos](https://neoemacs.com/posts/emacs_%E5%88%87%E6%8D%A2%E7%B3%BB%E7%BB%9F%E8%BE%93%E5%85%A5%E6%B3%95/)  


<a id="org51581c7"></a>

## Org mode

[futher more org readme](./modules/neo-emacs/org/readme.md)  

1.  Install Dependency

    There have some third party lib we need prepare.  
    
    1.  d2 diagram
    
        [d2 installation](https://github.com/terrastruct/d2/blob/master/docs/INSTALL.md)  
        
            alias ds2 "/opt/homebrew/bin//d2 --sketch --animate-interval=1400 -l elk -c --pad 0"
            alias d2 "/opt/homebrew/bin//d2 --pad 0 --layout tala "

2.  Image to base64

    No need to sent images files of the source.  
    The embedded base64 image make to distribute your html documentation more easily.  

3.  Optimize Line Number

    Just hidden the colon after line number character.  
    Modify \`~/.emacs.d/.local/straight/repos/org/lisp/ox-html.el\`.  
    
        1  (let* ((code-lines (split-string code "\n"))
        2     (code-length (length code-lines))
        3     (num-fmt
        4  	(and num-start
        5  	     (format "%%%ds "
        6  	     (format "%(add-hook 'code-review-mode-hook
        7          (lambda ()
        8            ;; include *Code-Review* buffer into current workspace
        9            (persp-add-buffer (current-buffer))))%%ds: "

4.  Image Directory

    Cause org mode html export program  need a image directory locate at org root directory.  
    Highly recommended:  
    Use `ln` making an mirror of the directory.  
    Make the image directory as your screenshot file&rsquo;s saving location.  
    
        ln -s ~/org/org-roam/image any_where/image


<a id="orge90bfc3"></a>

## Verb

Verb is a new package for http client,becase the restclient is out of date and the author no longger maintain it on github.Fortunately there have a alternative one named verb which is more powerful and customizable. Verb support url template which makes you change different environment more conveniently.Also verb supports variables and picture query and upload.In org mode start verb just use \`C-c C-r\` as a previous command,example \`C-c C-r C-f\` will execute http request with your config,So verb is really fancy right?  


<a id="orgbcd501c"></a>

## Iredis

1.  install

        brew install iredis

2.  config

    Here have a  [template](https://github.com/laixintao/iredis/blob/master/iredis/data/iredisrc) of iredis&rsquo; configuration.The essential point is <span class="underline">alias\_dsn</span>  
    
        1  [alias_dsn]
        2  example_dsn1 = redis://[[username]:[password]]@localhost:6379/0
        3  example_dsn2 = rediss://[[username]:[password]]@localhost:6379/0
        4  example_dsn3 = unix://[[username]:[password]]@/path/to/socket.sock?db=0

3.  usage

    Use command to connect redis database.The most convenient thing is you could index your content as iredis have integrated with jq command.  
    
        iredis -d wvp-test
        10.100.10.70:6379[7]> get VMP_MEDIA_SERVER:000000:zlm_fragment | jq .


<a id="org97652c2"></a>

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


<a id="org13c1d2a"></a>

## Elpa Offline

rsync -avz rsync://mirrors.tuna.tsinghua.edu.cn/elpa ~/soft/emacs-elpa  

    (setq configuration-layer--elpa-archives
          '(("melpa-cn" . "/soft/emacs-elpa/melpa/")
            ("org-cn"   . "/soft/emacs-elpa/org/")
            ("gnu-cn"   . "/soft/emacs-elpa/gnu/")
            ("marmalade-cn"   . "/soft/emacs-elpa//marmalade/")))


<a id="org584213a"></a>

## Vue

as a full stack developer u need vue support, so here it comes.  

    npm install vls -g


<a id="org73e5ae5"></a>

## startup workspace

You could customization startup inital workspace and their buffer.No need to open it every time.  

    (setq +workspaces-main " SSH")
    (defun open-my-workspaces ()
      (interactive)
      (+workspace/new " IDE")
      (find-file "yourexpect.java")
      (+workspace/new " SQL")
      (find-file "yourexpect.sql")
      (+workspace/new " HTTP")
      (find-file "yourexpect.http")
      (+workspace/new "󱗃 ORG")
      (find-file "yourexpect.org"))
    (add-hook 'window-setup-hook #'open-my-workspaces)


<a id="org5ac449c"></a>

# About the Release

This step can help you compile neo emacs faster,It only takes 3 minutes to install using the release package on my Mac laptop. Otherwise it would take me 15 minutes. The release installation package is a better choice for users with unstable networks and those who need to frequently reinstall neoemacs.  
Release package contains the git repository of related dependencies.The compiled directory files are removed and the .git directory is retained,So that you can perform subsequent upgrades.  
I will update the Release package once a month, And test them in advance and revise them for compatibility with upstream projects.  


<a id="org60f8f7f"></a>

# Customize Farther

For customize farther, there have some documentation you need read.  
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

