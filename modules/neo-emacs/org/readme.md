
# Table of Contents

1.  [Org mode Usage](#org8c6e03b)
    1.  [Basic usage](#org6da05d6)
    2.  [Org template](#org439d123)
    3.  [Org transclusion](#org9ca0d9c)
    4.  [Org remark](#orgcfe6d2e)
    5.  [Org appear](#org4195079)
    6.  [Org to Html](#org8e512d1)
    7.  [Latex PDF setting](#org588a6f3)
    8.  [Optimize Line Number](#org0b96f45)
    9.  [Org Roam UI](#org2b3f5b2)
    10. [Image Directory](#org777af20)



<a id="org8c6e03b"></a>

# Org mode Usage


<a id="org6da05d6"></a>

## Basic usage

Most of the basic useage reference to [doom-org-style](https://github.com/vanniuner/doom-org-style)  


<a id="org439d123"></a>

## Org template

For classify noter better,we need a method to make different kinds of org note into an associated directory.  
Firstly,define your classify and their directory and a key of select the particular classification.  
The select interface will popup when you use `SPC n r i` to create a new note, of course your chooise determined it&rsquo;s classification.  
In here,I use org-head.setup for default html export setting. the template ultimate effect like this.  

    :PROPERTIES:
    :ID:       22f46285-bbe0-4916-9df4-380688b2793b
    :END:
    #+title: test-org
    #+subtitle:
    #+author: vanniuner
    #+SETUPFILE: ~/.doom.d/org-head.setup

    (setq org-roam-capture-templates
    '(("d" "default" plain "%?"
            :if-new  (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "#+title: ${title}\n#+subtitle: \n#+author: vanniuner\n#+SETUPFILE: ~/.doom.d/org-head.setup")
            :unnarrowed t)
      ("j" "java" plain "%?"
            :if-new (file+head "java/%<%Y%m%d%H%M%S>-${slug}.org" "#+title: ${title}\n#+subtitle: \n#+author: vanniuner\n#+SETUPFILE: ~/.doom.d/org-head.setup")
            :unnarrowed t)
      ("e" "emacs" plain "%?"
            :target (file+head "emacs/%<%Y%m%d%H%M%S>-${slug}.org" "#+title: ${title}\n#+subtitle: \n#+author: vanniuner\n#+SETUPFILE: ~/.doom.d/org-head.setup")
            :unnarrowed t)
      ("p" "speech" plain "%?"
            :target (file+head "speech/%<%Y%m%d%H%M%S>-${slug}.org" "#+title: ${title}\n#+subtitle: \n#+author: vanniuner\n#+SETUPFILE: ~/.doom.d/org-head.setup")
            :unnarrowed t)
    ))


<a id="org9ca0d9c"></a>

## Org transclusion

[org-transclusion](https://github.com/nobiot/org-transclusion) lets you insert a copy of text content via a file link or ID link within an Org file, The usage case here below.  
There have a little conflict with org appear,[The incompatible with org appear](https://github.com/nobiot/org-transclusion/issues/194) we are waiting for the author&rsquo;s repsonse.  

    #+transclude: [[anyfile][shortname]] :level 2 :lines 1-2 :src java

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
<td class="org-left">SPC n t</td>
<td class="org-left">open transclusion</td>
</tr>


<tr>
<td class="org-left">SPC n g</td>
<td class="org-left">open transclusion refresh</td>
</tr>


<tr>
<td class="org-left">SPC n O</td>
<td class="org-left">open transclusion source file</td>
</tr>
</tbody>
</table>


<a id="orgcfe6d2e"></a>

## Org remark

[org-remark](https://github.com/nobiot/org-remark) lets you highlight and annotate text files and websites with using Org mode.  
You could customize faces of the note.  

    (custom-set-faces `(org-remark-highlighter ((t (:underline (:color "#1B4F72" :style line) :background "#57a6db")))))

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<tbody>
<tr>
<td class="org-left">key</td>
<td class="org-left">binding</td>
<td class="org-left">describe</td>
</tr>


<tr>
<td class="org-left">SPC r m</td>
<td class="org-left">org-remark-mark</td>
<td class="org-left">make a note</td>
</tr>


<tr>
<td class="org-left">SPC r o</td>
<td class="org-left">org-remark-open</td>
<td class="org-left">open a note and cursor location at the note butter</td>
</tr>


<tr>
<td class="org-left">SPC r n</td>
<td class="org-left">org-remark-view-next</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">SPC r p</td>
<td class="org-left">org-remark-view-prev</td>
<td class="org-left">&#xa0;</td>
</tr>
</tbody>
</table>


<a id="org4195079"></a>

## HOLD Org appear

[org-appear](https://github.com/awth13/org-appear) make invisible parts of Org elements appear visible.  
No key-binding here,because it automatic trigger when your cursor on it.  

    [[https://github.com/nobiot/org-transclusion][org-transclusion]] lets
    org-transclusion lets
    # org-transclusion -> [[https://github.com/nobiot/org-transclusion][org-transclusion]]


<a id="org8e512d1"></a>

## Org to Html

1.  Image to base64

    No need to sent images files of the source.  
    The embedded base64 image make to distribute your html documentation more easily.  

2.  dotgraphviz of hand painted style

    Use dotgraphviz of hand painted style you need make sure the step here below.  
    
        cd ~/.doom.d/neoemacs/sketchviz/sketch.js
        npm install --save roughjs
        npm i jsdom
    
        #+BEGIN_SRC dotsk :file dotsk-demo.svg
            digraph G {
                bgcolor="transparent"
                rankdir = LR
                a -> b [minlen=2,label="ϟ"]
            }
    
        digraph G {
            bgcolor="transparent"
            rankdir = LR
            a -> b [minlen=2,label="ϟ"]
        }


<a id="org588a6f3"></a>

## Latex PDF setting

1.  install [mactex](https://tug.org/mactex/)
2.  put [elegantpaper.cls](https://github.com/ElegantLaTeX/ElegantPaper/blob/master/elegantpaper.cls) under the org file dir
3.  add the code in the head of your org mode file  
    
        #+LATEX_COMPILER: xelatex
        #+LATEX_CLASS: elegantpaper
        #+OPTIONS: prop:t
4.  [more info](https://www.sheerwill.live/posts/main/20220723211325-vanilla_emacs_with_purcell/)


<a id="org0b96f45"></a>

## Optimize Line Number

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


<a id="org2b3f5b2"></a>

## Org Roam UI

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<tbody>
<tr>
<td class="org-left">org-roam-ui-open</td>
<td class="org-left">open an org roam on web</td>
</tr>
</tbody>
</table>


<a id="org777af20"></a>

## Image Directory

Cause org mode html export program  need a image directory locate at org root directory.  
Highly recommended:  
Use `ln` making an mirror of the directory.  
Make the image directory as your screenshot file&rsquo;s saving location.  

    ln -s ~/org/org-roam/image any_where/image

