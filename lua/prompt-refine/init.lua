---@class PromptRefineConfig
---@field cli_cmd string The CLI executable to call
---@field meta_prompt_path string Path to the standard meta prompt file
---@field meta_prompt_teams_path string Path to the teams meta prompt file

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
    cli_cmd = "gemini",
    meta_prompt_path = plugin_root() .. "/meta-prompts/default.txt",
    meta_prompt_teams_path = plugin_root() .. "/meta-prompts/teams.txt",
}

---Current configuration (merged with defaults)
---@type PromptRefineConfig
local config = vim.deepcopy(defaults)

---Strip markdown code block wrappers from LLM output
---Handles ```markdown ... ```, ``` ... ```, and variations with optional language tags
---@param output string The raw output from the CLI
---@return string The sanitized output without markdown code blocks
local function strip_markdown_blocks(output)
    -- Strip leading ```markdown or ```... and trailing ```
    -- Match ``` followed by optional language identifier, then capture everything until closing ```
    local stripped = output:gsub("^```%w*%s*\n", ""):gsub("\n```$", "")
    -- Handle case where there's no newline after opening backticks
    stripped = stripped:gsub("^```%w*%s*", "")
    -- Handle case where there's no newline before closing backticks
    stripped = stripped:gsub("```$", "")
    return stripped
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
    -- Save current file first
    vim.cmd("write")

    -- Get current buffer content
    local bufnr = 0
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

    -- Show notification that refinement is in progress
    vim.notify("PromptRefine: Processing...", vim.log.levels.INFO)

    -- Run CLI asynchronously
    vim.system(config.cli_cmd, {
        stdin = combined_input,
        text = true,
    }, function(result)
        if result.code ~= 0 then
            vim.notify("PromptRefine: CLI failed with code " .. result.code .. "\n" .. (result.stderr or "unknown error"), vim.log.levels.ERROR)
            return
        end

        -- Strip markdown code blocks from output
        local refined_content = strip_markdown_blocks(result.stdout or "")

        -- Split into lines
        local new_lines = vim.split(refined_content, "\n", { trimempty = false })

        -- Replace entire buffer content
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, new_lines)

        -- Save the file again
        vim.cmd("write")

        vim.notify("PromptRefine: Complete!", vim.log.levels.INFO)
    end)
end

---Setup the plugin with user configuration
---@param opts? PromptRefineConfig Optional user configuration
function M.setup(opts)
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
