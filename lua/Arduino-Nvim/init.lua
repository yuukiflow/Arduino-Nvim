local M = {}

-- Load dependencies
require("Arduino-Nvim.remap")
require("Arduino-Nvim.libGetter")

-- Plugin data directory for virtual environment
local PLUGIN_DATA_DIR = vim.fn.stdpath("data") .. "/arduino-nvim"
local VENV_DIR = PLUGIN_DATA_DIR .. "/venv"

-- Get the plugin's root directory (where requirements.txt lives)
local function get_plugin_root()
	local source = debug.getinfo(1, "S").source:sub(2) -- Remove @ prefix
	-- source is .../lua/Arduino-Nvim/init.lua, go up 3 levels
	return vim.fn.fnamemodify(source, ":h:h:h")
end

-- Setup Python virtual environment with dependencies (runs async on plugin load)
local function setup_python_venv()
	local uv_path = vim.fn.exepath("uv")
	if not uv_path or uv_path == "" then
		-- uv not installed, skip setup silently (will warn when actually needed)
		return
	end

	local venv_python = VENV_DIR .. "/bin/python"
	local plugin_root = get_plugin_root()
	local requirements_file = plugin_root .. "/requirements.txt"

	-- Check if venv already exists and has pyserial
	if vim.fn.filereadable(venv_python) == 1 then
		local check = io.popen(venv_python .. " -c 'import serial' 2>&1")
		if check then
			local result = check:read("*a")
			check:close()
			if not result:match("ModuleNotFoundError") then
				return -- Already set up
			end
		end
	end

	-- Create plugin data directory if needed
	if vim.fn.isdirectory(PLUGIN_DATA_DIR) == 0 then
		vim.fn.mkdir(PLUGIN_DATA_DIR, "p")
	end

	-- Run venv setup asynchronously to not block Neovim startup
	vim.fn.jobstart(uv_path .. " venv " .. VENV_DIR, {
		on_exit = function(_, exit_code)
			if exit_code == 0 then
				-- Install dependencies from requirements.txt
				local install_cmd
				if vim.fn.filereadable(requirements_file) == 1 then
					install_cmd = string.format("%s pip install --python %s -r %s", uv_path, venv_python, requirements_file)
				else
					install_cmd = string.format("%s pip install --python %s pyserial", uv_path, venv_python)
				end
				vim.fn.jobstart(install_cmd, {
					on_exit = function(_, install_exit_code)
						if install_exit_code == 0 then
							vim.notify("Arduino-Nvim: Python environment ready", vim.log.levels.INFO)
						end
					end,
				})
			end
		end,
	})
end

-- Setup venv on plugin load
setup_python_venv()

-- Default settings
M.board = "arduino:avr:uno"
M.port = "/dev/ttyUSB0"
M.baudrate = 115200
local config_file = ".arduino_config.lua"

function Trim(s)
	return s:match("^%s*(.-)%s*$")
end

function M.status()
	local buf, win, opts = M.create_floating_cli_monitor()
	local data = string.format("Board: %s\nPort: %s\nBaudrate: %s", M.board, M.port, M.baudrate)
	M.append_to_buffer({ data }, buf, win, opts)
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

function M.load_or_create_config()
	-- Check if sketch.yaml exists
	if vim.fn.filereadable(config_file) == 0 then
		-- If not, create sketch.yaml with default settings
		vim.notify("config file not found. Creating with default settings.", vim.log.levels.INFO)
		local file = io.open(config_file, "w")
		if file then
			file:write("local M = {}\n")
			file:write("M.board = '" .. M.board .. "'\n")
			file:write("M.port = '" .. M.port .. "'\n")
			file:write("M.baudrate =" .. M.baudrate .. "\n")
			file:write("return M\n")
			file:close()
		else
			vim.nofify("Error: Cannot create config file.", vim.log.levels.ERROR)
		end
	else
		-- Read existing file and check if fqbn and port match the config
		local config = loadfile(config_file)
		if config then
			local ok, settings = pcall(config)
			if ok and settings then
				M.board = settings.board or M.board
				M.port = settings.port or M.port
				M.baudrate = settings.baudrate or M.baudrate
				vim.notify("Config loaded from file: " .. config_file, vim.log.levels.INFO)
			end
		end
	end
end

M.load_or_create_config()
-- Utility function to strip ANSI escape codes
local function strip_ansi_codes(line)
	return line:gsub("\27%[[0-9;]*m", "")
