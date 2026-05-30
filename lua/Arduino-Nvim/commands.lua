local M = {}

-- Load dependencies
local utils = require("Arduino-Nvim.utils")
local gui = require("Arduino-Nvim.gui")

-- get_boards returns a table of available boards
function M.get_boards()
	-- Check if arduino-cli is available
	if not utils.check_arduino_cli() then
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

  return boards
end

function M.get_ports_v2()
	-- Check if arduino-cli is available
	if not utils.check_arduino_cli() then
		return
	end

	-- Get list of connected ports using arduino-cli
	local handle = io.popen("arduino-cli board list --format json")
	if not handle then
		vim.notify("Error: Failed to execute arduino-cli board list --format json", vim.log.levels.ERROR)
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

	-- Extract port names from the arduino-cli output
	local ports = {}
  if ok and data and data.detected_ports then
    for _, info in ipairs(data.detected_ports) do
      local address = info.port.address
      local name = "Unknown"
      if info.matching_boards and #info.matching_boards > 0 then
        name = info.matching_boards[1].name
      end

      table.insert(ports, {address = address, name = name})
    end
  end
	-- If no ports found, show an error message
	if #ports == 0 then
		vim.notify("No connected COM ports found.", vim.log.levels.ERROR)
		return
	end

  return ports
end

-- get_ports returns a table with the available ports
function M.get_ports()
	-- Check if arduino-cli is available
	if not utils.check_arduino_cli() then
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

  return ports
end

-- Function to check code compilation
function M.compile(callback)
	-- Check if arduino-cli is available
	if not utils.check_arduino_cli() then
		return
	end

	-- Command to compile in the current directory
  local cmd = "arduino-cli compile --fqbn " 
    .. _ArduinoConfigValues.board 
    .. " " 
    .. vim.fn.shellescape(vim.fn.expand("%:p:h"))

	-- Run the command asynchronously
	vim.fn.jobstart(cmd, {
		stdout_buffered = false,
		on_stdout = function(_, data)
			if data then
				gui.show_in_floating_window(data)
			end
		end,
		on_stderr = function(_, data)
			-- Only append lines that contain actual content to avoid false errors
			if data and #data > 0 then
				local error_lines = {}
				for _, line in ipairs(data) do
					local cleaned_line = utils.strip_ansi_codes(line)
					if cleaned_line:match("%S") then -- Only consider non-empty, non-whitespace lines
						table.insert(error_lines, "Error: " .. cleaned_line)
					end
				end
				if #error_lines > 0 then
					gui.show_in_floating_window(error_lines)
				end
			end
		end,
		on_exit = function(_, exit_code)
			if exit_code == 0 then
				gui.show_in_floating_window({ "--- Code compilation successful. ---" })
        if callback then
          callback()
        end
			else
				gui.show_in_floating_window({ "--- Code compilation failed. ---" })
			end
		end,
	})
end

function M.upload()
	-- Check if arduino-cli is available
	if not utils.check_arduino_cli() then
		return
	end

	local upload_cmd = "arduino-cli upload -p "
		.. _ArduinoConfigValues.port
		.. " --fqbn "
		.. _ArduinoConfigValues.board
		.. " --verify "
    .. vim.fn.shellescape(vim.fn.expand("%:p:h"))

	-- Function to start upload after successful compilation
	local function start_upload()
		vim.fn.jobstart(upload_cmd, {
			stdout_buffered = false,
			on_stdout = function(_, data)
				if data then
          gui.show_in_floating_window(data)
				end
			end,
			on_stderr = function(_, data)
				if data and #data > 0 and data[1]:match("%S") then -- Only log if there is actual error content
					gui.show_in_floating_window(
						vim.tbl_map(function(line)
							return "Error: " .. line
						end, data)
					)
				end
			end,
			on_exit = function(_, exit_code)
				if exit_code == 0 then
					gui.show_in_floating_window({ "--- Upload Complete ---" })
				else
					gui.show_in_floating_window({ "--- Upload Failed ---" })
					-- Suggest checking available ports
					gui.show_in_floating_window({
						"Hint: Run ':InoList' to check available ports or ':InoSelectPort' to choose a different port",
					})
				end
			end,
		})
	end

  -- compile code and upload as a callback
  M.compile(start_upload)
end

