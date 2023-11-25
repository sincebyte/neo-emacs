
# Table of Contents

1.  [About](#org92b698a)
2.  [How to install](#org00b923d)
3.  [How to update](#orgbef50bc)
4.  [Private setting](#org94c4f3e)
5.  [Neoemacs modules](#org290540b)
6.  [Customize Farther](#orgbb62ced)

![img](https://img.shields.io/badge/neo_emacs-v3.0-green.svg)  ![img](https://img.shields.io/badge/based_on-doom_emacs-red.svg?color=3152A0)  ![img](https://img.shields.io/badge/macos-full_supported-red.svg?logo=macos&color=55C2E1) ![img](https://img.shields.io/badge/windows-almost_supported-red.svg?logo=windows&color=3498DB)  
![img](https://img.shields.io/badge/eclipse-jdt_1.27.1-red.svg?logo=eclipse&color=2C2255) ![img](https://img.shields.io/badge/supports-Emacs_27.1_to_29.1-red.svg?logo=gnuemacs&color=7F5AB6)  

![img](./image-use.png)  


<a id="org92b698a"></a>

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


<a id="org00b923d"></a>

# How to install

1.  Install emacs

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

2.  Clone project

    clone doom-emacs and neo-emacs from github.  
    
        git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.emacs.d
        git clone --depth 1 https://github.com/vanniuner/neo-emacs.git ~/.doom.d/

3.  Doom Install

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
        
            brew install cmake libtool gnuplot d2 ripgrep fzf terrastruct/tap/tala graphviz
    
    At last run below, this will take few minutes. And it depends on the quality of your network.  
    
        ~/.emacs.doom/bin/doom install
        ~/.emacs.doom/bin/doom.cmd install


<a id="orgbef50bc"></a>

# How to update

1.  For brew

        brew upgrade
        brew update && brew upgrade emacs-mac && brew cleanup emacs-mac

2.  For doom project

        export EMACS=/Applications/Emacs.app/Contents/MacOS/EMACS
        sh ~/.emacs.d/bin/doom upgrade
        sh ~/.emacs.d/bin/doom install
        sh ~/.emacs.d/bin/doom sync


<a id="org94c4f3e"></a>

# Private setting

Customize your private setting config in the config.el ; use `setq`  

1.  Font setting

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

2.  Basic setting

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
    <td class="org-left">&#xa0;</td>
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


<a id="org290540b"></a>

# Neoemacs modules

1.  Lsp Java

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

2.  Vterm Shell

    <div class="notice-warning" id="org6693561">
    <p>
    Vterm is not available on windows.<br />
    Thus windows user have to use eshell as a downgrade plan.<br />
    </p>
    
    </div>
    
    1.  Install vterm
    
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

3.  Ejc Sql

    -   The privacy configuration  
        In here you could save any connections in your setting config.  
        But where should the setting located especially for our Emacs config project with a public github repository? There have a privacy path which is excluded in the public repository named **user-private-dir**, You could config your connection&rsquo;s account/password here for safely.  
        There default load a db-work module which having your privacy config .  
        
            (add-to-list 'load-path user-private-dir )
            (use-package! db-work                    )
    -   Config your particular db connection  
        
            (use-package ejc-sql
            :commands ejc-sql-mode ejc-connect
            :config
            (setq clomacs-httpd-default-port 18090)
            (ejc-create-connection "connection-name"
                    :classpath      "~/.m2/repository/mysql/mysql-connector-java/8.0.17/
                        mysql-connector-java-8.0.17.jar"
                    :connection-uri "jdbc:mysql://localhost/user?useSSL=false&user=root&password=pwd"
                    :separator      "</?\.*>" )
            )
            (provide 'db-work)
    -   Write Sql file  
        Before try to use ejc sql, firstly create a sql file which named with a suffix **.sql**, cause emacs will turn on the sql minor mode so that ejc-sql could works well. And then use `SPC e c` to connect a particular database which you have configurated. Emacs will popup a minibuffer listing candidates which show you the **connection-name**.  
        Secondarily, write your testing sql content which surrounded by a tag, cause we have configurated **:separator** by a syntax meaning tag in order to execute a single sql rather than to choose it.For sure you could make any comment with the tag&rsquo;s schema.  
        Further more, you could use delimiter sign for batch execution. the delimiter could customization by any character.  
        Finnaly, use `C-c C-c` to execute it. It&rsquo;s just execute the content which surrounded by a tag in your cusor.  
        
            1     <SELECT name='select all org'>
            2     SELECT * FROM TABLE_ORG
            3     </SELECT>
            4  
            5     <SELECT>
            6     delimiter ;
            7     COMMENT ON COLUMN TABLE_ORG.PROJECT_CODE IS '项目编码';
            8     COMMENT ON COLUMN TABLE_ORG.PERIOD IS '期间';
            9     </SELECT>
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
        <td class="org-left">ejc-connection</td>
        <td class="org-left">choose connection with ivy</td>
        </tr>
        
        
        <tr>
        <td class="org-left">C-c C-c</td>
        <td class="org-left">ejc-execute</td>
        <td class="org-left">execute the sql</td>
        </tr>
        </tbody>
        </table>

4.  Emacs Rime

    [Emacs Rime](https://github.com/DogLooksGood/emacs-rime) which makes to embedding an input method be possible whthin the emacs.Emacs could benefit form the flexible configuration of [rime](https://rime.im/).  
    On macos it&rsquo;s required to install **Squirrel** which is one of rime&rsquo;s distribution. **Squirrel** is installed in your os system as a input method.  
    Note that the configuration of rime located at home/Library/Rime/. We want to sharing this configuration between Eamcs rime and os rime.  
    So there have a variable which named `rime-user-data-dir` , And another important variable is `rime-librime-root` which configed the librime location.  
    
    <table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">
    
    
    <colgroup>
    <col  class="org-left" />
    
    <col  class="org-left" />
    </colgroup>
    <tbody>
    <tr>
    <td class="org-left">variable</td>
    <td class="org-left">required</td>
    </tr>
    
    
    <tr>
    <td class="org-left">rime-user-data-dir</td>
    <td class="org-left">true</td>
    </tr>
    
    
    <tr>
    <td class="org-left">rime-librime-root</td>
    <td class="org-left">true</td>
    </tr>
    </tbody>
    </table>
    
    [futher more rime readme](./modules/neo-emacs/rime/readme.md)  

5.  Org mode

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

6.  Restclient

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

7.  Eredis Usage

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

8.  Bookmark

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

9.  Elpa Offline

    rsync -avz rsync://mirrors.tuna.tsinghua.edu.cn/elpa ~/soft/emacs-elpa  
    
        (setq configuration-layer--elpa-archives
              '(("melpa-cn" . "/soft/emacs-elpa/melpa/")
                ("org-cn"   . "/soft/emacs-elpa/org/")
                ("gnu-cn"   . "/soft/emacs-elpa/gnu/")
                ("marmalade-cn"   . "/soft/emacs-elpa//marmalade/")))

10. Vue

    as a full stack developer u need vue support, so here it comes.  
    
        npm install vls -g


<a id="orgbb62ced"></a>

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

