require("edin.remap")
require("edin.libGetter")
local M = {}

M.board = "uno"
M.port = "COM3"
M.baudrate = 115200

local config_file = vim.fn.stdpath('config') .. '/arduino_config.lua'

function Trim(s)
    return s:match("^%s*(.-)%s*$")
end

function M.status()
    local status = string.format("Board: %s\nPort: %s\nBaudrate: %s", M.board, M.port, M.baudrate)
    os.execute("notify-send -t 3000 '" .. status .. "'")
end

-- Function to save settings to the config file
function M.save_config()
    local file = io.open(config_file, "w")
    if file then
        file:write("return {\n")
        file:write(string.format("  board = %q,\n", M.board))
        file:write(string.format("  port = %q,\n", M.port))
        file:write(string.format("  baudrate = %q,\n", M.baudrate))
        file:write("}\n")
        file:close()
    else
        vim.notify("Error: Cannot write to config file.", vim.log.levels.ERROR)
    end
end

-- Function to load settings from the config file
function M.load_config()
    local config = loadfile(config_file)
    if config then
        local ok, settings = pcall(config)
        if ok and settings then
            M.board = settings.board or M.board
            M.port = settings.port or M.port
            M.baudrate = settings.baudrate or M.baudrate
        else
            vim.notify("Error loading config file.", vim.log.levels.ERROR)
        end
    else
        vim.notify("Config file not found. Using default settings.", vim.log.levels.WARN)
    end
end

-- Load configuration on startup
M.load_config()

-- Utility function to strip ANSI escape codes
local function strip_ansi_codes(line)
    return line:gsub("\27%[[0-9;]*m", "")
end

-- Function to create a floating CLI monitor window that starts small and grows
local function create_floating_cli_monitor()
    local width = vim.o.columns -- Full width of the screen
    local initial_height = 5    -- Start with a small height (adjustable)

    -- Create a buffer for the floating window
    local buf = vim.api.nvim_create_buf(false, true)

    -- Define initial window options to position it at the bottom
    local opts = {
        relative = "editor",
        width = width,
        height = initial_height,
        row = vim.o.lines - initial_height - 2, -- Position at the bottom
        col = 0,
        style = "minimal",
        border = "rounded", -- Optional: add border for visual separation
    }

    -- Create the floating window and store its ID
    local win = vim.api.nvim_open_win(buf, true, opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "<cmd>lua vim.api.nvim_win_close(" .. win .. ", false)<CR>",
        { noremap = true, silent = true })
    -- Set buffer options for the CLI monitor
    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(buf, "swapfile", false)

    return buf, win, opts
end

-- Function to dynamically adjust the floating window height based on buffer content
local function adjust_window_height(win, buf, opts)
    local line_count = vim.api.nvim_buf_line_count(buf)
    local new_height = math.min(line_count, vim.o.lines - 2) -- Max height limited to screen size

    -- Update window height and reposition if necessary to keep it at the bottom
    opts.height = new_height
    opts.row = vim.o.lines - new_height - 2
    vim.api.nvim_win_set_config(win, opts)
end

-- Function to set the COM port and save config
function M.set_com(port)
    M.port = Trim(port)
    vim.notify("Port set to: " .. port)
    M.save_config()
end

-- Function to set the board type and save config
function M.set_board(board)
    M.board = Trim(board)
    vim.notify("Board set to: " .. board)
    M.save_config()
end

-- Function to set the baud rate and save config
function M.set_baudrate(baudrate)
    M.baudrate = Trim(baudrate)
    vim.notify("Baud rate set to: " .. baudrate)
    M.save_config()
end

-- Function to check code
function M.check()
    -- Create the output window buffer and window
    local buf, win, opts = create_floating_cli_monitor()

    -- Function to append lines to the output buffer and adjust height
    local function append_to_buffer(lines)
        -- Strip ANSI codes from each line and append to buffer
        local cleaned_lines = vim.tbl_map(strip_ansi_codes, lines)
        vim.api.nvim_buf_set_lines(buf, -1, -1, false, cleaned_lines)
        adjust_window_height(win, buf, opts)
    end

    -- Command to compile in the current directory
    local cmd = "arduino-cli compile --fqbn " .. M.board .. " " .. vim.fn.expand('%')

    -- Run the command asynchronously
    vim.fn.jobstart(cmd, {
        stdout_buffered = false,
        on_stdout = function(_, data)
            if data then
                append_to_buffer(data)
            end
        end,
        on_stderr = function(_, data)
            -- Only append lines that contain actual content to avoid false errors
            if data then
                local error_lines = {}
                for _, line in ipairs(data) do
                    local cleaned_line = strip_ansi_codes(line)
                    if cleaned_line:match("%S") then  -- Only consider non-empty, non-whitespace lines
                        table.insert(error_lines, "Error: " .. cleaned_line)
                    end
                end
                if #error_lines > 0 then
                    append_to_buffer(error_lines)
                end
            end
        end,
        on_exit = function(_, exit_code)
            if exit_code == 0 then
                append_to_buffer({ "--- Code checked successfully. ---" })
            else
                append_to_buffer({ "--- Code check failed. ---" })
            end
        end,
    })
end


