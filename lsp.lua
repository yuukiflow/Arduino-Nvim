-- Path to the configuration file where board and port are saved
local config_file = '.arduino_config.lua'

-- Load configuration function
local function load_arduino_config()
    local config = loadfile(config_file)
    if config then
        local ok, settings = pcall(config)
        if ok and settings then
            return settings
        end
    end
    -- Fallback defaults if config loading fails
    return {
        board = "arduino:avr:uno",
        port = "/dev/ttyACM0",
    }
end

-- Check or create sketch.yaml with correct fqbn and port
local function check_or_create_sketch_yaml(settings)
    local yaml_file = "sketch.yaml"
    local ino_files = vim.fn.glob('*.ino', false, true)
    if #ino_files == 0 then
        -- No .ino files found, do not proceed
        return
    end
    -- Load current config for board and port
    local board = settings.board
    local port = settings.port

    -- Check if sketch.yaml exists
    if vim.fn.filereadable(yaml_file) == 0 then
        -- If not, create sketch.yaml with default settings
        vim.notify("sketch.yaml not found. Creating with default settings.", vim.log.levels.INFO)
        local file = io.open(yaml_file, "w")
        if file then
            file:write("fqbn: " .. board .. "\n")
            file:write("port: " .. port .. "\n")
            file:close()
        end
    else
        -- Read existing file and check if fqbn and port match the config
        local current_yaml = {}
        for line in io.lines(yaml_file) do
            local key, value = line:match("(%S+):%s*(%S+)")
            if key and value then
                current_yaml[key] = value
            end
        end

        -- Update fqbn or port if they differ from config
        if current_yaml["default_fqbn"] ~= board or current_yaml["default_port"] ~= port then
            vim.notify("Updating fqbn or port in sketch.yaml to match config.", vim.log.levels.INFO)
            local file = io.open(yaml_file, "w")
            file:write("default_fqbn: " .. board .. "\n")
            file:write("default_port: " .. port .. "\n")
            file:close()
        end
    end
end


-- Set up the Arduino language server with saved configuration
local function setup_arduino_lsp()
    -- Load board configuration
    local settings = load_arduino_config()
    check_or_create_sketch_yaml(settings)
    local board = settings.board or "arduino:avr:uno" -- Default fallback
    -- Configure the Arduino language server using loaded settings
    require('lspconfig').arduino_language_server.setup {
        cmd = {
            "arduino-language-server",
            "-cli", "arduino-cli",
            "-cli-config", "$HOME/.arduino15/arduino-cli.yaml",
            "-clangd", "/usr/bin/clangd",
            "-fqbn", board,
        },
        filetypes = { "arduino", "cpp" },
        root_dir = function(fname)
            return vim.loop.cwd()
        end,
        handlers = {
        }
    }
end

-- Export the setup function
return {
    setup = setup_arduino_lsp
}
