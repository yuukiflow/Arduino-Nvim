-- board_config file is intended to save all code that
-- interacts with the config file per project
-- i.e. `.arduino_config.lua`
-- If any other code wants to interact with the config file
-- should call this module to update it or get the current data
local gui = require("Arduino-Nvim.gui")
local utils = require("Arduino-Nvim.utils")

local M = {}

-- Function to save config file with given params
function M.save_config()
	local file = io.open(_ArduinoConfigValues.config_file, "w")
	if file then
		file:write("return {\n")
		file:write(string.format("  board = %q,\n", _ArduinoConfigValues.board))
		file:write(string.format("  port = %q,\n", _ArduinoConfigValues.port))
		file:write(string.format("  baudrate = %q,\n", _ArduinoConfigValues.baudrate))
		file:write("}\n")
		file:close()
	else
		vim.notify("Error: Cannot write to config file.", vim.log.levels.ERROR)
	end
end

-- Function to set the COM port and save config
function M.set_com(port)
	_ArduinoConfigValues.port = utils.trim(port)
	vim.notify("Port set to: " .. port)
	M.save_config()
end

-- Function to set the board type and save config
function M.set_board(board)
	_ArduinoConfigValues.board = utils.trim(board)
	vim.notify("Board set to: " .. board)
	M.save_config()
end

-- Function to set the baud rate and save config
function M.set_baudrate(baudrate)
	_ArduinoConfigValues.baudrate = utils.trim(baudrate)
	vim.notify("Baud rate set to: " .. baudrate)
	M.save_config()
end

-- Function to save settings to the config file
function M.load_or_create_config()
	-- Check if sketch.yaml exists
	if vim.fn.filereadable(_ArduinoConfigValues.config_file) == 0 then
		-- If not, create sketch.yaml with default settings
		vim.notify("config file not found. Creating with default settings.", vim.log.levels.INFO)
    M.save_config()
	else
		-- Read existing file and check if fqbn and port match the config
		local config = loadfile(_ArduinoConfigValues.config_file)
		if config then
			local ok, settings = pcall(config)
			if ok and settings then
          _ArduinoConfigValues.board = settings.board or _ArduinoConfigValues.board
          _ArduinoConfigValues.port = settings.port or _ArduinoConfigValues.port
          _ArduinoConfigValues.baudrate = settings.baudrate or _ArduinoConfigValues.baudrate
				vim.notify(
          "Config loaded from file: " .. _ArduinoConfigValues.config_file,
          vim.log.levels.INFO)
			end
		end
	end
end

function M.board_config_status()
	local data = string.format(
    "Board: %s\nPort: %s\nBaudrate: %s",
    _ArduinoConfigValues.board,
    _ArduinoConfigValues.port,
    _ArduinoConfigValues.baudrate)
	gui.show_in_floating_window({ data })
end

function M.arduino_board_list()
	-- Check if arduino-cli is available
	if not utils.check_arduino_cli() then
		return
	end

	-- list all available ports1
	local handle = io.popen("arduino-cli board list")
	if not handle then
		vim.notify("Error: Failed to execute arduino-cli board list", vim.log.levels.ERROR)
		return
	end
	local result = handle:read("*a")
	handle:close()
	gui.show_in_floating_window({ result })
end


return M
