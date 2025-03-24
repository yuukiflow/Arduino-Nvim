# Arduino-Nvim

A Neovim plugin that provides Arduino IDE-like functionality directly in your editor. This plugin integrates Arduino development tools with Neovim, offering a seamless development experience for Arduino projects.

## Features

- Arduino project compilation and verification
- Code upload to Arduino boards
- Serial monitor with writeable interface
- Board and port management
- Library management with Telescope integration
- LSP support for Arduino development
- Real-time status monitoring

## Requirements

- [arduino-cli](https://arduino.github.io/arduino-cli/) (latest stable version)
- [arduino-language-server](https://github.com/arduino/arduino-language-server) (patched version required - see [Patch](https://github.com/arduino/arduino-language-server/issues/187#issuecomment-2241641098))
- [clangd](https://clangd.llvm.org/) (latest stable version)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)

## Installation

1. Clone the repository:
```sh
git clone https://github.com/yuukiflow/Arduino-Nvim.git ~/.config/nvim/lua/Arduino-Nvim
```

2. Add the following to your `init.lua`:
```lua
-- Load LSP configuration first
require("Arduino-Nvim.lsp").setup()

-- Set up Arduino file type detection
vim.api.nvim_create_autocmd("FileType", {
    pattern = "arduino",
    callback = function()
        require("Arduino-Nvim")
    end
})
```

## Usage

All commands are prefixed with `<leader>a` followed by a single letter indicating the action:

| Command | Description |
|---------|-------------|
| `<leader>ac` | Compile and verify the current sketch |
| `<leader>au` | Upload sketch to board (configures port and FQBN) |
| `<leader>am` | Open serial monitor in a floating terminal |
| `<leader>as` | Display current board, port, and FQBN status |
| `<leader>al` | Open library manager (Telescope interface) |
| `<leader>ap` | List available ports |
| `<leader>ab` | List available boards |

### Serial Monitor Configuration

Set the baudrate for the serial monitor using:
```
:InoSetBaudrate 115200
```
Default baudrate is 115200 if not specified.


## License

This project is licensed under the MIT License - see the LICENSE file for details.
