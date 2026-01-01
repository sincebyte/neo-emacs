
# Table of Contents

1.  [Use system input rime](#org4704963)
    1.  [evil hook](#orgb572ece)
    2.  [hammerspoon.config](#orgb42891c)
    3.  [install macism](#org60cedfb)
    4.  [rime keybinding config](#orgec8312e)
2.  [Install Librime](#orgd8f826d)
    1.  [how to get librime on mac?](#orge51e0ad)
    2.  [how to get librime on windows?](#orgb1f949e)
3.  [Rime Usage](#org83151ba)
    1.  [小鹤音形](#org8526e6c)
    2.  [Key-binding](#org18391f3)
    3.  [Q/A](#org72d63d8)



<a id="org4704963"></a>

# Use system input rime

Use system input method get a more unify experience, the control chain like  C-; -hammerspoon-> shift space -> switch rime ascii.  


<a id="orgb572ece"></a>

## evil hook

    (defun my/mac-switch-to-english ()
      "切换到系统英文输入法"
      (call-process "macism" nil 0 nil
                    "com.apple.keylayout.ABC"))
    
    (defun my/mac-switch-to-chinese ()
      "切换到系统中文输入法（Squirrel / Rime）"
      (call-process "macism" nil 0 nil
                    "im.rime.inputmethod.Squirrel.Hans"))
    
    (with-eval-after-load 'evil
      ;; 进入 insert → 中文
      (add-hook 'evil-insert-state-entry-hook
                #'my/mac-switch-to-chinese)
    
      ;; 退出 insert → 英文
      (add-hook 'evil-insert-state-exit-hook
                #'my/mac-switch-to-english))


<a id="orgb42891c"></a>

## hammerspoon.config

    hs.hotkey.bind({"ctrl"}, ";", function()
        local win = hs.window.frontmostWindow()
        if win then
            local appName = win:application():name()
            if appName == "Emacs" then
                hs.eventtap.keyStroke({"shift"}, "space")
                -- hs.eventtap.keyStroke({"ctrl"}, "z")
            else
                hs.eventtap.keyStroke({"ctrl"}, "z")
            end
        end
    end)


<a id="org60cedfb"></a>

## install macism

    brew tap laishulu/homebrew
    brew install macism


<a id="orgec8312e"></a>

## rime keybinding config

    # 快捷键
    key_binder:
      bindings:
        # Tab / Shift+Tab 切换光标至下/上一个拼音
        #- { when: composing, accept: Shift+Tab, send: Shift+Left }
        #- { when: composing, accept: Tab, send: Shift+Right }
        # Tab / Shift+Tab 翻页
        # - { when: has_menu, accept: Shift+Tab, send: Page_Up }
        # - { when: has_menu, accept: Tab, send: Page_Down }
        # Option/Alt + ←/→ 切换光标至下/上一个拼音
        - { when: composing, accept: ";", send: "2" }
        - { when: composing, accept: Alt+Left, send: Shift+Left }
        - { when: composing, accept: Alt+Right, send: Shift+Right }
        # emacs_editing:
        - { when: composing, accept: Control+p, send: Left }
        - { when: composing, accept: Control+n, send: Right }
        # 实现无论在 macos 系统中还是在 emacs 内部都可以使用 C-p 与 C-n 来实现选词。
        # macos 系统使用下面两行将 rime 加载好(系统只会加载rime配置一次)，然后再注释掉，emacs 使用上面的配置。
        - { when: composing, accept: Up, send: Left }
        - { when: composing, accept: Down, send: Right }
        # numbered_mode_switch:
        # - { when: always, select: .next, accept: Control+Shift+1 }                  # 在最近的两个方案之间切换
        # - { when: always, select: .next, accept: Control+Shift+exclam }             # 在最近的两个方案之间切换
        # - { when: always, toggle: ascii_mode, accept: Control+Shift+2 }             # 切换中英
        # - { when: always, toggle: ascii_mode, accept: Control+Shift+at }            # 切换中英
        # - { when: always, toggle: full_shape, accept: Control+Shift+5 }             # 切换全半角
        # - { when: always, toggle: full_shape, accept: Control+Shift+percent }       # 切换全半角
    
        # emacs_editing:
        # - { when: composing, accept: Control+p, send: Up }
        # - { when: composing, accept: Control+n, send: Down }
        # - { when: composing, accept: Control+b, send: Left }
        # - { when: composing, accept: Control+f, send: Right }
        # - { when: composing, accept: Control+a, send: Home }
        # - { when: composing, accept: Control+e, send: End }
        # - { when: composing, accept: Control+d, send: Delete }
        # - { when: composing, accept: Control+k, toggle: xxxxx } #释放Ctrl+k=ctrl+del 万象用来调序，且删除属于低频场景，建议双手操作
        # - { when: composing, accept: Control+h, send: BackSpace }
        # - { when: composing, accept: Control+g, send: Escape }
        # - { when: composing, accept: Control+bracketleft, send: Escape }
        # - { when: composing, accept: Control+y, send: Page_Up }
        # - { when: composing, accept: Alt+v, send: Page_Up }
        # - { when: composing, accept: Control+v, send: Page_Down }
    
        # optimized_mode_switch:
        # - { when: always, accept: Control+Shift+space, select: .next }
        - { when: always, accept: Shift+space, toggle: ascii_mode }


<a id="orgd8f826d"></a>

# Install Librime


<a id="orge51e0ad"></a>

## how to get librime on mac?

-   from offical: <https://github.com/rime/librime>
-   from elpa: M-x install-package rime

unzip rime-1.5.3-osx.zip -d ~/.emacs.d/librime  


<a id="orgb1f949e"></a>

## how to get librime on windows?

on window we need <https://scoop.sh/>.After that [install librime](https://github.com/DogLooksGood/emacs-rime/blob/master/INSTALLATION.org)  


<a id="org83151ba"></a>

# Rime Usage

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


<a id="org8526e6c"></a>

## 小鹤音形

[小鹤音形](https://www.flypy.com/) was a wonderful input method, with it we could touch typing totally. The config file located here [flypy-rime-config](https://github.com/vanniuner/neo-emacs/tree/master/neoemacs/rime-config) provided two input method configuration. You need unzip them to `rime-user-data-dir` , and config the priority for candidate by `flypy_top.txt` .  


<a id="org18391f3"></a>

## Key-binding

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
<td class="org-left">C-;</td>
<td class="org-left">toggle-input-method</td>
</tr>

<tr>
<td class="org-left">&#xa0;</td>
<td class="org-left">rime-sync</td>
</tr>

<tr>
<td class="org-left">&#xa0;</td>
<td class="org-left">rime-deploy</td>
</tr>
</tbody>
</table>


<a id="org72d63d8"></a>

## Q/A

-   <https://github.com/DogLooksGood/emacs-rime> supply this plugin.
-   <https://github.com/rime/plum> for more infomation.
-   &rsquo;emacs-module.h&rsquo; file not found  
    
        lib.c:23:10: fatal error: 'emacs-module.h' file not found
          #include <emacs-module.h>
                  ^~~~~~~~~~~~~~~~
    
        cp /opt/homebrew/opt/emacs-plus@29/include/emacs-module.h ~/.doom.d/neoemacs/rime-macos/dist/include

