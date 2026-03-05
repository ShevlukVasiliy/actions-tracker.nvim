# Neovim plugin to track actions in different modes.

## Dependencies

```bash
luarocks install lsqlite3
```

And add this to your .zshrc or .bashrc

```bash
export export LUA_PATH="./lua/?.lua;;"
```

## Installation

### Vim pack

```lua
vim.pack.add({
    {src = "https://github.com/shevlukvasiliy/actions-tracker.nvim"}
})
```

### Other

See [packer.nvim](https://github.com/wbthomason/packer.nvim), [lazy.nvim](https://github.com/folke/lazy.nvim) and other plugin managers documentation to connect plugin to your neovim.

### After plugin manager

```lua
require("actions-tracker").setup()
```

## Usage

Plugin starts tracking automatically when neovim starts.
To see statistics, run `:ActionsTrackerAnalytics`.
