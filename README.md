# PromptRefine.nvim

A Neovim plugin that sends the current buffer to a local LLM CLI tool for prompt refinement. Pure plumbing—pipes text in, gets refined text out.

## Features

- **Asynchronous execution** - Neovim stays responsive while the LLM processes
- **Two refinement modes** - Standard and Agent Teams
- **Markdown sanitization** - Automatically extracts content from ```code blocks``` even with conversational output
- **Configurable CLI** - Works with stdin-based CLIs (gemini, codex) and argument-based CLIs (claude)
- **File path preservation** - Keeps `@path/to/file` references intact
- **Timeout protection** - Kills hanging processes after 60 seconds (configurable)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "finnff/nvim-prompt-refine",
    config = function()
        require("prompt-refine").setup({
            cli_cmd = { "gemini", "-o", "text" },
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
    -- The CLI command and arguments (array format)
    cli_cmd = { "gemini", "-o", "text" },

    -- Whether to pass input via stdin (default: false)
    -- Set to true for CLIs that read from stdin (e.g., codex, custom tools)
    -- Set to false for CLIs that use positional arguments (e.g., gemini, claude)
    use_stdin = false,

    -- Request timeout in milliseconds (default: 60000 = 60 seconds)
    timeout = 60000,

    -- Optional: Custom paths to meta prompt files
    -- Defaults to built-in meta-prompts if not specified
    -- meta_prompt_path = "~/.config/prompt-refine/meta.txt",
    -- meta_prompt_teams_path = "~/.config/prompt-refine/teams.txt",

    -- Change to safe directory before running CLI (default: true)
    -- Only applies when use_stdin=true; prevents workspace scanning issues
    -- Set to false if your CLI needs access to the current working directory
    safe_cwd = true,
})
```

### CLI Configuration Examples

**Gemini** (recommended/default):
```lua
cli_cmd = { "gemini", "-o", "text" }
use_stdin = false  -- Per official docs, gemini needs prompt as positional argument
```
> **Note**: Per official [gemini-cli automation docs](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/tutorials/automation.md), the pattern is `cat file | gemini "prompt"` where stdin is optional context and the positional argument is the prompt. Our plugin passes the entire input as the prompt, so `use_stdin = false` is correct. Note: `safe_cwd` does not apply when `use_stdin=false`.

**Claude Code**:
```lua
cli_cmd = { "claude", "-p" }
use_stdin = false  -- Query becomes positional argument after -p
```

**OpenAI Codex** (stdin-based):
```lua
cli_cmd = { "codex", "exec", "-", "--skip-git-repo-check" }
use_stdin = true   -- Must override default for stdin-based CLIs
safe_cwd = true    -- Optional: prevents workspace scanning (only works with use_stdin=true)
```

**Custom stdin-based CLI**:
```lua
cli_cmd = { "llm", "run", "--model", "gpt-4" }
use_stdin = true   -- Must override default for stdin-based CLIs
```

### Backward Compatibility

Old string-style `cli_cmd` still works:
```lua
-- This is automatically converted to { "gemini" }
cli_cmd = "gemini"
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
    cli_cmd = { "scripts/dummy-cli.sh" },
})
```

The dummy script wraps output in markdown blocks with conversational text to verify the sanitization works correctly.

## How It Works

1. Captures current buffer number (prevents modifying wrong file if you switch buffers)
2. Saves the current file
3. Reads buffer content and meta prompt file
4. Sends combined input to CLI (via stdin or as argument)
5. Extracts content from markdown code blocks (handles conversational output)
6. Replaces buffer with refined content
7. Saves the file again

## License

MIT
