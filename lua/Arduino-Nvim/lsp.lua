local utils = require("Arduino-Nvim.utils")
local M = {}

-- Check or create sketch.yaml with correct fqbn and port
local function check_or_create_sketch_yaml()
	local yaml_file = "sketch.yaml"
	local ino_files = vim.fn.glob("*.ino", false, true)
	if #ino_files == 0 then
		-- No .ino files found, do not proceed
		return
	end
	-- Load current config for board and port
	local board = _ArduinoConfigValues.board
	local port = _ArduinoConfigValues.port

	-- Check if sketch.yaml exists
	if vim.fn.filereadable(yaml_file) == 0 then
		-- If not, create sketch.yaml with default settings
		vim.notify("sketch.yaml not found. Creating with default settings.", vim.log.levels.INFO)
		local file = io.open(yaml_file, "w")
		if file then
			file:write("fqbn: " .. board .. "\n")
			file:write("port: " .. port .. "\n")
			file:close()
		end
	else
		-- Read existing file and check if fqbn and port match the config
		local current_yaml = {}
		for line in io.lines(yaml_file) do
			local key, value = line:match("(%S+):%s*(%S+)")
			if key and value then
				current_yaml[key] = value
			end
		end

		-- Update fqbn or port if they differ from config
		if current_yaml["default_fqbn"] ~= board or current_yaml["default_port"] ~= port then
			vim.notify("Updating fqbn or port in sketch.yaml to match config.", vim.log.levels.INFO)
			local file = io.open(yaml_file, "w")
			if file then
				file:write("default_fqbn: " .. board .. "\n")
				file:write("default_port: " .. port .. "\n")
				file:close()
			else
				vim.nofify("Error: Cannot update sketch file.", vim.log.levels.ERROR)
			end
		end
	end
end

-- Set up the Arduino language server with saved configuration
function M.setup_arduino_lsp()
	check_or_create_sketch_yaml()
	local board = _ArduinoConfigValues.board or "arduino:avr:uno" -- Default fallback

	-- Find required executables
	local clangd_path = utils.find_executable("clangd") or "/usr/bin/clangd"
	local arduino_cli_config = vim.fn.expand("$HOME/.arduino15/arduino-cli.yaml")

	-- Check if arduino-language-server is available
	if not utils.find_executable("arduino-language-server") then
		vim.notify("Error: arduino-language-server not found in PATH. Please install it.", vim.log.levels.ERROR)
		return
	end

  lspconfig_table = {}
  lspconfig_table["cmd"] = {
    "arduino-language-server",
    "-cli",
    "arduino-cli",
    "-cli-config",
    arduino_cli_config,
    "-clangd",
    clangd_path,
    "-fqbn",
    board,
  }
  lspconfig_table['filetypes'] = { "arduino" }


	-- Configure the Arduino language server using loaded settings
  if vim.fn.has('nvim-0.11.0') == 1 then
    local util = require('lspconfig.util')
    vim.lsp.config['arduino-language-server'] = {
      cmd = lspconfig_table["cmd"],
      filetypes = lspconfig_table['filetypes'],
      root_dir = function(bufnr, on_dir)
        local fname = vim.api.nvim_buf_get_name(bufnr)
        on_dir(util.root_pattern('*.ino')(fname))
      end,
      capabilities = {
        textDocument = {
          ---@diagnostic disable-next-line: assign-type-mismatch
          semanticTokens = vim.NIL,
        },
        workspace = {
          ---@diagnostic disable-next-line: assign-type-mismatch
          semanticTokens = vim.NIL,
        },
      },
    }
    vim.lsp.enable('arduino-language-server')
  else
    require("lspconfig").arduino_language_server.setup({
      cmd = lspconfig_table["cmd"],
      filetypes = lspconfig_table["filetypes"],
      root_dir = function(_)
        return vim.fn.getcwd()
      end,
      handlers = {},
    })
  end
end

return M
