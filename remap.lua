vim.keymap.set("n", "<Leader>au", ":InoUpload<CR>", { silent = true })  -- Upload code
vim.keymap.set("n", "<Leader>ac", ":InoCheck<CR>", { silent = true })   -- Compile/check code
vim.keymap.set("n", "<Leader>as", ":InoStatus<CR>", { silent = true })  -- Show current board and port status
vim.keymap.set("n", "<Leader>ag", ":InoGUI<CR>", { silent = true })     -- Open GUI for setting board and port
vim.keymap.set("n", "<Leader>am", ":InoMonitor<CR>", { silent = true })     -- Open Serial monitor with default port and baud rate
vim.keymap.set("n", "<Leader>al", ":InoLib<CR>", { silent = true })
vim.keymap.set("n", "<Leader>ab", ":InoSelectBoard<CR>", { silent = true })     -- open board selection gui
vim.keymap.set("n", "<Leader>ap", ":InoSelectPort<CR>", { silent = true }) -- open board selection gui


vim.keymap.set("n", "<Esc>", function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_config(win).relative == "editor" then
            vim.api.nvim_win_close(win, false)
        end
    end
end, { silent = true , noremap = true })
