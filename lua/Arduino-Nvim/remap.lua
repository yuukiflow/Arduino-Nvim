local M = {}

local keymaps = {
  {
    mode = "n",
    key = "<Leader>au",
    func = ":InoUpload<CR>",
    desc = "Upload sketch to board",
  },
  {
    mode = "n",
    key = "<Leader>ac",
    func = ":InoCheck<CR>",
    desc = "Compile and verify current sketch",
  },
  {
    mode = "n",
    key = "<Leader>as",
    func = ":InoStatus<CR>",
    desc = "Display current board, port and FQBN status",
  },
  {
    mode = "n",
    key = "<Leader>ag",
    func = ":InoGUI<CR>",
    desc = "Open GUI for setting board and port (Telescope interface)",
  },
  {
    mode = "n",
    key = "<Leader>am",
    func = ":InoMonitor<CR>",
    desc = "Open serial monitor with configuration display",
  },
  {
    mode = "n",
    key = "<Leader>al",
    func = ":InoLib<CR>",
    desc = "Open library manager (Telescope interface)",
  },
  {
    mode = "n",
    key = "<Leader>ab",
    func = ":InoSelectBoard<CR>",
    desc = "Select Arduino board from available boards (Telescope interface)",
  },
  {
    mode = "n",
    key = "<Leader>ap",
    func = ":InoSelectPort<CR>",
    desc = "Select Arduino port from available ports (Telescope interface)",
  },
  {
    mode = "n",
    key = "<Leader>ar",
    func = ":InoUploadReset<CR>",
    desc = "Upload with manual reset (for UNO R4 WiFi)",
  },
}


function M.load_keymaps(use_default_keymaps)
  vim.keymap.set("n", "<Esc>", function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(win).relative == "editor" then
        vim.api.nvim_win_close(win, false)
      end
    end
  end, { silent = true , noremap = true })

  if _ArduinoConfigValues.use_default_keymaps then
    for _, keymap in pairs(keymaps) do
      vim.keymap.set(keymap.mode or "n", keymap.key, keymap.func, { silent = true })
    end
  end

  if #_ArduinoConfigValues.keymaps > 0 then
    for _, keymap in pairs(_ArduinoConfigValues.keymaps) do
      vim.keymap.set(keymap.mode or "n", keymap.key, keymap.func, keymap.opts or { silent = true })
    end
  end
end

return M
