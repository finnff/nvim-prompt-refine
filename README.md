# PromptRefine.nvim

A Neovim plugin that sends the current buffer to a local LLM CLI tool for prompt refinement. Pure plumbing—pipes text in, gets refined text out.

## Features

- **Asynchronous execution** - Neovim stays responsive while the LLM processes
- **Two refinement modes** - Standard and Agent Teams
- **Markdown sanitization** - Automatically strips ```code block``` wrappers from LLM output
- **Configurable CLI** - Works with any local LLM tool (gemini, claude, codex, etc.)
- **File path preservation** - Keeps `@path/to/file` references intact

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "finnff/nvim-prompt-refine",
    config = function()
        require("prompt-refine").setup({
            cli_cmd = "gemini",  -- or "claude", "codex", or your custom CLI
            meta_prompt_path = "~/.config/prompt-refine/meta.txt",
            meta_prompt_teams_path = "~/.config/prompt-refine/teams.txt",
        })
    end,
}
```

Or add to your runtimepath:

```bash
git clone https://github.com/finnff/nvim-prompt-refine ~/.config/nvim/pack/vendor/start/nvim-prompt-refine
```

## Configuration

```lua
require("prompt-refine").setup({
    -- The CLI executable to call
    cli_cmd = "gemini",

    -- Path to standard meta prompt
    meta_prompt_path = "~/.config/prompt-refine/meta.txt",

    -- Path to agent teams meta prompt
    meta_prompt_teams_path = "~/.config/prompt-refine/teams.txt",
})
```

## Usage

1. Write a prompt in your buffer
2. Execute `:PromptRefine` for standard refinement
3. Or execute `:PromptRefineTeams` for agent team optimization
4. The buffer is saved, sent to your CLI, and replaced with the refined output

## Testing

A dummy CLI script is provided at `scripts/dummy-cli.sh` for testing without API keys:

```bash
chmod +x scripts/dummy-cli.sh
```

Then configure in your Neovim:

```lua
require("prompt-refine").setup({
    cli_cmd = "scripts/dummy-cli.sh",
})
```

The dummy script wraps output in markdown blocks to verify the sanitization works correctly.

## How It Works

1. Saves the current file
2. Reads buffer content and meta prompt file
3. Sends combined input to CLI via stdin (avoids shell escaping issues)
4. Strips markdown code blocks from output
5. Replaces buffer with refined content
6. Saves the file again

## License

MIT
