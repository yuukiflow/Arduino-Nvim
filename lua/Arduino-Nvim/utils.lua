local M = {}

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

-- Function to dynamically adjust the floating window height based on buffer content
local function adjust_window_height(win, buf, opts)
	local line_count = vim.api.nvim_buf_line_count(buf)
	local new_height = math.min(line_count, vim.o.lines - 2) -- Max height limited to screen size

	-- Update window height and reposition if necessary to keep it at the bottom
	opts.height = new_height
	opts.row = vim.o.lines - new_height - 2
	vim.api.nvim_win_set_config(win, opts)
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
