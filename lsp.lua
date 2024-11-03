-- Path to the configuration file where board and port are saved
local config_file = vim.fn.stdpath('config') .. '/arduino_config.lua'

-- Load configuration function
local function load_arduino_config()
    local config = loadfile(config_file)
    if config then
        local ok, settings = pcall(config)
        if ok and settings then
            return settings
        else
            vim.notify("Error loading Arduino config file.", vim.log.levels.ERROR)
        end
    else
        vim.notify("Arduino config file not found. Using default settings.", vim.log.levels.WARN)
    end
    -- Fallback defaults if config loading fails
    return {
        board = "arduino:avr:uno",
        port = "/dev/ttyACM0",
    }
end

-- Set up the Arduino language server with saved configuration
local function setup_arduino_lsp()
    -- Load board configuration
    local settings = load_arduino_config()
    local board = settings.board or "arduino:avr:uno" -- Default fallback

    -- Configure the Arduino language server using loaded settings
    require('lspconfig').arduino_language_server.setup {
        cmd = {
            "arduino-language-server", -- Replace with the path of your manually installed binary
            "-cli", "arduino-cli",
            "-cli-config", "/home/edin/.arduino15/arduino-cli.yaml",
            "-fqbn", "arduino:avr:nano",
            "-clangd", "/usr/bin/clangd",
            "-log"
        },
        filetypes = { "arduino", "cpp" },
        root_dir = function(fname)
            return require('lspconfig').util.root_pattern("sketch.yaml", ".git")(fname) or vim.loop.cwd()
        end,
        handlers = {
            ["window/logMessage"] = function() end, -- Suppress extraneous logs
            ["window/showMessage"] = function() end
        }
    }
end

vim.api.nvim_create_autocmd("FileType", {
    pattern = "arduino",
    callback = function()
        require("lspconfig").arduino_language_server.setup {
            cmd = {
                "arduino-language-server",
                "-cli", "arduino-cli",
                "-cli-config", "/home/edin/.arduino15/arduino-cli.yaml",
                "-fqbn", "arduino:avr:nano",
                "-clangd", "/usr/bin/clangd"
            },
            filetypes = { "arduino", "cpp" },
            root_dir = function(fname)
                return require('lspconfig').util.root_pattern("sketch.yaml", ".git")(fname) or vim.loop.cwd()
            end,
        }
    end
})


-- Export the setup function
return {
    setup = setup_arduino_lsp
}
