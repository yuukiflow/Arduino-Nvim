-- board_config file is intended to save all code that
-- interacts with the config file per project
-- i.e. `.arduino_config.lua`
-- If any other code wants to interact with the config file
-- should call this module to update it or get the current data
local utils = require("Arduino-Nvim.utils")

local M = {}

-- Default settings
M.config_file = ".arduino_config.lua"
M.board_config_table = {
  board = "arduino:avr:uno",
  port = "/dev/ttyUSB0",
  baudrate = 115200
}

-- Function to save config file with given params
function M.save_config(b_config_table)
	local file = io.open(M.config_file, "w")
	if file then
		file:write("return {\n")
		file:write(string.format("  board = %q,\n", b_config_table.board))
		file:write(string.format("  port = %q,\n", b_config_table.port))
		file:write(string.format("  baudrate = %q,\n", b_config_table.baudrate))
		file:write("}\n")
		file:close()
	else
		vim.notify("Error: Cannot write to config file.", vim.log.levels.ERROR)
	end
end

-- Function to set the COM port and save config
function M.set_com(port)
	M.board_config_table.port = utils.trim(port)
	vim.notify("Port set to: " .. port)
	utils.save_config(M.board_config_table)
end

-- Function to set the board type and save config
function M.set_board(board)
	M.board_config_table.board = utils.trim(board)
	vim.notify("Board set to: " .. board)
	utils.save_config(M.board_config_table)
end

-- Function to set the baud rate and save config
function M.set_baudrate(baudrate)
	M.board_config_table.baudrate = utils.trim(baudrate)
	vim.notify("Baud rate set to: " .. baudrate)
	utils.save_config(M.board_config_table)
end

-- Function to save settings to the config file
function M.load_or_create_config()
	-- Check if sketch.yaml exists
	if vim.fn.filereadable(M.config_file) == 0 then
		-- If not, create sketch.yaml with default settings
		vim.notify("config file not found. Creating with default settings.", vim.log.levels.INFO)
    b_config.save_config(M.board_config_table)
	else
		-- Read existing file and check if fqbn and port match the config
		local config = loadfile(M.config_file)
		if config then
			local ok, settings = pcall(config)
			if ok and settings then
        M.board_config_table = {
          board = settings.board or M.board_config_table.board,
          port = settings.port or M.board_config_table.port,
          baudrate = settings.baudrate or M.board_config_table.baudrate,
        }
				vim.notify("Config loaded from file: " .. M.config_file, vim.log.levels.INFO)
			end
		end
	end
end

function M.board_config_status()
	local buf, win, opts = utils.create_floating_cli_monitor()
	local data = string.format(
    "Board: %s\nPort: %s\nBaudrate: %s",
    M.board_config_table.board,
    M.board_config_table.port,
    M.board_config_table.baudrate)
	utils.append_to_buffer({ data }, buf, win, opts)
end


return M