end

-- Function to create a floating CLI monitor window that starts small and grows
function M.create_floating_cli_monitor()
	local width = vim.o.columns -- Full width of the screen
	local initial_height = 5 -- Start with a small height (adjustable)

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
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"<CR>",
		"<cmd>lua vim.api.nvim_win_close(" .. win .. ", false)<CR>",
		{ noremap = true, silent = true }
	)

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

-- Helper function to check if arduino-cli is available
local function check_arduino_cli()
	if vim.fn.exepath("arduino-cli") == "" then
		vim.notify("Error: arduino-cli not found in PATH. Please install it first.", vim.log.levels.ERROR)
		return false
	end
	return true
end

-- Function to check code
function M.check()
	-- Check if arduino-cli is available
	if not check_arduino_cli() then
		return
	end

	-- Create the output window buffer and window
	local buf, win, opts = M.create_floating_cli_monitor()

	-- Command to compile in the current directory
	local cmd = "arduino-cli compile --fqbn " .. M.board .. " " .. vim.fn.expand("%:p:h")

	-- Run the command asynchronously
	vim.fn.jobstart(cmd, {
		stdout_buffered = false,
		on_stdout = function(_, data)
			if data then
				M.append_to_buffer(data, buf, win, opts)
			end
		end,
		on_stderr = function(_, data)
			-- Only append lines that contain actual content to avoid false errors
			if data then
				local error_lines = {}
				for _, line in ipairs(data) do
					local cleaned_line = strip_ansi_codes(line)
					if cleaned_line:match("%S") then -- Only consider non-empty, non-whitespace lines
						table.insert(error_lines, "Error: " .. cleaned_line)
					end
				end
				if #error_lines > 0 then
					M.append_to_buffer(error_lines, buf, win, opts)
				end
			end
		end,
		on_exit = function(_, exit_code)
			if exit_code == 0 then
				M.append_to_buffer({ "--- Code checked successfully. ---" }, buf, win, opts)
			else
				M.append_to_buffer({ "--- Code check failed. ---" }, buf, win, opts)
			end
		end,
	})
end

-- Function to compile code and output binaries to ./bin directory
function M.compile()
	-- Check if arduino-cli is available
	if not check_arduino_cli() then
		return
	end

	-- Get sketch directory
	local sketch_dir = vim.fn.expand("%:p:h")
	local bin_dir = sketch_dir .. "/bin"

	-- Create bin directory if it doesn't exist
	if vim.fn.isdirectory(bin_dir) == 0 then
		vim.fn.mkdir(bin_dir, "p")
	end

	-- Create the output window buffer and window
	local buf, win, opts = M.create_floating_cli_monitor()

	M.append_to_buffer({ "--- Compiling sketch ---" }, buf, win, opts)
	M.append_to_buffer({ "Output directory: " .. bin_dir }, buf, win, opts)

	-- Command to compile with output directory
	local cmd = string.format(
		"arduino-cli compile --fqbn %s --output-dir %s %s",
		M.board,
		bin_dir,
		sketch_dir
	)

	-- Run the command asynchronously
	vim.fn.jobstart(cmd, {
		stdout_buffered = false,
		on_stdout = function(_, data)
			if data then
				M.append_to_buffer(data, buf, win, opts)
			end
		end,
		on_stderr = function(_, data)
			-- Only append lines that contain actual content to avoid false errors
			if data then
				local error_lines = {}
				for _, line in ipairs(data) do
					local cleaned_line = strip_ansi_codes(line)
					if cleaned_line:match("%S") then -- Only consider non-empty, non-whitespace lines
						table.insert(error_lines, "Error: " .. cleaned_line)
					end
				end
				if #error_lines > 0 then
					M.append_to_buffer(error_lines, buf, win, opts)
				end
			end
		end,
		on_exit = function(_, exit_code)
			if exit_code == 0 then
				M.append_to_buffer({ "--- Compilation complete. Binaries saved to ./bin ---" }, buf, win, opts)
			else
				M.append_to_buffer({ "--- Compilation failed. ---" }, buf, win, opts)
			end
		end,
	})
end

-- Helper function to split a string by newlines
local function split_string_by_newlines(input)
	local result = {}
	for line in input:gmatch("[^\r\n]+") do
		table.insert(result, line)
	end
	return result
end

