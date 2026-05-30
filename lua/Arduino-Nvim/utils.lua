local M = {}

-- Helper function to find executable in PATH
function M.find_executable(name)
	local path = vim.fn.exepath(name)
	if path and path ~= "" then
		return path
	end
	return nil
end

-- Utility function to strip ANSI escape codes
function M.strip_ansi_codes(line)
	return line:gsub("\27%[[0-9;]*m", "")
end

-- Helper function to split a string by newlines
function M.split_string_by_newlines(input)
	local result = {}
	for line in input:gmatch("[^\r\n]+") do
		table.insert(result, line)
	end
	return result
end

-- Helper function to check if arduino-cli is available
function M.check_arduino_cli()
	if vim.fn.exepath("arduino-cli") == "" then
		vim.notify("Error: arduino-cli not found in PATH. Please install it first.", vim.log.levels.ERROR)
		return false
	end
	return true
end


function M.trim(s)
	return s:match("^%s*(.-)%s*$")
end

return M