function M.upload()
    -- Create the CLI monitor buffer and window
    local buf, win, opts = create_floating_cli_monitor()

    -- Function to append lines to the monitor buffer and adjust height
    local function append_to_buffer(lines)
        -- Strip ANSI codes from each line and append to buffer
        local cleaned_lines = vim.tbl_map(strip_ansi_codes, lines)
        vim.api.nvim_buf_set_lines(buf, -1, -1, false, cleaned_lines)
        adjust_window_height(win, buf, opts)
    end

    -- Commands for compiling and uploading
    local compile_cmd = "arduino-cli compile --fqbn " .. M.board .. " " .. vim.fn.expand('%:p:h')
    local upload_cmd = "arduino-cli upload -p " .. M.port .. " --fqbn " .. M.board .. " " .. vim.fn.expand('%:p:h')

    -- Function to start upload after successful compilation
    local function start_upload()
        vim.fn.jobstart(upload_cmd, {
            stdout_buffered = false,
            on_stdout = function(_, data)
                if data then
                    append_to_buffer(data)
                end
            end,
            on_stderr = function(_, data)
                if data and #data > 0 and data[1]:match("%S") then -- Only log if there is actual error content
                    append_to_buffer(vim.tbl_map(function(line)
                        return "Error: " .. line
                    end, data))
                end
            end,
            on_exit = function()
                append_to_buffer({ "--- Upload Complete ---" })
            end,
        })
    end

    -- Start the compilation job
    vim.fn.jobstart(compile_cmd, {
        stdout_buffered = false,
        on_stdout = function(_, data)
            if data then
                append_to_buffer(data)
            end
        end,
        on_stderr = function(_, data)
            if data and #data > 0 and data[1]:match("%S") then -- Only log if there is actual error content
                append_to_buffer(vim.tbl_map(function(line)
                    return "Error: " .. line
                end, data))
            end
        end,
        on_exit = function(_, exit_code)
            if exit_code == 0 then
                append_to_buffer({ "--- Compilation Complete, Starting Upload ---" })
                start_upload()
            else
                append_to_buffer({ "--- Compilation Failed ---" })
            end
        end,
    })
end

function M.select_board_gui(callback)
    -- Run 'arduino-cli board listall --format json' and parse the output
    local handle = io.popen("arduino-cli board listall --format json")
    local result = handle:read("*a")
    handle:close()

    local json = require('dkjson') -- JSON library for parsing
    local ok, data = pcall(json.decode, result)

    local boards = {}
    if ok and data and data.boards then
        for _, board in ipairs(data.boards) do
            -- Extract the 'name' and 'fqbn' of each board
            local board_name = board.name or "Unknown Board"
            local fqbn = board.fqbn

            if fqbn then
                table.insert(boards, {
                    display = board_name,
                    fqbn = fqbn,
                    ordinal = board_name,
                })
            end
        end
    else
        print("Failed to parse JSON output of 'arduino-cli board listall'")
        return
    end

    -- If no boards are found, display a message
    if #boards == 0 then
        print("No Arduino boards found in the list.")
        return
    end

    require('telescope.pickers').new({}, {
        prompt_title = "Select Arduino Board",
        finder = require('telescope.finders').new_table {
            results = boards,
            entry_maker = function(entry)
                return {
                    value = entry.fqbn,
                    display = entry.display,
                    ordinal = entry.ordinal,
                }
            end
        },
        sorter = require('telescope.config').values.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
            local actions = require('telescope.actions')
            local action_state = require('telescope.actions.state')

            local function on_select()
                local selection = action_state.get_selected_entry()
                if selection then
                    M.set_board(selection.value) -- Use the selected FQBN
                    actions.close(prompt_bufnr)
                    if callback then callback() end
                end
            end

            map('i', '<CR>', on_select)
            map('n', '<CR>', on_select)
            return true
        end
    }):find()
end

function M.select_port_gui()
    -- Get list of connected ports using arduino-cli
    local handle = io.popen("arduino-cli board list")
    local result = handle:read("*a")
    handle:close()

    -- Extract port names from the arduino-cli output
    local ports = {}
    for line in result:gmatch("[^\r\n]+") do
        if line:match("^/dev/tty") or line:match("^COM") then -- Matches Linux/macOS and Windows COM port formats
            table.insert(ports, line:match("^(%S+)"))         -- Capture the port name only
        end
    end

    -- If no ports found, show an error message
    if #ports == 0 then
        vim.notify("No connected COM ports found.", vim.log.levels.ERROR)
        return
    end

    -- Use Telescope to display the list of available ports
    require('telescope.pickers').new({}, {
        prompt_title = "Select Arduino Port",
        finder = require('telescope.finders').new_table { results = ports },
        sorter = require('telescope.config').values.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
            map('i', '<CR>', function()
                local selection = require('telescope.actions.state').get_selected_entry()
                if selection then M.set_com(selection[1]) end
                require('telescope.actions').close(prompt_bufnr)
            end)
            return true
        end
    }):find()
end

-- Main GUI function to link board and port selection
function M.gui()
    M.select_board_gui(function() M.select_port_gui() end)
end

function M.monitor()
    local serial_command = string.format("arduino-cli monitor -p %s -c %s", M.port, M.baudrate)
    local hypr_command = string.format("hyprctl dispatch exec \"kitty -e sh -c '%s; exec bash'\" &", serial_command)
    os.execute(hypr_command)
    --vim.notify("Opening serial monitor on " .. M.port .. " at " .. M.baudrate .. " baud.")
    vim.print(serial_command)
end

vim.api.nvim_create_user_command("InoSetCom", function(opts) M.set_com(opts.args) end, { nargs = 1 })
vim.api.nvim_create_user_command("InoSetBoard", function(opts) M.set_board(opts.args) end, { nargs = 1 })
vim.api.nvim_create_user_command("InoCheck", function() M.check() end, {})
vim.api.nvim_create_user_command("InoUpload", function() M.upload() end, {})
vim.api.nvim_create_user_command("InoGUI", function() M.gui() end, {})
vim.api.nvim_create_user_command("InoMonitor", function() M.monitor() end, {})
vim.api.nvim_create_user_command("InoSetBaud", function(opts) M.set_baudrate(opts.args) end, { nargs = 1 })
vim.api.nvim_create_user_command("InoStatus", function() M.status() end, {})

return M
