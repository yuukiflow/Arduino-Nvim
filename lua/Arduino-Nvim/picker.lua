local M = {}

local config = {
	picker = nil, -- 'telescope' | 'snacks' | 'mini' | nil (auto)
}

local available_pickers = {
	{ id = "telescope", module = "telescope.pickers" },
	{ id = "snacks", module = "snacks" },
	{ id = "mini", module = "mini.pick" },
}

function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})
end

function M.get_backend()
	if config.picker then
		return config.picker
	end

	for _, picker in ipairs(available_pickers) do
		local ok = pcall(require, picker.module)
		if ok then
			return picker.id
		end
	end
	return nil
end

local backends = {}

local function get_display(item)
	if type(item) == "string" then
		return item
	end
	return item.display or item.text or item.label or item.name or tostring(item)
end

backends.snacks = function(opts)
	local ok, snacks = pcall(require, "snacks")
	if not ok then
		return vim.notify("snacks.nvim not installed", vim.log.levels.ERROR)
	end

	-- Prepare items for snacks: ensure 'text' is present for searching
	local items = {}
	for _, item in ipairs(opts.items) do
		local snack_item = { item = item }
		if type(item) == "table" then
			snack_item.text = item.text or get_display(item)
		else
			snack_item.text = tostring(item)
		end

		table.insert(items, snack_item)
	end

	snacks.picker({
		title = opts.title,
		items = items,
		layout = "select",
		format = function(item)
			-- item.item is now guaranteed to exist
			return { { get_display(item.item) } }
		end,
		confirm = function(picker, item)
			picker:close()
			-- item.item is now guaranteed to exist
			if item and opts.on_select then
				opts.on_select(item.item)
			end
		end,
	})
end
backends.mini = function(opts)
	local ok, mini_pick = pcall(require, "mini.pick")
	if not ok then
		return vim.notify("mini.pick not installed", vim.log.levels.ERROR)
	end

	-- 1. Pre-process items so mini.pick can natively search and display them
	local items = {}
	for _, item in ipairs(opts.items) do
		local pick_item = { item = item } -- Preserve original data

		if type(item) == "table" then
			-- Ensure there is a text field for mini.pick to display/match
			pick_item.text = item.text or get_display(item)
		else
			pick_item.text = tostring(item)
		end

		table.insert(items, pick_item)
	end

	-- 2. Start the picker
	mini_pick.start({
		source = {
			name = opts.title,
			items = items,
			-- DO NOT override `show`.
			-- mini.pick will automatically display and fuzzy-match against the `text` field we just created.
			choose = function(selected)
				if selected and opts.on_select then
					-- Pass the preserved original item back to the callback
					opts.on_select(selected.item)
				end
			end,
		},
	})
end

backends.telescope = function(opts)
	local ok, telescope = pcall(require, "telescope.pickers")
	if not ok then
		return vim.notify("telescope.nvim not installed", vim.log.levels.ERROR)
	end

	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	telescope
		.new({}, {
			prompt_title = opts.title,
			finder = finders.new_table({
				results = opts.items,
				entry_maker = function(entry)
					local display = get_display(entry)
					local ordinal

					-- FIX: Safely determine the ordinal based on data type
					if type(entry) == "table" then
						-- Fallback chain: Explicit ordinal -> explicit text -> rendered display
						ordinal = entry.ordinal or entry.text or display
					else
						ordinal = display
					end

					return {
						value = entry, -- Preserves the original item perfectly
						display = display,
						ordinal = ordinal,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr, map)
				local function select_entry()
					local selection = action_state.get_selected_entry()
					if selection then
						actions.close(prompt_bufnr)
						if opts.on_select then
							-- selection.value correctly passes the original item back
							opts.on_select(selection.value)
						end
					end
					return true
				end
				map("i", "<CR>", select_entry)
				map("n", "<CR>", select_entry)
				return true
			end,
		})
		:find()
end

--- Main entry point
---@param opts table { items = table, on_select = function, title = string }
function M.open(opts)
	opts.title = opts.title or "Select"

	local backend_id = M.get_backend()
	local backend_fn = backends[backend_id]
	if backend_fn then
		backend_fn(opts)
	else
		-- Fallback to vim.ui.select
		vim.ui.select(opts.items, {
			prompt = opts.title,
			format_item = get_display,
		}, function(item)
			if item and opts.on_select then
				opts.on_select(item)
			end
		end)
	end
end

return M
