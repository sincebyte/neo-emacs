
# Table of Contents

1.  [Install](#org6930706)
2.  [magit messy code (乱码)](#org194f9d0)


<a id="org6930706"></a>

# Install

<https://dandavison.github.io/delta/installation.html>

    brew install git-delta


<a id="org194f9d0"></a>

# magit messy code (乱码)

The octal escape &ldquo;\\346\\226\\207\\346\\241\\243.org&rdquo; indicates that Git/Magit did not display the file name as UTF-8 normally, but instead fallback it to a escaped string.
This is a classic problem of garbled Chinese characters in Emacs Magit. It can basically be determined that the output encoding of Git is inconsistent with the decoding of Emacs.

Disable Git&rsquo;s escape of non-ASCII file names

    git config --global core.quotepath false

