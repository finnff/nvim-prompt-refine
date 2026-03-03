-- PromptRefine plugin loader
-- Registers user commands after the plugin is set up

local M = {}

-- Track if setup has been called
local setup_called = false

-- Store the module reference
local prompt_refine

-- Lazy-load the main module
local function get_module()
    if not prompt_refine then
        prompt_refine = require("prompt-refine")
    end
    return prompt_refine
end

-- Create the commands
vim.api.nvim_create_user_command("PromptRefine", function()
    local mod = get_module()
    if not setup_called then
        vim.notify("PromptRefine: Call require('prompt-refine').setup() first", vim.log.levels.ERROR)
        return
    end
    mod.prompt_refine()
end, {
    desc = "Refine the current prompt using the standard meta prompt",
})

vim.api.nvim_create_user_command("PromptRefineTeams", function()
    local mod = get_module()
    if not setup_called then
        vim.notify("PromptRefine: Call require('prompt-refine').setup() first", vim.log.levels.ERROR)
        return
    end
    mod.prompt_refine_teams()
end, {
    desc = "Refine the current prompt using the agent teams meta prompt",
})

-- Monkey-patch the setup function to track when it's called
local original_setup = get_module().setup
get_module().setup = function(opts)
    setup_called = true
    return original_setup(opts)
end

return M
