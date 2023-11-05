
# Table of Contents

1.  [Install Librime](#org65ed836)
    1.  [how to get librime on mac?](#orgf6bd8d0)
    2.  [how to get librime on windows?](#org5c56337)
2.  [Rime Usage](#org426cc02)
    1.  [小鹤音形](#org65c118a)
    2.  [Key-binding](#org33acbfd)
    3.  [Q/A](#org2612948)



<a id="org65ed836"></a>

# Install Librime


<a id="orgf6bd8d0"></a>

## how to get librime on mac?

-   M-x install-package rime

unzip rime-1.5.3-osx.zip -d ~/.emacs.d/librime  


<a id="org5c56337"></a>

## how to get librime on windows?

on window we need <https://scoop.sh/>.After that [install librime](https://github.com/DogLooksGood/emacs-rime/blob/master/INSTALLATION.org)  


<a id="org426cc02"></a>

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


<a id="org65c118a"></a>

## 小鹤音形

[小鹤音形](https://www.flypy.com/) was a wonderful input method, with it we could touch typing totally. The config file located here [flypy-rime-config](https://github.com/vanniuner/neo-emacs/tree/master/neoemacs/rime-config) provided two input method configuration. You need unzip them to `rime-user-data-dir` , and config the priority for candidate by `flypy_top.txt` .  


<a id="org33acbfd"></a>

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


<a id="org2612948"></a>

## Q/A

-   <https://github.com/DogLooksGood/emacs-rime> supply this plugin.
-   <https://github.com/rime/plum> for more infomation.
-   &rsquo;emacs-module.h&rsquo; file not found  
    
        lib.c:23:10: fatal error: 'emacs-module.h' file not found
          #include <emacs-module.h>
                  ^~~~~~~~~~~~~~~~
    
        cp /opt/homebrew/opt/emacs-plus@29/include/emacs-module.h ~/.doom.d/neoemacs/rime-macos/dist/include

