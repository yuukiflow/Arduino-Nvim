-- gui file is intended to save all the code that
-- is used to create a gui experience like floating
-- windows or display selectors
local b_config = require("Arduino-Nvim.board_config")
local utils = require("Arduino-Nvim.utils")
local lib_manager = require("Arduino-Nvim.libGetter")
local M = {}

function M.arduino_board_list_gui()
	-- Check if arduino-cli is available
	if not utils.check_arduino_cli() then
		return
	end

	local buf, win, opts = utils.create_floating_cli_monitor()
	-- list all available ports1
	local handle = io.popen("arduino-cli board list")
	if not handle then
		vim.notify("Error: Failed to execute arduino-cli board list", vim.log.levels.ERROR)
		return
	end
	local result = handle:read("*a")
	handle:close()
	utils.append_to_buffer({ result }, buf, win, opts)
end

-- Library manager function with Telescope integration
function M.library_manager_gui()
  local library_names, installed_libs, outdated_libs = lib_manager.library_manager()
  if not library_names or #library_names == 0 then
    return
  end

  -- Custom entry maker function to include only name and tag in `ordinal`
  local function entry_maker(entry)
    if entry and entry.display_name and entry.lib_name then
      return {
        value = entry.display_name,
        display = entry.display_name, -- Show name with markers
        ordinal = entry.hidden_tag .. " " .. entry.lib_name, -- Use tag and lib_name for searchability
        lib_name = entry.lib_name, -- Store actual library name
      }
    else
      vim.notify("Error: entry or entry.display_name or entry.lib_name is nil", vim.log.levels.ERROR)
      return nil
    end
  end

  require("telescope.pickers")
  .new({}, {
    prompt_title = "Available Arduino Libraries",
    finder = require("telescope.finders").new_table({
      results = library_names,
      entry_maker = entry_maker,
    }),
    sorter = require("telescope.config").values.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")

      map("i", "<CR>", function()
        local selection = action_state.get_selected_entry()
        if selection then
          local lib_name = selection.lib_name -- Use the actual library name
          local cmd

          if outdated_libs[lib_name] then
            -- Update the library if an update is available
            cmd = 'arduino-cli lib install "' .. lib_name .. '" > /dev/null 2>&1'
            os.execute(cmd)
            vim.notify("Library '" .. lib_name .. "' updated successfully.", vim.log.levels.INFO)
          else
            -- Install the library if it's not installed
            cmd = 'arduino-cli lib install "' .. lib_name .. '" > /dev/null 2>&1'
            os.execute(cmd)
            vim.notify("Library '" .. lib_name .. "' installed successfully.", vim.log.levels.INFO)
          end

          -- Refresh the picker with updated tick mark and update status
          actions.close(prompt_bufnr)
          M.library_manager_gui() -- Reopen picker with updated status
        end
        return true
      end)
      return true
    end,
  })
  :find()
end

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

	-- Create a buffer for the floating window
	local buf = vim.api.nvim_create_buf(false, true)

	-- Define initial window options to position it at the bottom
	local win_opts = {
		relative = "editor",
		width = width,
		height = height,
		row = vim.o.lines - height - 2, -- Position at the bottom
		col = 0,
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

  append_to_buffer(data)
end

return M
