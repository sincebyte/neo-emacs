
# Table of Contents

1.  [Eglot for Java](#org9add88d)
    1.  [What&rsquo;s Eglot?](#org1ee32f0)
    2.  [Eglot workflow](#org0215388)
    3.  [Install jdtls](#org9718ac4)
    4.  [Jumping into third-party / JDK source](#org8cedfbf)
    5.  [Completion with Corfu](#orgcd6c72c)



<a id="org9add88d"></a>

# Eglot for Java

This note covers how neo-emacs runs Java under Eglot: picking jdtls, installing it, and making go-to-definition work for JDK / Maven classes that only exist as `.class` files.  


<a id="org1ee32f0"></a>

## What&rsquo;s Eglot?

Eglot is Emacs&rsquo; built-in LSP client. It does not embed language intelligence itself; it starts an external language server, speaks JSON-RPC with it, and maps the replies onto Emacs commands (`xref`, diagnostics, code actions, completion, and so on).  

For Java that server is almost always [Eclipse JDT Language Server](https://github.com/eclipse/eclipse.jdt.ls) (the `jdtls` launcher). Eglot only needs a command on `PATH` and an entry in `eglot-server-programs`.  


<a id="org0215388"></a>

## Eglot workflow

`eglot-server-programs` maps major modes to server launch commands. For Java:  

    ((java-mode java-ts-mode)
     . ,(eglot-alternatives '("jdtls" "java-language-server")))

`eglot-alternatives` tries each command in order; the first executable that exists wins. In practice that means `jdtls`.  

Opening a Java buffer then looks like this:  

    open Java file
          │
          ▼
    java-mode / java-ts-mode
          │
          ▼
    eglot-ensure
          │
          ▼
    look up eglot-server-programs
          │
          ▼
    resolve jdtls
          │
          ▼
    start jdtls process
          │
          ▼
    LSP initialize / connect

If `jdtls` is missing from `PATH`, Eglot has nothing to start. Fix the install before debugging Emacs config.  


<a id="org9718ac4"></a>

## Install jdtls

There are many ways to get jdtls (package managers, `lsp-java`&rsquo;s downloader, etc.). I prefer the [official distribution](https://download.eclipse.org/jdtls/) so the version is explicit.  

1.  Download and unpack the archive somewhere stable, e.g. `/Users/van/lsp-java`.
2.  Put its `bin` directory on `PATH`. In fish:

    set PATH /Users/van/lsp-java/bin $PATH

The `jdtls` entry point is a small Python script that eventually launches the OSGi-based language server JAR under a JVM. Two things usually need editing on a real machine:  

-   **JAVA\_HOME for the server itself.** jdtls wants a recent JDK. Point the launcher at one you control.
-   **Lombok.** Most Spring / enterprise codebases use it; without `-javaagent` on the server JVM, generated accessors never show up in completion or navigation.

A minimal wrapper around the stock launcher:  

    #!/usr/bin/env python3
    import importlib.util
    import sys
    import os
    
    os.environ["JAVA_HOME"] = "/Users/van/soft/jdk/jdk-25.0.2.jdk/Contents/Home"
    os.environ["PATH"] = os.path.join(os.environ["JAVA_HOME"], "bin") + ":" + os.environ["PATH"]
    
    script_dir = os.path.dirname(os.path.realpath(__file__))
    file_path = os.path.join(script_dir, "jdtls.py")
    
    spec = importlib.util.spec_from_file_location("jdtls", file_path)
    jdtls = importlib.util.module_from_spec(spec)
    sys.modules["jdtls"] = jdtls
    spec.loader.exec_module(jdtls)
    
    jdtls.main(sys.argv[1:])

Inside `jdtls.py`, the JVM argument list is where Lombok belongs:  

    exec_args = ["-Declipse.application=org.eclipse.jdt.ls.core.id1",
                 "-Dosgi.bundles.defaultStartLevel=4",
                 "-Declipse.product=org.eclipse.jdt.ls.core.product",
                 "-Dosgi.checkConfiguration=true",
                 "-Dosgi.sharedConfiguration.area=" + shared_config_path,
                 "-Dosgi.sharedConfiguration.area.readOnly=true",
                 "-Dosgi.configuration.cascaded=true",
                 "-Xms1G",
                 "--add-modules=ALL-SYSTEM",
                 "-javaagent:/Users/van/.doom.d/neoemacs/lombok1.18.38.jar",
                 "--add-opens", "java.base/java.util=ALL-UNNAMED",
                 "--add-opens", "java.base/java.lang=ALL-UNNAMED"] \
                + known_args.jvm_arg \
                + ["-jar", jar_path,
                   "-data", known_args.data] \
                + args

After that, `which jdtls` should succeed and `M-x eglot` in a Java buffer should connect without complaining about a missing server.  


<a id="org8cedfbf"></a>

## Jumping into third-party / JDK source

Plain Eglot + jdtls is enough for project sources. It falls short the moment you jump to something that lives only inside a JAR — `String`, `List`, Guava, Spring, anything without a local `.java` on disk.  

jdtls still knows the type. On `textDocument/definition` it returns a custom URI:  

    jdt://contents/rt.jar/java.lang/String.class?...

Emacs&rsquo; default file handlers do not understand `jdt://`. Eglot opens the location as if it were a normal path, so go-to-definition appears broken even though the language server answered correctly.  

neo-emacs closes that gap **with jdtls**, not by replacing it. The pieces:  

1.  **Advertise class-file support.** On initialize we send:

    (:extendedClientCapabilities
     (:classFileContentsSupport t)
     :settings
     (:java (:configuration
             (:maven (:downloadSources t)))))

That tells JDT LS the client can consume class contents, and asks Maven to pull `-sources` jars when available.  

1.  **Register a `jdt://` file-name handler.** `file-name-handler-alist` gets an entry for ``\\`jdt://``. When xref (or `find-file`) hits such a URI, control goes to `+eglot-java--jdt-uri-handler` instead of the filesystem.

2.  **Ask jdtls for the text.** The handler parses the URI into a stable cache path under the project root (`.eglot-java-jdt-cache/...`). On a cache miss it issues the JDT-specific request:

    (jsonrpc-request server :java/classFileContents (list :uri uri))

jdtls replies with either attached source (if a sources jar was downloaded) or a decompiled view of the `.class`. The reply is written to a `.java` file and that path is returned to Emacs.  

1.  **Open the cached buffer as Java.** `find-file-hook` turns those cache files into `java-ts-mode` so font-lock and editing feel normal.

So yes: navigation into third-party / JDK types still goes through **jdtls**. Eglot alone has no decompiler; neo-emacs only teaches Emacs how to open the `jdt://` locations jdtls already produces, and how to request `java/classFileContents` when the file is not cached yet.  

Rough sequence:  

    xref-find-definitions on String / List / library type
          │
          ▼
    jdtls → Location { uri: jdt://contents/... }
          │
          ▼
    Emacs open jdt://...
          │
          ▼
    +eglot-java--jdt-uri-handler
          │
          ├── cache hit  → open .eglot-java-jdt-cache/...java
          │
          └── cache miss → java/classFileContents
                               │
                               ▼
                         write cache + open

Packages such as `lsp-java` do something similar inside lsp-mode. The neo-emacs version is the same idea adapted to Eglot&rsquo;s thinner client: capability flags, a URI handler, and one custom RPC.  


<a id="orgcd6c72c"></a>

## Completion with Corfu

Eglot&rsquo;s completion candidates plug into `completion-at-point-functions`, so they work with Corfu without a special bridge. `kind-icon` can sit on `corfu-margin-formatters` if you want LSP completion kinds drawn in the margin; that is purely cosmetic and unrelated to jdtls.  

With jdtls on `PATH`, Lombok on the server JVM, and the `jdt://` handler installed, the day-to-day Java loop under Eglot is: open a file, get a server, jump across project and dependency code the same way.  

