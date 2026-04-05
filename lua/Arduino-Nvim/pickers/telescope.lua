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
          M.open_library_manager() -- Reopen picker with updated status
        end
        return true
      end)
      return true
    end,
  })
  :find()
end

return M
