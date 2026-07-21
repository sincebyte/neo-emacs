
# Table of Contents

1.  [cursor](#org89bb03b)
    1.  [Install](#orgee3198e)
    2.  [lsp server](#org8040646)
    3.  [Use cursor official ACP](#org63d1eef)

This module provides integration with Opencode, a powerful AI agent orchestration system for Emacs that enables seamless interaction with Large Language Models (LLMs) and various development tools.

\## Features

-   Integration with Opencode AI agents
-   MCP (Model Context Protocol) server support
-   Enhanced AI-assisted development workflows
-   Context-aware code completion and suggestions

\## Configuration

The module is preconfigured with sensible defaults. Additional configuration can be added to your private config.el file.

\## Key Bindings

Currently no default key bindings are set. You can add your preferred bindings to your private configuration:

    (map! :leader
          :prefix ("o" . "opencode")
          :desc "Start opencode session" "o" #'opencode-start-session
          :desc "Opencode chat" "c" #'opencode-chat
          :desc "Opencode edit" "e" #'opencode-edit)

\## Customization

You can customize the following variables in your config.el:

-   \`opencode-enable-auto-sync\`: Enable automatic synchronization
-   \`opencode-default-model\`: Set default AI model to use
-   \`opencode-mcp-servers\`: Configure MCP servers

\## Dependencies

This module depends on the \`opencode\` package which is fetched from \`codeberg.org/sczi/opencode.el\`.


<a id="org89bb03b"></a>

# cursor


<a id="orgee3198e"></a>

## Install

To ensure Cursor&rsquo;s official agent is available in your shell and supports the ACP protocol, follow these steps:
Cursor&rsquo;s official agent provides the ACP protocol via the agent acp subcommand. You can verify it works correctly using either method:

    # Install Cursor CLI
    brew install --cask cursor-cli
    agent --version
    
    # Authenticate with your Cursor account
    agent login
    
    agent acp --help


<a id="org8040646"></a>

## lsp server

<https://oraios.github.io/serena/02-usage/050_configuration.html#modes>

In the config(located at your project/.cursor/mcp.json), &ndash;from points to a local directory (/Users/van/ZY/workspace/serena), so uvx runs the code directly from your local source instead of downloading it from PyPI.Use **git clone <https://github.com/oraios/serena.git> *Users/van/ZY/workspace*** download source code first.You can simply run git pull in your local serena directory (/Users/van/ZY/workspace/serena) to update the code. 

    {
      "mcpServers": {
        "gitnexus": {
          "command": "npx",
          "args": [
            "-y",
            "gitnexus@latest",
            "mcp"
          ]
        },
        "codegraph": {
          "type": "stdio",
          "command": "codegraph",
          "args": ["serve", "--mcp"]
        },
        "lsp": {
          "type": "stdio",
          "command": "/Users/van/.pyenv/shims/uvx",
          "args": [
              "--from",
              "/Users/van/ZY/workspace/serena",
              "serena",
              "start-mcp-server",
              "--context",
              "ide",
              "--project",
              "/Users/van/ZY/workspace/skytech",
              "--language-backend",
              "LSP"
          ]
        }
      }
    }


<a id="org63d1eef"></a>

## Use cursor official ACP

ased on the Pull Request #394 you referenced, yes, agent-shell now defaults to using Cursor&rsquo;s official ACP.

About <https://github.com/xenodium/agent-shell/pull/394>
Override: [agent-shell/agent-shell-cursor.el](file:///Users/van/.config/emacs/.local/straight/repos/agent-shell/agent-shell-cursor.el)

