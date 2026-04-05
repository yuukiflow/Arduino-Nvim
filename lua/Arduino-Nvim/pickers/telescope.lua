local b_config = require("Arduino-Nvim.board_config")
local commands = require("Arduino-Nvim.commands")
local lib_manager = require("Arduino-Nvim.libGetter")

local M = {}
function M.select_board(callback)
  -- call get_boards to get a list of boards
  local boards = commands.get_boards()
  if not boards or #boards == 0 then
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
						b_config.set_board(selection.value) -- Use the selected FQBN
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

function M.select_port()
  local ports = commands.get_ports()
  if not ports or #ports == 0 then
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
						b_config.set_com(selection[1])
					end
					require("telescope.actions").close(prompt_bufnr)
				end)
				return true
			end,
		})
		:find()
end

-- Main GUI function to link board and port selection
function M.select_board_and_port()
	M.select_board(function()
		-- Only try to select port if there might be connected devices
		local handle = io.popen("arduino-cli board list")
		if handle then
			local result = handle:read("*a")
			handle:close()
			-- Check if any ports are listed
			if result:match("^/dev/tty") or result:match("^COM") then
				M.select_port()
			else
				vim.notify("No Arduino boards connected. Skipping port selection.", vim.log.levels.INFO)
			end
		else
			vim.notify("Failed to check for connected boards.", vim.log.levels.WARN)
		end
	end)
end

-- Library manager function with Telescope integration
function M.open_library_manager()
  local library_names, installed_libs, outdated_libs = lib_manager.library_manager()
  if not library_names or #library_names == 0 then
    return
  end

  local function entry_maker(entry)
    if entry and entry.display_name and entry.lib_name then
      local icon = "+"
      if installed_libs[entry.lib_name] then
        icon = "✓"
      end
      if outdated_libs[entry.lib_name] then
        icon = "↑"
      end

      return {
        value = entry,
        display = icon .. " " .. entry.display_name,
        ordinal = (entry.hidden_tag or "") .. " " .. entry.lib_name,
        lib_name = entry.lib_name,
      }
    else
      vim.notify("Error: entry nil", vim.log.levels.ERROR)
      return nil
    end
  end

  require("telescope.pickers")
  .new({}, {
    prompt_title = "Arduino Libraries",
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
        if not selection then return end

        local lib_name = selection.lib_name
        local cmd
        local message

        if installed_libs[lib_name] and not outdated_libs[lib_name] then
          cmd = 'arduino-cli lib uninstall "' .. lib_name .. '" > /dev/null 2>&1'
          message = "Library '" .. lib_name .. "' uninstalled."
        elseif outdated_libs[lib_name] then
          cmd = 'arduino-cli lib install "' .. lib_name .. '" > /dev/null 2>&1'
          message = "Library '" .. lib_name .. "' updated."
        else
          cmd = 'arduino-cli lib install "' .. lib_name .. '" > /dev/null 2>&1'
          message = "Library '" .. lib_name .. "' installed."
        end

        os.execute(cmd)
        vim.notify(message, vim.log.levels.INFO)

        actions.close(prompt_bufnr)
        M.open_library_manager()
      end)

      return true
    end,
  })
  :find()
end

return M
