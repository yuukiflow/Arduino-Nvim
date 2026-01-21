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
  - Visual indicators for installed libraries
  - Update detection and management
  - Cached library data for faster loading
- **ESP8266 LittleFS filesystem upload** for serving web files
- **LSP support** for Arduino development
- **Real-time status monitoring**
- **Persistent configuration storage**
- **Debug upload functionality** for troubleshooting

## 📋 Requirements

- [arduino-cli][acli] (latest stable version)
- [arduino-language-server][als]
- [clangd][clangd] (latest stable version)
- [telescope.nvim][telescope]
- [nvim-lspconfig][nvim-lspconfig]
- [uv][uv] (for ESP8266 LittleFS upload - manages Python virtual environment)

## 🚀 Installation (LazyVim)

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
| `<Leader>aw` | `:InoWatchUpload` | Upload and open serial monitor automatically |
| `<Leader>ar` | `:InoUploadReset` | Upload with manual reset (for UNO R4 WiFi) |
| `<Leader>ad` | `:InoDataUpload` | Upload LittleFS data directory (ESP8266) |
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
| `:InoWatchUpload` | Compile, upload, and automatically open serial monitor |
| `:InoDataUpload` | Upload `data/` directory to ESP8266 LittleFS filesystem |
| `:InoList` | List all available Arduino ports |
| `:InoSetBaud <rate>` | Set serial monitor baudrate (e.g. `:InoSetBaud 115200`) |

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
  baudrate = "115200",
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
├── sketch.ino               # Main Arduino sketch
├── .arduino_config.lua      # Plugin configuration (auto-generated)
├── data/                    # LittleFS filesystem directory (ESP8266)
│   ├── index.html           # Web files to upload
│   └── assets/              # Static assets (JS, CSS, images)
└── .arduino/                # Arduino CLI build artifacts
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

## ESP8266 LittleFS Upload

The plugin supports uploading a `data/` directory to ESP8266 boards as a LittleFS filesystem.
This is useful for serving web pages, configuration files, or other static assets from the ESP8266.

### Requirements

- ESP8266 board package installed via Arduino CLI
- [uv](https://docs.astral.sh/uv/) - Python package manager (automatically creates venv with pyserial)

### Usage

1. Create a `data/` directory in your sketch folder
2. Add files you want to upload (HTML, JS, CSS, images, etc.)
3. Run `:InoDataUpload` or press `<Leader>ad`

### Configuration

The plugin uses the **4M2M** flash layout by default (4MB flash, 2MB filesystem):

| Setting | Value |
|---------|-------|
| Flash Start | `0x200000` |
| Filesystem Size | ~2MB |
| Page Size | 256 bytes |
| Block Size | 8192 bytes |

### Example data/ directory

```sh
data/
├── index.html          # Main web page
├── config.json         # Configuration file
└── assets/
    ├── app.js          # JavaScript
    └── style.css       # Styles
```

The plugin will:
1. Automatically create a Python virtual environment at `~/.local/share/nvim/arduino-nvim/venv`
2. Install dependencies from `requirements.txt` into the venv using `uv`
3. Create a LittleFS image using `mklittlefs`
4. Upload the image to the ESP8266 using `esptool.py`

### Python Dependencies

The plugin manages its own Python virtual environment. Dependencies are defined in `requirements.txt`:

```
pyserial>=3.5
```

The venv is automatically created at `~/.local/share/nvim/arduino-nvim/venv` and dependencies
are installed asynchronously when the plugin loads (on Neovim startup with an Arduino file).

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
[uv]: https://docs.astral.sh/uv/
