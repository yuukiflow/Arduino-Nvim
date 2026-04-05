local commands = require("Arduino-Nvim.commands")
local b_config = require("Arduino-Nvim.board_config")
local M = {}

function M.select_board_gui(callback)
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

function M.select_port_gui()
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

return M
