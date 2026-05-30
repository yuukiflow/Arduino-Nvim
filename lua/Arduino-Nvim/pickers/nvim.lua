local b_config = require("Arduino-Nvim.board_config")
local commands = require("Arduino-Nvim.commands")
local lib_manager = require("Arduino-Nvim.libGetter")
local M = {}

function M.select_board()
  local boards = commands.get_boards()
  if #boards == 0 then
    return
  end
  vim.ui.select(boards, {
    prompt = 'Select board:',
    format_item = function(item)
      return item.display
    end
  }, function(choice)
    b_config.set_board(choice.fqbn)
  end)
end

function M.select_port()
  local ports = commands.get_ports_v2()
  if #ports == 0 then
    return
  end
  vim.ui.select(ports, {
    prompt = 'Select port:',
    format_item = function(item)
      return item.name .. " - " .. item.address
    end
  }, function(choice)
    b_config.set_com(choice.address)
  end)
end

function M.select_board_and_port()
  local boards = commands.get_boards()
  if #boards == 0 then
    return
  end

  local ports = commands.get_ports_v2()
  if #ports == 0 then
    return
  end

  vim.ui.select(boards, {
    prompt = 'Select board:',
    format_item = function(item)
      return item.display
    end
  }, function(board_choice)
    if not board_choice then
      return
    end

    vim.cmd("redraw") -- for builtin inputlist

    vim.ui.select(ports, {
      prompt = 'Select port:',
      format_item = function(item)
        return item.name .. " - " .. item.address
      end
    }, function(port_choice)
      if not port_choice then
        return
      end

      b_config.set_board(board_choice.fqbn)
      b_config.set_com(port_choice.address)
    end)
  end)
end

function M.open_library_manager()
  local lib_names, installed_libs, outdated_libs = lib_manager.library_manager()
  vim.notify("This backend does not support large amount of data, to search and install other libraries, please use another backend, only showing installed and outdated libraries")
  vim.notify("Installed libraries: "..vim.inspect(installed_libs))
  vim.notify("Outdated libraries: "..vim.inspect(outdated_libs))
end

return M
