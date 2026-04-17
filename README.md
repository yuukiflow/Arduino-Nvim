# Arduino-Nvim

A Neovim plugin that provides Arduino IDE-like functionality directly in your editor.
This plugin integrates Arduino development tools with Neovim, offering a seamless
development experience for Arduino projects.

## ✨ Features

- **Arduino project compilation and verification**
- **Code upload to Arduino boards** with reset support for UNO R4 WiFi
- **Serial monitor** with configuration display and clean interface
- **Board and port management** with GUI selection
- **Advanced library management** with Telescope integration
  - Visual indicators for installed libraries (✅)
  - Update detection and management (🔄)
  - Cached library data for faster loading
- **LSP support** for Arduino development
- **Real-time status monitoring**
- **Persistent configuration storage**
- **Debug upload functionality** for troubleshooting

## 📋 Requirements

- [arduino-cli][acli] (latest stable version)
- [arduino-language-server][als]
- [clangd][clangd] (latest stable version)
- picker (either)
    - [telescope.nvim][https://github.com/nvim-telescope/telescope.nvim]
    - [snacks.nvim][https://github.com/folke/snacks.nvim]
    - [mini.pick][https://github.com/nvim-mini/mini.pick]
- [nvim-lspconfig][nvim-lspconfig]


## 🚀 Installation

### 🚀 Neovim 0.12+

Add this to your `lua/plugins/arduino.lua`:

```lua
vim.pack.add({
  { src = "https://github.com/yuukiflow/Arduino-Nvim" },
  -- dependencies
  { src = "https://github.com/nvim-telescope/telescope.nvim" },
  -- { src = "https://github.com/folke/snacks.nvim" },
  -- { src = "https://github.com/nvim-mini/mini.pick" },
  { src = "https://github.com/neovim/nvim-lspconfig" },
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "arduino",
  callback = function()
	vim.cmd.packadd("Arduino-Nvim")
	require("Arduino-Nvim").setup({ 
      picker = "telescope" -- 'telescope' | 'snacks' | 'mini' (mini.pick) | nil (auto)
    })
  end,
  once = true,
})
```

### 🚀 Lazy.nvim

Add this to your `lua/plugins/arduino.lua`:

```lua
return {
  "yuukiflow/Arduino-Nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "neovim/nvim-lspconfig",
  },
  config = function()
    -- Load Arduino plugin for .ino files
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "arduino",
      callback = function()
        -- defaults to available picker if not set
        require("Arduino-Nvim")
      end,
    })
  end,
}
```

### Local Development Setup

If you're developing locally:

```lua
return {
  dir = vim.fn.stdpath("config") .. "/lua/Arduino-Nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "neovim/nvim-lspconfig",
  },
  config = function()
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "arduino",
      callback = function()
        require("Arduino-Nvim")
      end,
    })
  end,
}
```

## 🎮 Keymaps

All commands are prefixed with `<Leader>a` followed by a single letter:

| Keymap | Command | Description |
|--------|---------|-------------|
| `<Leader>ac` | `:InoCheck` | Compile and verify current sketch |
| `<Leader>au` | `:InoUpload` | Upload sketch to board |
| `<Leader>ar` | `:InoUploadReset` | Upload with manual reset (for UNO R4 WiFi) |
| `<Leader>am` | `:InoMonitor` | Open serial monitor with configuration display |
| `<Leader>as` | `:InoStatus` | Display current board, port, and FQBN status |
| `<Leader>al` | `:InoLib` | Open library manager (Telescope interface) |
| `<Leader>ag` | `:InoGUI` | Open GUI for setting board and port |
| `<Leader>ap` | `:InoSelectPort` | Select Arduino port from available ports |
| `<Leader>ab` | `:InoSelectBoard` | Select Arduino board from available boards |

## 🔧 Additional Commands

| Command | Description |
|---------|-------------|
| `:InoDebugUpload` | Debug upload process with detailed information |
| `:InoList` | List all available Arduino ports |
| `:InoSetBaud <rate>` | Set serial monitor baudrate (e.g. `:InoSetBaud 9600`) |

## ⚙️ Configuration

The plugin automatically creates and manages a `.arduino_config.lua` file in your
project directory to store:

- Board type (FQBN)
- Port selection  
- Baudrate settings

### Example Configuration File

```lua
return {
  board = "arduino:renesas_uno:unor4wifi",
  port = "/dev/ttyACM0", 
  baudrate = "9600",
}
```

### Serial Monitor

The serial monitor shows:

- Board configuration details
- Port settings (baudrate, bits, parity, etc.)
- Real-time Arduino output
- Clean exit with `Ctrl-C` or `Esc`

### Upload Troubleshooting

For Arduino UNO R4 WiFi upload issues:

1. **Try reset upload**: `<Leader>ar` or `:InoUploadReset`
2. **Debug upload**: `:InoDebugUpload` for detailed information
3. **Manual reset**: Hold reset button 8-10 seconds, then immediately upload
4. **Check connection**: Ensure USB cable is properly connected
5. Use a good quality USB cable, cheap cables gave me problems

### Library Manager

The library manager provides a Telescope interface with:

- ✅ Visual indicators for installed libraries
- 🔄 Update detection for outdated libraries  
- One-click installation and updates
- Cached library data for improved performance
- Search and filter capabilities

## 🛠️ LSP Setup

The plugin includes LSP configuration for Arduino development:

- **Syntax highlighting** and **code completion**
- **Error checking** and **diagnostics**
- **Function signatures** and **documentation**
- **Go to definition** support

## 📁 Project Structure

```sh
sketch/
├── sketch.ino              # Main Arduino sketch
├── .arduino_config.lua      # Plugin configuration (auto-generated)
└── .arduino/               # Arduino CLI build artifacts
    └── sketches/
        └── sketch.ino.bin   # Compiled binary
```

## 🐛 Troubleshooting

### Common Issues

1. **"No device found on ttyACM0"**
   - Try `<Leader>ar` for reset-based upload
   - Check USB connection
   - Verify board selection with `<Leader>ag`

2. **Monitor connection issues**
   - Check baudrate setting with `<Leader>as`
   - Ensure correct port selection
   - Try `:InoDebugUpload` for diagnostics

3. **LSP not working**
   - Ensure `arduino-language-server` is installed
   - Check `clangd` is in PATH
   - Restart Neovim after installation

### Debug Commands

- `:InoDebugUpload` - Show detailed upload process
- `:InoList` - List all available ports
- `:InoStatus` - Show current configuration

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

MIT License - Do whatever you want with the code. No attribution required.

<!-- References -->

[acli]: https://arduino.github.io/arduino-cli
[als]: https://github.com/arduino/arduino-language-server
[clangd]: https://clangd.llvm.org/
[telescope]: https://github.com/nvim-telescope/telescope.nvim
[nvim-lspconfig]: https://github.com/neovim/nvim-lspconfig
