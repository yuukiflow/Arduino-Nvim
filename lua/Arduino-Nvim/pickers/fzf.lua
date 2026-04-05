local b_config = require("Arduino-Nvim.board_config")
local commands = require("Arduino-Nvim.commands")
local lib_manager = require("Arduino-Nvim.libGetter")
local M = {}

function M.select_board()
  local boards = commands.get_boards()
  if #boards == 0 then
    return
  end

  local items = {}
  local map = {}
  for i, board in ipairs(boards) do
    local line = board.display
    table.insert(items, line)
    map[line] = board
  end

  require('fzf-lua').fzf_exec(items, {
    prompt = "Select board> ",
    actions = {
      ["default"] = function(selected)
        local choice = map[selected[1]]
        if choice then
          b_config.set_board(choice.fqbn)
        end
      end
    }
  })
end

function M.select_port()
  local ports = commands.get_ports_v2()
  if #ports == 0 then
    return
  end

  local items = {}
  local map = {}

  for _, port in ipairs(ports) do
    local line = port.name .. " - " .. port.address
    table.insert(items, line)
    map[line] = port
  end

  require('fzf-lua').fzf_exec(items, {
    prompt = "Select port> ",
    actions = {
      ["default"] = function(selected)
        local choice = map[selected[1]]
        if choice then
          b_config.set_com(choice.address)
        end
      end
    }
  })
end

function M.select_board_and_port()
  local boards = commands.get_boards()
  local ports = commands.get_ports_v2()

  if #boards == 0 or #ports == 0 then
    return
  end

  local board_items = {}
  local board_map = {}

  for _, board in ipairs(boards) do
    table.insert(board_items, board.display)
    board_map[board.display] = board
  end

  local port_items = {}
  local port_map = {}

  for _, port in ipairs(ports) do
    local line = port.name .. " - " .. port.address
    table.insert(port_items, line)
    port_map[line] = port
  end

  require('fzf-lua').fzf_exec(board_items, {
    prompt = "Select board> ",
    actions = {
      ["default"] = function(selected_board)
        local board = board_map[selected_board[1]]
        if not board then return end

        -- Segundo picker
        require('fzf-lua').fzf_exec(port_items, {
          prompt = "Select port> ",
          actions = {
            ["default"] = function(selected_port)
              local port = port_map[selected_port[1]]
              if not port then return end

              b_config.set_board(board.fqbn)
              b_config.set_com(port.address)
            end
          }
        })
      end
    }
  })
end

function M.open_library_manager()
  local library_names, installed_libs, outdated_libs = lib_manager.library_manager()
  if not library_names or #library_names == 0 then
    return
  end

  local items = {}

  for _, entry in ipairs(library_names) do
    if entry and entry.display_name and entry.lib_name then
      local icon = "+"
      if installed_libs[entry.lib_name] then
        icon = "✓"
      end
      if outdated_libs[entry.lib_name] then
        icon = "↑"
      end

      local display = icon .. " " .. entry.display_name

      local line = string.format(
        "%s|%s %s|%s",
        display,                
        entry.hidden_tag or "",
        entry.lib_name,         
        entry.lib_name          
      )

      table.insert(items, line)
    end
  end

  require('fzf-lua').fzf_exec(items, {
    prompt = "Arduino Libraries> ",
    fzf_opts = {
      ["--delimiter"] = "|",
      ["--with-nth"] = "1",
    },
    actions = {
      ["default"] = function(selected)
        local line = selected[1]
        local lib_name = line:match("|([^|]+)$")
        if not lib_name then return end

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
      end
    }
  })
end

return M
