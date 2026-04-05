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
  use_lsp = false,
  keymaps = {},
}

local function set_default_commands()
  vim.api.nvim_create_user_command("InoCheck",       commands.compile, {})
  vim.api.nvim_create_user_command("InoMonitor",     commands.monitor, {})
  vim.api.nvim_create_user_command("InoUpload",      commands.upload, {})
  vim.api.nvim_create_user_command("InoUploadSlow",  commands.upload_slow, {})
  vim.api.nvim_create_user_command("InoUploadReset", commands.upload_reset, {})
  vim.api.nvim_create_user_command("InoDebugUpload", commands.upload_debug, {})
  vim.api.nvim_create_user_command("InoGUI",         gui.gui, {})
  vim.api.nvim_create_user_command("InoList",        gui.arduino_board_list_gui, {})
  vim.api.nvim_create_user_command("InoLib",         gui.library_manager_gui, {})
  vim.api.nvim_create_user_command("InoSelectBoard", gui.select_board_gui, {})
  vim.api.nvim_create_user_command("InoSelectPort",  gui.select_port_gui, {})
  vim.api.nvim_create_user_command("InoStatus",      b_config.board_config_status, {})

  vim.api.nvim_create_user_command("InoSetBaud", function(opts)
    b_config.set_baudrate(opts.args)
  end, { nargs = 1 })
end

function M.setup(opts)
  b_config.load_or_create_config()
  remap.load_keymaps(true)
  lsp.setup_arduino_lsp()
  set_default_commands()
end

return M