-- Updated append_to_buffer function
function M.append_to_buffer(lines, buf, win, opts)
	-- Ensure lines is a table, even if a single string is passed
	if type(lines) == "string" then
		lines = { lines }
	end

	-- Split each line in the table by newlines
	local processed_lines = {}
	for _, line in ipairs(lines) do
		local split_lines = split_string_by_newlines(line)
		vim.list_extend(processed_lines, split_lines)
	end

	-- Clean each line to remove ANSI codes and add to the buffer
	local cleaned_lines = vim.tbl_map(strip_ansi_codes, processed_lines)
	vim.api.nvim_buf_set_lines(buf, -1, -1, false, cleaned_lines)

	-- Adjust the window height if necessary
	adjust_window_height(win, buf, opts)
end

function M.upload()
	-- Check if arduino-cli is available
	if not check_arduino_cli() then
		return
	end

	-- Create the CLI monitor buffer and window
	local buf, win, opts = M.create_floating_cli_monitor()

	-- Commands for compiling and uploading
	local compile_cmd = "arduino-cli compile --fqbn " .. M.board .. " " .. vim.fn.expand("%:p:h")

	-- For UNO R4 WiFi, try using arduino-cli's built-in reset handling
	local upload_cmd = "arduino-cli upload -p "
		.. M.port
		.. " --fqbn "
		.. M.board
		.. " --verify "
		.. vim.fn.expand("%:p:h")

	-- Function to start upload after successful compilation
	local function start_upload()
		vim.fn.jobstart(upload_cmd, {
			stdout_buffered = false,
			on_stdout = function(_, data)
				if data then
					M.append_to_buffer(data, buf, win, opts)
				end
			end,
			on_stderr = function(_, data)
				if data and #data > 0 and data[1]:match("%S") then -- Only log if there is actual error content
					M.append_to_buffer(
						vim.tbl_map(function(line)
							return "Error: " .. line
						end, data),
						buf,
						win,
						opts
					)
				end
			end,
			on_exit = function(_, exit_code)
				if exit_code == 0 then
					M.append_to_buffer({ "--- Upload Complete ---" }, buf, win, opts)
				else
					M.append_to_buffer({ "--- Upload Failed ---" }, buf, win, opts)
					-- Suggest checking available ports
					M.append_to_buffer({
						"Hint: Run ':InoList' to check available ports or ':InoSelectPort' to choose a different port",
					}, buf, win, opts)
				end
			end,
		})
	end

	-- Start the compilation job
	vim.fn.jobstart(compile_cmd, {
		stdout_buffered = false,
		on_stdout = function(_, data)
			if data then
				M.append_to_buffer(data, buf, win, opts)
			end
		end,
		on_stderr = function(_, data)
			if data and #data > 0 and data[1]:match("%S") then -- Only log if there is actual error content
				M.append_to_buffer(
					vim.tbl_map(function(line)
						return "Error: " .. line
					end, data),
					buf,
					win,
					opts
				)
			end
		end,
		on_exit = function(_, exit_code)
			if exit_code == 0 then
				M.append_to_buffer({ "--- Compilation Complete, Starting Upload ---" }, buf, win, opts)
				start_upload()
			else
				M.append_to_buffer({ "--- Compilation Failed ---" }, buf, win, opts)
			end
		end,
	})
end

