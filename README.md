# just.nvim
Just task runner for neovim

## Installation
Using [lazy](https://github.com/folke/lazy.nvim)
```lua
{
    "al1-ce/just.nvim",
    dependencies = {
        'nvim-lua/plenary.nvim',
        'nvim-telescope/telescope.nvim',
        'rcarriga/nvim-notify',
        'j-hui/fidget.nvim',
    },
    config = true
}
```

## Configuration
Default config is:
```
require("just").setup({
    play_sound = false, -- plays sound when task is finished or failed
})
```

## [More info](https://github.com/al1-ce/just.nvim/blob/master/primer.md)
Click the link

