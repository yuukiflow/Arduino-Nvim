# An arduino IDE for neovim

I've made this plugin to replicate the functionnality of [Arduino IDE](https://www.arduino.cc/en/Software/ArduinoIDE) in neovim. It's a work in progress and I'm open to any feedback.

## Requirements

- arduino-cli
- arduino-language-server (needs lsp.go lib to me modified : https://github.com/arduino/arduino-language-server/issues/187#issuecomment-2241641098)
- clangd

## Installation

```sh
git clone https://github.com/yuukiflow/Arduino-Nvim.git ~/.config/nvim/lua/Arduino-Nvim
```

in your init.lua

```lua
require("arduino-nvim")
```

## Usage

I have key bindings set in remap.lua as follow :
they all start with `<leader> a` and follow a simple rule.
Next letter is the first letter of the tool you wanna use.

`<leader> a`:
- c: compile and check
- u: upload to set port and fqbn
- m: opens a new kitty terminal with the monitor
- s: shows the current status for board, port and fqbn
- l: opens a gui library manager (built around telescope)
- p: displays available ports

Baudrate has to be set manually for now with
```
:InoSetBaudrate 115200
```
Know that baudrate defaults to 115200 if not set.
