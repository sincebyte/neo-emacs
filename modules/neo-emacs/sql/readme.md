
# Table of Contents

1.  [Ejc-sql Usage](#org64f6cdb)
2.  [Sqlserver](#org2ae71da)



<a id="org64f6cdb"></a>

# Ejc-sql Usage

-   The privacy configuration  
    In here you could save any connections in your setting config.  
    But where should the setting located especially for our Emacs config project with a public github repository? There have a privacy path which is excluded in the public repository named **user-private-dir**, You could config your connection&rsquo;s account/password here for safely.
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


<a id="org2ae71da"></a>

# Sqlserver

Maybe you need this post for \`The server selected protocol version TLS10 is not accepted by client preferences\` : <https://blog.csdn.net/w605283073/article/details/126755540>  

