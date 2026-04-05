local remap = require("Arduino-Nvim.remap")
local commands = require("Arduino-Nvim.commands")
local b_config = require("Arduino-Nvim.board_config")
local gui = require("Arduino-Nvim.gui")
local lsp = require("Arduino-Nvim.lsp")
local M = {}

-- Default config values
_ArduinoConfigValues = {
  config_file = ".arduino_config.lua",
  board = "arduino:avr:uno",
  port = "/dev/ttyUSB0",
  baudrate = 115200,
  use_default_keymaps = true,
  use_default_commands = true,
  keymaps = {},
}

local function set_default_commands()
  vim.api.nvim_create_user_command("InoMonitor",     commands.monitor, {})
  vim.api.nvim_create_user_command("InoUpload",      commands.upload, {})
  vim.api.nvim_create_user_command("InoUploadSlow",  commands.upload_slow, {})
  vim.api.nvim_create_user_command("InoUploadReset", commands.upload_reset, {})
  vim.api.nvim_create_user_command("InoDebugUpload", commands.upload_debug, {})
  -- vim.api.nvim_create_user_command("InoGUI",         gui.gui, {})
  -- vim.api.nvim_create_user_command("InoList",        gui.arduino_board_list_gui, {})
  -- vim.api.nvim_create_user_command("InoLib",         gui.library_manager_gui, {})
  -- vim.api.nvim_create_user_command("InoSelectBoard", gui.select_board_gui, {})
  -- vim.api.nvim_create_user_command("InoSelectPort",  gui.select_port_gui, {})
  vim.api.nvim_create_user_command("InoStatus",      b_config.board_config_status, {})

  vim.api.nvim_create_user_command("InoCheck",       function()
    commands.compile()
  end, {})
  vim.api.nvim_create_user_command("InoSetBaud", function(opts)
    b_config.set_baudrate(opts.args)
  end, { nargs = 1 })
end

local function update_config(opts)
  opts = opts or {}

  for key, value in pairs(opts) do
    if _ArduinoConfigValues[key] == nil then
      vim.notify(string.format(
        'Configuration for "%s" not found, please check supported configs in plugin page',
        key
      ))
    end
    _ArduinoConfigValues[key] = value
  end
end

function M.setup(opts)
  -- Update global config values
  update_config(opts)

  -- load or create board configuration
  b_config.load_or_create_config()

  -- load keymaps
  remap.load_keymaps()

  -- load lsp
  lsp.setup_arduino_lsp()

  -- load default commands
  if _ArduinoConfigValues.use_default_commands then
    set_default_commands()
  end
end

return M
