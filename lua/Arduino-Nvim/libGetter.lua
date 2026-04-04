-- Use vim.json directly (available in Neovim 0.9+)
-- This eliminates the need for custom JSON implementation
local json = vim.json
	or {
		decode = function(_)
			error("JSON decode not available: requires Neovim 0.9+")
		end,
		encode = function(_)
			error("JSON encode not available: requires Neovim 0.9+")
		end,
	}
local cache_file = vim.fn.stdpath("cache") .. "/arduino_libs.json"
local cache_expiration = 7 * 24 * 60 * 60 -- Cache expires in 7 days

local M = {}

-- Function to fetch libraries from Arduino CLI and store in cache
local function fetch_and_cache_libraries()
	vim.notify("Fetching libraries from arduino-cli...", vim.log.levels.INFO)
	local handle = io.popen("arduino-cli lib search --format json")
	if not handle then
		vim.notify("Failed to execute arduino-cli lib search", vim.log.levels.ERROR)
		return nil
	end
	local result = handle:read("*a")
	handle:close()

	local ok, lib_data = pcall(json.decode, result)
	if ok and lib_data then
		vim.notify("Successfully parsed libraries from JSON.", vim.log.levels.INFO)
		-- Save to cache file
		local cache_handle = io.open(cache_file, "w")
		if cache_handle then
			cache_handle:write(json.encode(lib_data))
			cache_handle:close()
		else
			vim.notify("Failed to write cache file", vim.log.levels.ERROR)
		end
		return lib_data
	else
		vim.notify("Failed to fetch libraries or parse JSON.", vim.log.levels.ERROR)
		return nil
	end
end

-- Load libraries from cache or fetch if expired
local function load_libraries_from_cache()
	local cache_stat = vim.uv.fs_stat(cache_file)
	if cache_stat and (os.time() - cache_stat.mtime.sec) < cache_expiration then
		vim.notify("Loading libraries from cache.", vim.log.levels.INFO)
		local cache_handle = io.open(cache_file, "r")
		if not cache_handle then
			vim.notify("Failed to open cache file", vim.log.levels.ERROR)
			return fetch_and_cache_libraries()
		end
		local cache_content = cache_handle:read("*a")
		cache_handle:close()
		local ok, lib_data = pcall(json.decode, cache_content)
		if ok and lib_data then
			vim.notify("Successfully loaded libraries from cache.", vim.log.levels.INFO)
			return lib_data
		else
			vim.notify("Failed to parse cached libraries.", vim.log.levels.ERROR)
		end
	end
	vim.notify("Cache expired or missing, fetching new data.", vim.log.levels.INFO)
	return fetch_and_cache_libraries()
end

-- Fetch list of installed libraries
local function get_installed_libraries()
	local handle = io.popen("arduino-cli lib list --format json")
	if not handle then
		vim.notify("Failed to execute arduino-cli lib list", vim.log.levels.ERROR)
		return {}
	end
	local result = handle:read("*a")
	handle:close()

	local ok, installed_data = pcall(json.decode, result)
	local installed_libs = {}

	if ok and installed_data and installed_data.installed_libraries then
		for _, entry in ipairs(installed_data.installed_libraries) do
			if entry.library and entry.library.name then
				installed_libs[entry.library.name] = entry.library.version -- Store version for comparison
			end
		end
	else
		vim.notify("Failed to fetch installed libraries.", vim.log.levels.ERROR)
	end

	return installed_libs
end

-- Fetch libraries with available updates
local function get_libraries_with_updates()
	local handle = io.popen("arduino-cli outdated --format json")
	if not handle then
		vim.notify("Failed to execute arduino-cli outdated", vim.log.levels.ERROR)
		return {}
	end
	local result = handle:read("*a")
	handle:close()

	local ok, outdated_data = pcall(json.decode, result)
	local outdated_libs = {}

	if ok and outdated_data and outdated_data.libraries then
		for _, lib_entry in ipairs(outdated_data.libraries) do
			local lib_info = lib_entry.library
			local lib_name = lib_info and lib_info.name
			local latest_version = lib_entry.release and lib_entry.release.version

			if lib_name and latest_version then
				outdated_libs[lib_name] = latest_version -- Store latest version for display
			else
				vim.notify("Warning: Missing lib_name or latest_version for entry", vim.log.levels.WARN)
			end
		end
	else
		vim.notify("Failed to fetch outdated libraries.", vim.log.levels.ERROR)
	end

	return outdated_libs
end

-- Function to update and reopen Telescope picker with tick marks
local function update_library_picker()
	M.library_manager_gui() -- Reload the library manager to reflect changes
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

-- Library manager function with Telescope integration
function M.library_manager_gui()
  local library_names, installed_libs, outdated_libs = M.library_manager()
  if not library_names or #library_names == 0 then
    return
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
          update_library_picker() -- Reopen picker with updated status
        end
        return true
      end)
      return true
    end,
  })
  :find()
end

-- Main function for library management
function M.library_manager()
	local libraries_data = load_libraries_from_cache()
	local libraries = libraries_data and libraries_data.libraries

  -- Early return, easy to read
  if not libraries or #libraries == 0 then
		vim.notify("No libraries found.", vim.log.levels.WARN)
    return
  end

  local library_names = {}

  -- Get the list of currently installed libraries
  local installed_libs = get_installed_libraries()
  local outdated_libs = get_libraries_with_updates()

  for _, lib in ipairs(libraries) do
    if lib.name then
      local display_name = lib.name
      local tag = "[uninstalled]" -- Default tag

      if installed_libs[lib.name] then
        display_name = "✅ " .. display_name -- Add tick mark for installed libs
        tag = "[installed]"

        if outdated_libs[lib.name] then
          display_name = "🔄 " .. display_name -- Append update available icon
          tag = "[outdated]"
        end
      end

      -- Insert each library with display name, hidden tag, and actual lib_name
      table.insert(library_names, {
        display_name = display_name,
        hidden_tag = tag,
        lib_name = lib.name,
      })
    end
  end

  return library_names, installed_libs, outdated_libs
end

-- Run library fetch on startup only if cache is expired
--[[ vim.api.nvim_create_autocmd("BufReadPost", {
    pattern = "*.ino",
    callback = function()
        load_libraries_from_cache()
    end,
})]]

-- Create Neovim command to open the library manager
vim.api.nvim_create_user_command("InoLib", function()
	M.library_manager_gui()
end, {})

-- Return M to make it accessible
return M