function M.upload_and_monitor()
	-- Check if arduino-cli is available
	if not check_arduino_cli() then
		return
	end

	-- Check if board and port are configured
	if M.board == "" then
		vim.notify("No board selected. Please run :InoBoard first.", vim.log.levels.WARN)
		return
	end

	if M.port == "" then
		vim.notify("No port selected. Please run :InoPort first.", vim.log.levels.WARN)
		return
	end

	local buf, win, opts = M.create_floating_cli_monitor()
	M.append_to_buffer({ "--- Starting Compilation ---" }, buf, win, opts)

	local compile_cmd = "arduino-cli compile --fqbn "
		.. M.board
		.. " "
		.. vim.fn.expand("%:p:h")
		.. " 2>&1"

	local function start_upload()
		M.append_to_buffer({ "--- Starting Upload ---" }, buf, win, opts)
		local upload_cmd = "arduino-cli upload -p "
			.. M.port
			.. " --fqbn "
			.. M.board
			.. " --verify "
			.. vim.fn.expand("%:p:h")
			.. " 2>&1"

		vim.fn.jobstart(upload_cmd, {
			on_stdout = function(_, data, _)
				if data and #data > 0 then
					M.append_to_buffer(data, buf, win, opts)
				end
			end,
			on_stderr = function(_, data, _)
				if data and #data > 0 then
					M.append_to_buffer(data, buf, win, opts)
				end
			end,
			on_exit = function(_, exit_code, _)
				if exit_code == 0 then
					M.append_to_buffer({ "--- Upload Complete, Starting Monitor ---" }, buf, win, opts)
					-- Close the upload window after a brief delay, then start monitor
					vim.defer_fn(function()
						if vim.api.nvim_win_is_valid(win) then
							vim.api.nvim_win_close(win, true)
						end
						M.monitor()
					end, 1000)
				else
					M.append_to_buffer({ "--- Upload Failed ---" }, buf, win, opts)
				end
			end,
		})
	end

	vim.fn.jobstart(compile_cmd, {
		on_stdout = function(_, data, _)
			if data and #data > 0 then
				M.append_to_buffer(data, buf, win, opts)
			end
		end,
		on_stderr = function(_, data, _)
			if data and #data > 0 then
				M.append_to_buffer(data, buf, win, opts)
			end
		end,
		on_exit = function(_, exit_code, _)
			if exit_code == 0 then
				M.append_to_buffer({ "--- Compilation Complete, Starting Upload ---" }, buf, win, opts)
				start_upload()
			else
				M.append_to_buffer({ "--- Compilation Failed ---" }, buf, win, opts)
			end
		end,
	})
end

function M.select_board_gui(callback)
	-- Check if arduino-cli is available
	if not check_arduino_cli() then
		return
	end

	-- Run 'arduino-cli board listall --format json' and parse the output
	local handle = io.popen("arduino-cli board listall --format json")
	if not handle then
		vim.notify("Error: Failed to execute arduino-cli board listall", vim.log.levels.ERROR)
		return
	end
	local result = handle:read("*a")
	handle:close()

	local ok, data = pcall(vim.json.decode, result)
	if not ok then
		vim.notify("Error parsing JSON from arduino-cli: " .. tostring(data), vim.log.levels.ERROR)
		vim.notify("Raw output: " .. result:sub(1, 200) .. "...", vim.log.levels.DEBUG)
		return
	end

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

	require("telescope.pickers")
		.new({}, {
			prompt_title = "Select Arduino Board",
			finder = require("telescope.finders").new_table({
				results = boards,
				entry_maker = function(entry)
					return {
						value = entry.fqbn,
						display = entry.display,
						ordinal = entry.ordinal,
					}
				end,
			}),
			sorter = require("telescope.config").values.generic_sorter({}),
			attach_mappings = function(prompt_bufnr, map)
				local actions = require("telescope.actions")
				local action_state = require("telescope.actions.state")

				local function on_select()
					local selection = action_state.get_selected_entry()
					if selection then
						M.set_board(selection.value) -- Use the selected FQBN
						actions.close(prompt_bufnr)
						if callback then
							callback()
						end
					end
				end

				map("i", "<CR>", on_select)
				map("n", "<CR>", on_select)
				return true
			end,
		})
		:find()
end

function M.select_port_gui()
	-- Check if arduino-cli is available
	if not check_arduino_cli() then
		return
	end

	-- Get list of connected ports using arduino-cli
	local handle = io.popen("arduino-cli board list")
	if not handle then
		vim.notify("Error: Failed to execute arduino-cli board list", vim.log.levels.ERROR)
		return
	end
	local result = handle:read("*a")
	handle:close()

	-- Extract port names from the arduino-cli output
	local ports = {}
	for line in result:gmatch("[^\r\n]+") do
		if line:match("^/dev/tty") or line:match("^/dev/cu") or line:match("^COM") then -- Matches Linux/macOS and Windows COM port formats
			table.insert(ports, line:match("^(%S+)")) -- Capture the port name only
		end
	end

	-- If no ports found, show an error message
	if #ports == 0 then
		vim.notify("No connected COM ports found.", vim.log.levels.ERROR)
		return
	end

	-- Use Telescope to display the list of available ports
	require("telescope.pickers")
		.new({}, {
			prompt_title = "Select Arduino Port",
			finder = require("telescope.finders").new_table({ results = ports }),
			sorter = require("telescope.config").values.generic_sorter({}),
			attach_mappings = function(prompt_bufnr, map)
				map("i", "<CR>", function()
					local selection = require("telescope.actions.state").get_selected_entry()
					if selection then
						M.set_com(selection[1])
					end
					require("telescope.actions").close(prompt_bufnr)
				end)
				return true
			end,
		})
		:find()
