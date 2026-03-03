---@class PromptRefineConfig
---@field cli_cmd string[] The CLI command and arguments (e.g., { "gemini", "-o", "text", "-p" })
---@field use_stdin? boolean Whether to pass input via stdin (default: true). Set false for CLIs like Claude that use -p flag
---@field model? string Model name to pass via --model flag (e.g., "sonnet", "gemini-2.5-pro")
---@field meta_prompt_path? string Path to the standard meta prompt file
---@field meta_prompt_teams_path? string Path to the teams meta prompt file
---@field timeout? integer Timeout in milliseconds (default: 60000 = 60 seconds)
---@field safe_cwd? boolean Run CLI in an empty temp directory to prevent workspace scanning (default: true)

local M = {}

---Get the plugin's root directory
local function plugin_root()
    local source = debug.getinfo(1, "S").source:sub(2)
    -- From lua/prompt-refine/init.lua, go up 3 levels to reach plugin root
    return vim.fn.fnamemodify(source, ":h:h:h")
end

---Default configuration
---@type PromptRefineConfig
local defaults = {
    cli_cmd = { "gemini", "-o", "text", "-p" },
    use_stdin = false,  -- gemini uses -p flag for headless mode; prompt appended as -p's value
    model = nil,  -- optional: passed as --model <value> to the CLI
    meta_prompt_path = plugin_root() .. "/meta-prompts/default.txt",
    meta_prompt_teams_path = plugin_root() .. "/meta-prompts/teams.txt",
    timeout = 60000,  -- 60 seconds
    safe_cwd = true,  -- Run CLI in empty temp dir to prevent workspace scanning
}

---Current configuration (merged with defaults)
---@type PromptRefineConfig
local config = vim.deepcopy(defaults)

