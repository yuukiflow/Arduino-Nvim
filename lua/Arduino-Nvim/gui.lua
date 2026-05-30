-- gui file is intended to save all the code that
-- is used to create a gui experience like floating
-- windows or display selectors
local utils = require("Arduino-Nvim.utils")
local M = {}

local floating_window_data = {}
local function close_window_clear_data()
  if floating_window_data.win
    and vim.api.nvim_win_is_valid(floating_window_data.win) then
    vim.api.nvim_win_close(floating_window_data.win, true)
  end

  floating_window_data = {}
end

-- Function to dynamically adjust the floating window height based on buffer content
local function adjust_window_height()
	local line_count = vim.api.nvim_buf_line_count(floating_window_data.buf)
	local new_height = math.min(line_count, vim.o.lines - 2) -- Max height limited to screen size

	-- Update window height and reposition if necessary to keep it at the bottom
	floating_window_data.opts.height = new_height
	floating_window_data.opts.row = vim.o.lines - new_height - 2
	vim.api.nvim_win_set_config(floating_window_data.win, floating_window_data.opts)
end

local function create_floating_window(opts)
  local opts = opts or {}
	local width = opts.width or vim.o.columns -- Full width of the screen
	local height = opts.height or 5 -- Start with a small height (adjustable)
  local row = opts.row or (vim.o.lines - height - 2)
  local col = opts.col or 0

	-- Create a buffer for the floating window
	local buf = vim.api.nvim_create_buf(false, true)

	-- Define initial window options to position it at the bottom
	local win_opts = {
		relative = "editor",
		width = width,
		height = height,
		row = row, -- Position at the bottom
		col = col,
		style = "minimal",
		border = "rounded", -- Optional: add border for visual separation
	}

	-- Create the floating window and store its ID
	local win = vim.api.nvim_open_win(buf, true, win_opts)

  floating_window_data = {
    win = win,
    buf = buf,
    opts = win_opts
  }

  vim.keymap.set("n", "<CR>", close_window_clear_data, {
    buffer = buf,
    noremap = true,
    silent = true,
  })
end

local function append_to_buffer(lines)
	-- Ensure lines is a table, even if a single string is passed
	if type(lines) == "string" then
		lines = { lines }
	end

	-- Split each line in the table by newlines
	local processed_lines = {}
	for _, line in ipairs(lines) do
		local split_lines = utils.split_string_by_newlines(line)
		vim.list_extend(processed_lines, split_lines)
	end

	-- Clean each line to remove ANSI codes and add to the buffer
	local cleaned_lines = vim.tbl_map(utils.strip_ansi_codes, processed_lines)
	vim.api.nvim_buf_set_lines(floating_window_data.buf, -1, -1, false, cleaned_lines)

	-- Adjust the window height if necessary
	adjust_window_height()
end

function M.show_in_floating_window(data, opts)
  if not floating_window_data.win
    or not vim.api.nvim_win_is_valid(floating_window_data.win) then
    create_floating_window(opts)
  end

  if not data then
    return
  end

  append_to_buffer(data)
end

return M
