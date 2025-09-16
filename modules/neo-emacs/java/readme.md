
# Table of Contents

1.  [Java module](#org06476d3)
    1.  [most wanted](#org1434f58)
    2.  [Dap-java Usage](#org818b7ee)
    3.  [build handle](#org97e4320)
    4.  [eclipse jdt server](#orgf7320a5)
2.  [python lsp](#org4c5334f)
3.  [issue](#org55e99c7)
    1.  [complete code](#org462cf34)



<a id="org06476d3"></a>

# Java module

Neo-Emacs will automatically download the jdtls from \`lsp-java-jdt-download-url\`, and now it&rsquo;s located at [jdt-language-server-1.22.0](https://www.eclipse.org/downloads/download.php?file=/jdtls/milestones/1.22.0/jdt-language-server-1.22.0-202304131553.tar.gz).After that you could use all the features powered by eclipse.  

-   code-format  
    Firstly you could check your java env correctly or not. check by doom doctor, a warning showed that  
    we need \`brew install clang-format\`.So here we are.  
    
        brew install clang-format
        brew install semgrep
-   Generate eclipse files  
    Execute mvn command for generate eclipse .project & .classpath files on your project root path.  
    
        mvn eclipse:clean eclipse:eclipse
-   Support projectlombok plugin  
    There have a default lombok.jar in `doom-user-dir/neoemacs` which you could replace by yourself.  
    
        (setq  lombok-jar-path (expand-file-name (concat doom-user-dir "neoemacs/lombok.jar")
-   Shotcuts/Key binding  
    
    <table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">
    <caption class="t-bottom"><span class="table-number">Table 1:</span> java mode key binding</caption>
    
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
    </tbody>
    </table>
-   HotSwarp  
    [hotswapagent](http://hotswapagent.org/mydoc_configuration.html) ，a relacement of jrebel  
    -   DCEVM  
        1.  [download](https://github.com/JetBrains/JetBrainsRuntime/releases?page=6)  [dcevm](https://ssw.jku.at/dcevm/)
        2.  use command run your application `dcevmjava -jar app.jar`
    -   Hotswapagent  
        1.  download lastest hotswapagent [here](https://github.com/HotswapProjects/HotswapAgent/releases)
        2.  replace hotswapagent to $DCEVM\_HOME/lib/hotswap/hotswap-agent.jar
    -   Startup  
        1.  hotswap-agent config.  
            [hotswap-agent.properties](https://github.com/HotswapProjects/HotswapAgent/blob/master/hotswap-agent-core/src/main/resources/hotswap-agent.properties) hotswap-agent.properties place to project&rsquo;s resources directory.  
            
                extraClasspath=target/classes;../longda-archetype-dao/target/classes
                watchResources=../longda-archetype-dao/src/main/resources
                webappDir=
                disabledPlugins=Hibernate, Hibernate3JPA, Hibernate3, Jersey1, Jersey2, MyFaces,
                Mojarra, Omnifaces, ELResolver, WildFlyELResolver, OsgiEquinox, Owb, Proxy, Weld,
                JBossModules, ResteasyRegistry, Deltaspike, GlassFish, Vaadin, Wicket, CxfJAXRS,
                FreeMarker, Undertow
                autoHotswap=true
                spring.basePackagePrefix=pkg.
                LOGGER=info
        2.  startup with dcevm  
            use dcevm jar run your application which locate at $DCEVM\_HOME/bin/java.  
            add java startup parameters for HotswapAgent.  
            
                $dcevmjava -XX:HotswapAgent=fatjar -Xlog:redefine+class*=info -jar app.jar
-   How to upgrade jdtls  
    1.  Customization your own eclipse jdtls project version by replace it&rsquo;s binary pacage.
    2.  Download the lastest jdt-language-server from <https://download.eclipse.org/jdtls/milestones>.
    3.  Replace file to ~/.emacs.d/.local/etc/lsp/eclipse.jdt.ls.


<a id="org1434f58"></a>

## TODO most wanted

1.  coding

    1.  eldoc [lsp-java/issues/432](https://github.com/emacs-lsp/lsp-java/issues/432)


<a id="org818b7ee"></a>

## TODO Dap-java Usage

I do not use debug for years. So be careful the documentation maybe outdated.I think you need customization by yourself.  

-   Config the debug host and port, add file $usr\_private\_dir/dap-java-config.el.
-   Use \`(setq user-private-dir &ldquo;$usr\_private\_dir/dap-java-config.el&rdquo; )\` make it effective.  
    
        1       (dap-register-debug-template
        2       "user-service"
        3       (list :name "Java Attach"
        4               :type "java"
        5               :request "attach"
        6               :projectName "user-service"
        7               :hostName "127.0.0.1"
        8               :port 1044))
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
    <td class="org-left">DESCRIPTION</td>
    </tr>
    
    <tr>
    <td class="org-left">, n</td>
    <td class="org-left">dap-next</td>
    <td class="org-left">Breakpoint next</td>
    </tr>
    
    <tr>
    <td class="org-left">, b</td>
    <td class="org-left">dap-breakpoint-toggle</td>
    <td class="org-left">&#xa0;</td>
    </tr>
    
    <tr>
    <td class="org-left">, c</td>
    <td class="org-left">dap-continue</td>
    <td class="org-left">&#xa0;</td>
    </tr>
    
    <tr>
    <td class="org-left">, r</td>
    <td class="org-left">dap-eval-region</td>
    <td class="org-left">&#xa0;</td>
    </tr>
    
    <tr>
    <td class="org-left">, a</td>
    <td class="org-left">dap-eval-thing-at-point</td>
    <td class="org-left">&#xa0;</td>
    </tr>
    
    <tr>
    <td class="org-left">, d</td>
    <td class="org-left">dap-debug</td>
    <td class="org-left">&#xa0;</td>
    </tr>
    
    <tr>
    <td class="org-left">, u</td>
    <td class="org-left">dap-ui-repl</td>
    <td class="org-left">&#xa0;</td>
    </tr>
    </tbody>
    </table>


<a id="org97e4320"></a>

## build handle

because of the isuue <https://github.com/emacs-lsp/lsp-java/issues/465>  

    /Users/van/soft/apache-maven-3.6.1/bin/mvn -Djdt.js.server.root\=/Users/van/lsp-java/ -Djunit.runner.root\=/Users/van/.emacs.d/.local/cache/eclipse.jdt.ls/test-runner/ -Djunit.runner.fileName\=junit-platform-console-standalone.jar -Djava.debug.root\=/Users/van/lsp-java/bundles clean package -Djdt.download.url\=http\://1.117.167.195/download/jdt-language-server-1.31.0-202401111522.tar.gz -f ~/.doom.d/modules/neo-emacs/java/pom.xml


<a id="orgf7320a5"></a>

## eclipse jdt server

    /Users/van/soft/jdk/jdk-21.0.6.jdk/Contents/Home/bin/java \
    $JAVA_17_HOME/bin/java \
    -Declipse.application=org.eclipse.jdt.ls.core.id1 \
    -Dosgi.bundles.defaultStartLevel=4 \
    -Declipse.product=org.eclipse.jdt.ls.core.product \
    -Djava.import.generatesMetadataFilesAtProjectRoot=false \
    -Dlog.level=ALL \
    -Xmx1G \
    --add-modules=ALL-SYSTEM \
    --add-opens java.base/java.util=ALL-UNNAMED \
    --add-opens java.base/java.lang=ALL-UNNAMED \
    -jar ./plugins/org.eclipse.equinox.launcher_1.7.0.v20250331-1702.jar \
    -configuration ./config_mac \
    -data ~/.config/emacs/.local/etc/java-workspace


<a id="org4c5334f"></a>

# python lsp

use pyright for completion and ruff for code format  


<a id="org55e99c7"></a>

# issue


<a id="org462cf34"></a>

## TODO complete code

<https://github.com/emacs-lsp/lsp-mode/issues/4875>  