end

function M.InoList()
	-- Check if arduino-cli is available
	if not check_arduino_cli() then
		return
	end

	local buf, win, opts = M.create_floating_cli_monitor()
	-- list all available ports1
	local handle = io.popen("arduino-cli board list")
	if not handle then
		vim.notify("Error: Failed to execute arduino-cli board list", vim.log.levels.ERROR)
		return
	end
	local result = handle:read("*a")
	handle:close()
	M.append_to_buffer({ result }, buf, win, opts)
end

-- Main GUI function to link board and port selection
function M.gui()
	M.select_board_gui(function()
		-- Only try to select port if there might be connected devices
		local handle = io.popen("arduino-cli board list")
		if handle then
			local result = handle:read("*a")
			handle:close()
			-- Check if any ports are listed
			if result:match("^/dev/tty") or result:match("^COM") then
				M.select_port_gui()
			else
				vim.notify("No Arduino boards connected. Skipping port selection.", vim.log.levels.INFO)
			end
		else
			vim.notify("Failed to check for connected boards.", vim.log.levels.WARN)
		end
	end)
end

function M.monitor()
	-- Check if arduino-cli is available
	if not check_arduino_cli() then
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)

	local win_width = math.floor(vim.o.columns * 0.8)
	local win_height = math.floor(vim.o.lines * 0.8)
	local win_opts = {
		relative = "editor",
		width = win_width,
		height = win_height,
		row = math.floor((vim.o.lines - win_height) / 2),
		col = math.floor((vim.o.columns - win_width) / 2),
		style = "minimal",
		border = "rounded",
	}

	local win = vim.api.nvim_open_win(buf, true, win_opts)

	-- First show monitor configuration info
	local config_info = {
		"Arduino Serial Monitor",
		"======================",
		"Board: " .. M.board,
		"Port: " .. M.port,
		"",
		"Getting monitor configuration...",
	}
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, config_info)

	-- Get monitor configuration details
	local describe_cmd = "arduino-cli monitor -p " .. M.port .. " --describe"
	vim.fn.jobstart(describe_cmd, {
		stdout_buffered = false,
		on_stdout = function(_, data)
			if data then
				-- Filter and format the output
				local filtered_lines = {}
				for _, line in ipairs(data) do
					if line:match("%S") and not line:match("%[32m") and not line:match("%[0m") then
						table.insert(filtered_lines, line)
					end
				end
				if #filtered_lines > 0 then
					vim.api.nvim_buf_set_lines(buf, -1, -1, false, filtered_lines)
				end
			end
		end,
		on_exit = function()
			-- Add separator and start the actual monitor
			vim.api.nvim_buf_set_lines(
				buf,
				-1,
				-1,
				false,
				{ "", "Starting monitor...", "Press CTRL-C or Esc to exit.", "" }
			)

			local serial_command = string.format("arduino-cli monitor -p %s -b %s --config baudrate=%s", M.port, M.board, M.baudrate)

			-- Create a new buffer for the terminal
			local term_buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_win_set_buf(win, term_buf)

			-- Start the actual monitor in the new buffer
			vim.fn.termopen(serial_command, {
				cwd = vim.fn.expand("%:p:h"),
				on_exit = function(_, exit_code)
					if exit_code ~= 0 and vim.api.nvim_buf_is_valid(term_buf) then
						vim.api.nvim_buf_set_lines(
							term_buf,
							-1,
							-1,
							false,
							{ "", "Monitor exited with code: " .. exit_code }
						)
					end
				end,
			})

			-- Update key mappings for the new buffer
			vim.api.nvim_buf_set_keymap(
				term_buf,
				"t",
				"<C-c>",
				"<C-\\><C-n>:bd!<CR>",
				{ noremap = true, silent = true }
			)
			vim.api.nvim_buf_set_keymap(term_buf, "n", "<C-c>", ":bd!<CR>", { noremap = true, silent = true })
			vim.api.nvim_buf_set_keymap(
				term_buf,
				"t",
				"<Esc>",
				"<C-\\><C-n>:bd!<CR>",
				{ noremap = true, silent = true }
			)
			vim.api.nvim_buf_set_keymap(term_buf, "n", "<Esc>", ":bd!<CR>", { noremap = true, silent = true })

			vim.cmd("startinsert")
		end,
	})

	-- Better key mappings for monitor
	vim.api.nvim_buf_set_keymap(buf, "t", "<C-c>", "<C-\\><C-n>:bd!<CR>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "<C-c>", ":bd!<CR>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "t", "<Esc>", "<C-\\><C-n>:bd!<CR>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":bd!<CR>", { noremap = true, silent = true })
end

vim.api.nvim_create_user_command("InoSelectBoard", function()
	M.select_board_gui()
end, {})
vim.api.nvim_create_user_command("InoSelectPort", function()
	M.select_port_gui()
end, {})
vim.api.nvim_create_user_command("InoCheck", function()
	M.check()
end, {})
vim.api.nvim_create_user_command("InoCompile", function()
	M.compile()
end, {})
vim.api.nvim_create_user_command("InoGUI", function()
	M.gui()
end, {})
vim.api.nvim_create_user_command("InoMonitor", function()
	M.monitor()
end, {})
vim.api.nvim_create_user_command("InoSetBaud", function(opts)
	M.set_baudrate(opts.args)
end, { nargs = 1 })
vim.api.nvim_create_user_command("InoUpload", function()
	M.upload()
end, {})
vim.api.nvim_create_user_command("InoWatchUpload", function()
	M.upload_and_monitor()
end, {})
vim.api.nvim_create_user_command("InoUploadSlow", function()
	M.baudrate = "1200"
	vim.notify("Trying upload with 1200 baud rate...", vim.log.levels.INFO)
	M.upload()
end, {})
vim.api.nvim_create_user_command("InoUploadReset", function()
	-- Try manual reset approach for UNO R4 WiFi
	local buf, win, opts = M.create_floating_cli_monitor()
	M.append_to_buffer({ "--- Attempting upload with manual reset ---" }, buf, win, opts)

	-- First set port to 1200 baud to trigger reset
	local reset_cmd = "stty -f " .. M.port .. " 1200"
	M.append_to_buffer({ "Resetting board..." }, buf, win, opts)
	os.execute(reset_cmd)

	-- Wait a moment for reset
	vim.defer_fn(function()
		-- Try upload after reset
		local upload_cmd = "arduino-cli upload -p " .. M.port .. " --fqbn " .. M.board .. " " .. vim.fn.expand("%:p:h")
		M.append_to_buffer({ "Starting upload after reset..." }, buf, win, opts)

		vim.fn.jobstart(upload_cmd, {
			stdout_buffered = false,
			on_stdout = function(_, data)
				if data then
					M.append_to_buffer(data, buf, win, opts)
				end
			end,
			on_stderr = function(_, data)
				if data and #data > 0 and data[1]:match("%S") then
					M.append_to_buffer(
						vim.tbl_map(function(line)
							return "Error: " .. line
						end, data),
						buf,
						win,
						opts
					)
				end
			end,
			on_exit = function(_, exit_code)
				if exit_code == 0 then
					M.append_to_buffer({ "--- Upload with reset Complete ---" }, buf, win, opts)
				else
					M.append_to_buffer({ "--- Upload with reset Failed ---" }, buf, win, opts)
				end
			end,
		})
	end, 2000) -- 2 second delay
end, {})

vim.api.nvim_create_user_command("InoDebugUpload", function()
	-- Debug upload process for UNO R4 WiFi
	local buf, win, opts = M.create_floating_cli_monitor()
	M.append_to_buffer({ "--- Debugging Arduino UNO R4 WiFi Upload ---" }, buf, win, opts)

	-- Check board detection
	M.append_to_buffer({ "Checking board detection..." }, buf, win, opts)
	vim.fn.jobstart("arduino-cli board list", {
		stdout_buffered = false,
		on_stdout = function(_, data)
			if data then
				M.append_to_buffer(data, buf, win, opts)
			end
		end,
		on_exit = function()
			-- Try to touch the port to see if it's accessible
			M.append_to_buffer({ "Testing port access..." }, buf, win, opts)
			vim.fn.jobstart("stty -f " .. M.port, {
				stdout_buffered = false,
				on_stdout = function(_, data)
					if data then
						M.append_to_buffer(
							{ "Port " .. M.port .. " accessible: " .. table.concat(data, " ") },
							buf,
							win,
							opts
						)
					end
				end,
				on_stderr = function(_, data)
					if data then
						M.append_to_buffer({ "Port error: " .. table.concat(data, " ") }, buf, win, opts)
					end
				end,
				on_exit = function()
					-- Try verbose upload
					M.append_to_buffer({ "Attempting verbose upload..." }, buf, win, opts)
					local verbose_cmd = "arduino-cli upload -p "
						.. M.port
						.. " --fqbn "
						.. M.board
						.. " --verbose "
						.. vim.fn.expand("%:p:h")
					vim.fn.jobstart(verbose_cmd, {
						stdout_buffered = false,
						on_stdout = function(_, data)
							if data then
								M.append_to_buffer(data, buf, win, opts)
							end
						end,
						on_stderr = function(_, data)
							if data then
								M.append_to_buffer(data, buf, win, opts)
							end
						end,
					})
				end,
			})
		end,
	})
end, {})

vim.api.nvim_create_user_command("InoStatus", function()
	M.status()
end, {})
vim.api.nvim_create_user_command("InoList", function()
	M.InoList()
end, {})

-- ============================================================================
-- LittleFS Data Upload for ESP8266
-- ============================================================================

-- ESP8266 LittleFS configuration for 4M2M (4MB flash, 2MB filesystem)
local ESP8266_LITTLEFS_CONFIG = {
	fs_start = 0x200000, -- 2MB offset
	fs_end = 0x3FA000, -- End address
	fs_size = 0x1FA000, -- ~2MB filesystem size
	fs_page = 256, -- Page size
	fs_block = 8192, -- Block size
	baud = 460800, -- Upload baud rate
}

-- Get venv python path (venv is set up on plugin load)
local function get_venv_python()
	local venv_python = VENV_DIR .. "/bin/python"

	-- Check if venv exists and has pyserial
	if vim.fn.filereadable(venv_python) == 1 then
		local check = io.popen(venv_python .. " -c 'import serial' 2>&1")
		if check then
			local result = check:read("*a")
			check:close()
			if not result:match("ModuleNotFoundError") then
				return venv_python, nil
			end
		end
	end

	return nil, "Python environment not ready. Restart Neovim or install uv: https://docs.astral.sh/uv/"
end

-- Function to find ESP8266 tools in Arduino15 directory
local function find_esp8266_tools()
	local arduino15 = vim.fn.expand("$HOME/Library/Arduino15")
	local esp8266_base = arduino15 .. "/packages/esp8266"

	local tools = {
		mklittlefs = nil,
		esptool = nil,
		python3 = nil,
	}

	-- Find mklittlefs (in tools/mklittlefs/*/mklittlefs)
	local mklittlefs_dir = esp8266_base .. "/tools/mklittlefs"
	local handle = io.popen("ls -1 " .. mklittlefs_dir .. " 2>/dev/null | head -1")
	if handle then
		local version = handle:read("*l")
		handle:close()
		if version and version ~= "" then
			tools.mklittlefs = mklittlefs_dir .. "/" .. version .. "/mklittlefs"
		end
	end

	-- Find esptool.py (in hardware/esp8266/*/tools/esptool/esptool.py)
	local hw_dir = esp8266_base .. "/hardware/esp8266"
	handle = io.popen("ls -1 " .. hw_dir .. " 2>/dev/null | head -1")
	if handle then
		local version = handle:read("*l")
		handle:close()
		if version and version ~= "" then
			tools.esptool = hw_dir .. "/" .. version .. "/tools/esptool/esptool.py"
		end
	end

	-- Use uv-managed venv with pyserial (set up on plugin load)
	local venv_python, err = get_venv_python()
	if venv_python then
		tools.python3 = venv_python
	else
		-- Log error but don't fail yet - will be caught later
		vim.notify("Arduino-Nvim: " .. (err or "Failed to setup Python environment"), vim.log.levels.WARN)
	end

	return tools
end

-- Upload LittleFS data directory to ESP8266
function M.upload_data()
	-- Check if this is an ESP8266 board
	if not M.board:match("^esp8266:") then
		vim.notify("LittleFS upload is only supported for ESP8266 boards", vim.log.levels.ERROR)
		return
	end

	-- Check if data/ directory exists
	local sketch_dir = vim.fn.expand("%:p:h")
	local data_dir = sketch_dir .. "/data"

	if vim.fn.isdirectory(data_dir) == 0 then
		vim.notify("No 'data' directory found in sketch folder: " .. sketch_dir, vim.log.levels.ERROR)
		return
	end

	-- Find ESP8266 tools
	local tools = find_esp8266_tools()

	if not tools.mklittlefs or vim.fn.filereadable(tools.mklittlefs) == 0 then
		vim.notify("mklittlefs tool not found. Please install ESP8266 board package.", vim.log.levels.ERROR)
		return
	end

	if not tools.esptool or vim.fn.filereadable(tools.esptool) == 0 then
		vim.notify("esptool.py not found. Please install ESP8266 board package.", vim.log.levels.ERROR)
		return
	end

	if not tools.python3 or vim.fn.filereadable(tools.python3) == 0 then
		vim.notify("python3 not found. Please install ESP8266 board package.", vim.log.levels.ERROR)
		return
	end

	-- Create output window
	local buf, win, opts = M.create_floating_cli_monitor()

	-- Create temporary file for LittleFS image
	local littlefs_image = "/tmp/littlefs.bin"

	-- Step 1: Create LittleFS image
	M.append_to_buffer({ "--- Creating LittleFS image ---" }, buf, win, opts)
	M.append_to_buffer({ "Data directory: " .. data_dir }, buf, win, opts)

	local config = ESP8266_LITTLEFS_CONFIG
	local mklittlefs_cmd = string.format(
		"%s -c %s -s %d -p %d -b %d %s",
		tools.mklittlefs,
		data_dir,
		config.fs_size,
		config.fs_page,
		config.fs_block,
		littlefs_image
	)

	M.append_to_buffer({ "Running: mklittlefs -c data -s " .. config.fs_size .. " ..." }, buf, win, opts)

	vim.fn.jobstart(mklittlefs_cmd, {
		stdout_buffered = false,
		on_stdout = function(_, data)
			if data then
				M.append_to_buffer(data, buf, win, opts)
			end
		end,
		on_stderr = function(_, data)
			if data and #data > 0 and data[1]:match("%S") then
				M.append_to_buffer(data, buf, win, opts)
			end
		end,
		on_exit = function(_, exit_code)
			if exit_code ~= 0 then
				M.append_to_buffer({ "--- Failed to create LittleFS image ---" }, buf, win, opts)
				return
			end

			-- Get file size
			local stat = vim.loop.fs_stat(littlefs_image)
			local size_kb = stat and math.floor(stat.size / 1024) or 0
			M.append_to_buffer({ "LittleFS image created: " .. size_kb .. " KB" }, buf, win, opts)

			-- Step 2: Upload LittleFS image using esptool
			M.append_to_buffer({ "", "--- Uploading LittleFS image to ESP8266 ---" }, buf, win, opts)
			M.append_to_buffer({ "Port: " .. M.port }, buf, win, opts)
			M.append_to_buffer({ "Flash address: 0x" .. string.format("%X", config.fs_start) }, buf, win, opts)

			local esptool_cmd = string.format(
				"%s %s --chip esp8266 --port %s --baud %d write_flash 0x%X %s",
				tools.python3,
				tools.esptool,
				M.port,
				config.baud,
				config.fs_start,
				littlefs_image
			)

			vim.fn.jobstart(esptool_cmd, {
				stdout_buffered = false,
				on_stdout = function(_, data2)
					if data2 then
						M.append_to_buffer(data2, buf, win, opts)
					end
				end,
				on_stderr = function(_, data2)
					if data2 and #data2 > 0 and data2[1]:match("%S") then
						M.append_to_buffer(data2, buf, win, opts)
					end
				end,
				on_exit = function(_, exit_code2)
					if exit_code2 == 0 then
						M.append_to_buffer({ "", "--- LittleFS Upload Complete ---" }, buf, win, opts)
						M.append_to_buffer({ "Files uploaded successfully to ESP8266 filesystem." }, buf, win, opts)
					else
						M.append_to_buffer({ "", "--- LittleFS Upload Failed ---" }, buf, win, opts)
						M.append_to_buffer({
							"Hint: Check port connection and try :InoSelectPort",
						}, buf, win, opts)
					end

					-- Clean up temp file
					os.remove(littlefs_image)
				end,
			})
		end,
	})
end

vim.api.nvim_create_user_command("InoDataUpload", function()
	M.upload_data()
end, {})

return M