---Extract content from markdown code blocks
---Handles LLM output that may have conversational text around the code block
---Returns content between first ``` and last ```
---@param output string The raw output from the CLI
---@return string The content extracted from code blocks, or original if no blocks found
local function strip_markdown_blocks(output)
    -- Find first opening ```
    local first_tick = output:find("```")
    if not first_tick then
        return output  -- No code block found, return as-is
    end

    -- Find the newline after the opening ``` (skip language identifier like ```markdown)
    local content_start = output:find("\n", first_tick)
    if not content_start then
        return output  -- Malformed, no newline after opening ```
    end
    content_start = content_start + 1  -- Skip the newline to get actual content

    -- Find closing ``` after the content start
    local last_tick = output:find("```", content_start)
    if not last_tick then
        return output  -- Unclosed code block, return as-is
    end

    -- Extract content between backticks
    local content_end = last_tick - 1

    -- Handle potential trailing newline before closing ```
    if content_end >= content_start and output:sub(content_end, content_end) == "\n" then
        content_end = content_end - 1
    end

    return output:sub(content_start, content_end)
end

---Read file content as a string
---@param filepath string Path to the file
---@return string|nil File content or nil if error
local function read_file(filepath)
    local file, err = io.open(filepath, "r")
    if not file then
        return nil, err
    end
    local content = file:read("*all")
    file:close()
    return content
end

---Refine the current buffer using the specified meta prompt
---@param meta_prompt_path string Path to the meta prompt file to use
local function refine_prompt(meta_prompt_path)
    -- CRITICAL: Capture actual buffer number BEFORE async call
    -- This prevents modifying the wrong buffer if user switches files
    local bufnr = vim.api.nvim_get_current_buf()

    -- Save current file first
    vim.cmd("write")

    -- Get current buffer content
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local buffer_content = table.concat(lines, "\n")

    -- Read meta prompt file
    local meta_prompt, err = read_file(meta_prompt_path)
    if not meta_prompt then
        vim.notify("PromptRefine: Failed to read meta prompt: " .. (err or "unknown error"), vim.log.levels.ERROR)
        return
    end

    -- Combine meta prompt with buffer content
    local separator = "\n\n--- PROMPT TO REFINE ---\n\n"
    local combined_input = meta_prompt .. separator .. buffer_content

    -- Show detailed notification about what's happening
    local input_size = #combined_input
    local cmd_str = table.concat(config.cli_cmd, " ")
    vim.notify(string.format("PromptRefine: Calling '%s' with %d bytes of input...", cmd_str, input_size), vim.log.levels.INFO)

    -- Build the command arguments
    local cmd_args = vim.deepcopy(config.cli_cmd)

    -- Inject --model flag if configured
    if config.model then
        table.insert(cmd_args, "--model")
        table.insert(cmd_args, config.model)
    end

    -- For CLIs that don't read stdin (like Claude), append input as argument
    if not config.use_stdin then
        table.insert(cmd_args, combined_input)
    end

    -- Track completion for timeout handling
    local done = false
    local start_time = vim.loop.now()

    -- Determine cwd: use an empty temp directory if safe_cwd is enabled
    -- This prevents CLIs like Gemini from scanning the workspace directory on startup
    local final_stdin = config.use_stdin and combined_input or nil
    local safe_dir = nil
    if config.safe_cwd then
        safe_dir = vim.fn.tempname() .. "_promptrefine"
        vim.fn.mkdir(safe_dir, "p")
    end

    -- Run CLI asynchronously
    local handle = vim.system(cmd_args, {
        stdin = final_stdin,
        text = true,
        cwd = safe_dir,
    }, function(result)
        done = true
        -- Clean up temp directory
        if safe_dir then
            vim.fn.delete(safe_dir, "rf")
        end
        vim.schedule(function()
            local elapsed = vim.loop.now() - start_time
            if result.code ~= 0 then
                vim.notify(string.format("PromptRefine: CLI failed (code %d) after %dms\nstderr: %s",
                    result.code, elapsed, result.stderr or "none"), vim.log.levels.ERROR)
                return
            end

            local stdout_size = result.stdout and #result.stdout or 0
            vim.notify(string.format("PromptRefine: Got %d bytes of output in %dms", stdout_size, elapsed), vim.log.levels.INFO)

            -- Strip markdown code blocks from output
            local refined_content = strip_markdown_blocks(result.stdout or "")

            -- Split into lines
            local new_lines = vim.split(refined_content, "\n", { trimempty = false })

            -- Verify buffer still exists and is valid before modifying
            if not vim.api.nvim_buf_is_valid(bufnr) then
                vim.notify("PromptRefine: Original buffer no longer exists", vim.log.levels.WARN)
                return
            end

            -- Replace entire buffer content
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, new_lines)

            -- Save the file again
            vim.cmd("write")

            vim.notify(string.format("PromptRefine: Complete! Replaced buffer with %d lines in %dms", #new_lines, elapsed), vim.log.levels.INFO)
        end)
    end)

    -- Set up timeout to kill the process if it takes too long
    local timer = vim.loop.new_timer()
    timer:start(config.timeout, 0, function()
        if not done then
            handle:kill(9)  -- SIGKILL
            timer:close()
            vim.schedule(function()
                local elapsed = vim.loop.now() - start_time
                vim.notify(string.format("PromptRefine: Timeout after %dms (limit: %dms). CLI process killed.",
                    elapsed, config.timeout), vim.log.levels.ERROR)
            end)
        else
            timer:close()
        end
    end)
end

---Setup the plugin with user configuration
---@param opts? PromptRefineConfig Optional user configuration
function M.setup(opts)
    -- Auto-convert string cli_cmd to table for backward compatibility
    if opts and opts.cli_cmd and type(opts.cli_cmd) == "string" then
        opts.cli_cmd = { opts.cli_cmd }
    end

    config = vim.tbl_deep_extend("force", defaults, opts or {})

    -- Validate config paths exist (warn but don't error)
    local meta_file = io.open(config.meta_prompt_path, "r")
    if not meta_file then
        vim.notify("PromptRefine: Warning - meta_prompt_path not found: " .. config.meta_prompt_path, vim.log.levels.WARN)
    else
        meta_file:close()
    end

    local teams_file = io.open(config.meta_prompt_teams_path, "r")
    if not teams_file then
        vim.notify("PromptRefine: Warning - meta_prompt_teams_path not found: " .. config.meta_prompt_teams_path, vim.log.levels.WARN)
    else
        teams_file:close()
    end
end

---Run standard prompt refinement
function M.prompt_refine()
    refine_prompt(config.meta_prompt_path)
end

---Run agent teams prompt refinement
function M.prompt_refine_teams()
    refine_prompt(config.meta_prompt_teams_path)
end

return M