function M.upload_slow()
  local init_br = _ArduinoConfigValues.baudrate
  _ArduinoConfigValues.baudrate = 1200
  vim.notify("Trying upload with 1200 baud rate...", vim.log.levels.INFO)
  M.upload()
  _ArduinoConfigValues.baudrate = init_br
end

function M.monitor()
	-- Check if arduino-cli is available
	if not utils.check_arduino_cli() then
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
		"Board: " .. _ArduinoConfigValues.board,
		"Port: " .. _ArduinoConfigValues.port,
		"",
		"Getting monitor configuration...",
	}
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, config_info)

	-- Get monitor configuration details
	local describe_cmd = "arduino-cli monitor -p " .. _ArduinoConfigValues.port .. " --describe"
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

			local serial_command = string.format(
        "arduino-cli monitor -p %s -b %s --config %d",
        _ArduinoConfigValues.port,
        _ArduinoConfigValues.board,
        _ArduinoConfigValues.baudrate
      )

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

function M.upload_reset()
	-- Try manual reset approach for UNO R4 WiFi
	utils.append_to_buffer({ "--- Attempting upload with manual reset ---" }, buf, win, opts)

	-- First set port to 1200 baud to trigger reset
	local reset_cmd = "stty -f " .. _ArduinoConfigValues.port .. " 1200"
	utils.append_to_buffer({ "Resetting board..." }, buf, win, opts)
	os.execute(reset_cmd)

	-- Wait a moment for reset
	vim.defer_fn(function()
		-- Try upload after reset
		local upload_cmd = "arduino-cli upload -p " 
    .. _ArduinoConfigValues.port 
    .. " --fqbn " 
    .. _ArduinoConfigValues.board 
    .. " --verify " 
    .. vim.fn.shellescape(vim.fn.expand("%:p:h"))
		gui.show_in_floating_window({ "Starting upload after reset..." })

		vim.fn.jobstart(upload_cmd, {
			stdout_buffered = false,
			on_stdout = function(_, data)
				if data then
					gui.show_in_floating_window(data)
				end
			end,
			on_stderr = function(_, data)
				if data and #data > 0 and data[1]:match("%S") then
					gui.show_in_floating_window(
						vim.tbl_map(function(line)
							return "Error: " .. line
						end, data)
					)
				end
			end,
			on_exit = function(_, exit_code)
				if exit_code == 0 then
					gui.show_in_floating_window({ "--- Upload with reset Complete ---" })
				else
					gui.show_in_floating_window({ "--- Upload with reset Failed ---" })
				end
			end,
		})
	end, 2000) -- 2 second delay
end

function M.upload_debug()
	-- Debug upload process for UNO R4 WiFi
	gui.show_in_floating_window({ "--- Debugging Arduino UNO R4 WiFi Upload ---" })

	-- Check board detection
	gui.show_in_floating_window({ "Checking board detection..." })
	vim.fn.jobstart("arduino-cli board list", {
		stdout_buffered = false,
		on_stdout = function(_, data)
			if data then
				gui.show_in_floating_window(data)
			end
		end,
		on_exit = function()
			-- Try to touch the port to see if it's accessible
			gui.show_in_floating_window({ "Testing port access..." })
			vim.fn.jobstart("stty -f " .. _ArduinoConfigValues.port, {
				stdout_buffered = false,
				on_stdout = function(_, data)
					if data then
						gui.show_in_floating_window(
							{ "Port " .. _ArduinoConfigValues.port .. " accessible: " .. table.concat(data, " ") }
						)
					end
				end,
				on_stderr = function(_, data)
					if data then
						gui.show_in_floating_window({ "Port error: " .. table.concat(data, " ") })
					end
				end,
				on_exit = function()
					-- Try verbose upload
					gui.show_in_floating_window({ "Attempting verbose upload..." })
					local verbose_cmd = "arduino-cli upload -p "
						.. _ArduinoConfigValues.port
						.. " --fqbn "
						.. _ArduinoConfigValues.board
						.. " --verbose "
            .. vim.fn.shellescape(vim.fn.expand("%:p:h"))
					vim.fn.jobstart(verbose_cmd, {
						stdout_buffered = false,
						on_stdout = function(_, data)
							if data then
								gui.show_in_floating_window(data)
							end
						end,
						on_stderr = function(_, data)
							if data then
								gui.show_in_floating_window(data)
							end
						end,
					})
				end,
			})
		end,
	})
end

return M
