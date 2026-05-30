local b_config = require("Arduino-Nvim.board_config")
local commands = require("Arduino-Nvim.commands")
local lib_manager = require("Arduino-Nvim.libGetter")
local M = {}

function M.select_board()
  local boards = commands.get_boards()
  if #boards == 0 then return end

  require('snacks.picker').pick({
    title = "Select Board",
    items = boards,
    format = function(item)
      return { text = item.display }
    end,
    confirm = function(picker, item)
      picker:close()
      b_config.set_board(item.fqbn)
    end,
  })
end

function M.select_port()
  local ports = commands.get_ports_v2()
  if #ports == 0 then return end

  require('snacks.picker').pick({
    title = "Select Port",
    items = ports,
    format = function(item)
      return { text = item.name .. " - " .. item.address }
    end,
    confirm = function(picker, item)
      picker:close()
      b_config.set_com(item.address)
    end,
  })
end

function M.select_board_and_port()
  local boards = commands.get_boards()
  local ports = commands.get_ports_v2()

  if #boards == 0 or #ports == 0 then return end

  require('snacks.picker').pick({
    title = "Select Board",
    items = boards,
    format = function(item)
      return { text = item.display }
    end,
    confirm = function(picker, board)
      picker:close()

      require('snacks.picker').pick({
        title = "Select Port",
        items = ports,
        format = function(item)
          return { text = item.name .. " - " .. item.address }
        end,
        confirm = function(picker2, port)
          picker2:close()
          b_config.set_board(board.fqbn)
          b_config.set_com(port.address)
        end,
      })
    end,
  })
end

function M.open_library_manager()
  local library_names, installed_libs, outdated_libs = lib_manager.library_manager()
  if not library_names or #library_names == 0 then return end

  require('snacks.picker').pick({
    title = "Arduino Libraries",
    items = library_names,

    format = function(entry)
      local icon = "+"
      if installed_libs[entry.lib_name] then
        icon = "✓"
      end
      if outdated_libs[entry.lib_name] then
        icon = "↑"
      end

      return {
        text = icon .. " " .. entry.display_name,
      }
    end,

    search = function(entry)
      return (entry.hidden_tag or "") .. " " .. entry.lib_name
    end,

    confirm = function(picker, entry)
      picker:close()

      local lib_name = entry.lib_name
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
      vim.notify(message)

      vim.defer_fn(function()
        M.open_library_manager()
      end, 100)
    end,
  })
end

return M
