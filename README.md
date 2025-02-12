# just.nvim
[Just](https://github.com/casey/just) task runner for neovim

## Screenshots
Example just file (default JustCreateTemplate with added build task)

![example](readme/just-file.png)

Fidget hint

![example](readme/just-fidget.png)

Output of `:Just build`

![example](readme/just-qf.png)

`:JustSelect`

![example](readme/just-select.png)

## Installation
Using [lazy](https://github.com/folke/lazy.nvim)
```lua
{
    "al1-ce/just.nvim",
    dependencies = {
        'nvim-lua/plenary.nvim', -- async jobs
        'nvim-telescope/telescope.nvim', -- task picker (optional)
        'rcarriga/nvim-notify', -- general notifications (optional)
        'j-hui/fidget.nvim', -- task progress (optional)
        'al1-ce/jsfunc.nvim', -- extension library
    },
    config = true
}
```

## Configuration
Default config is:
```lua
require("just").setup({
    fidget_message_limit = 32, -- limit for length of fidget progress message 
    play_sound = false, -- plays sound when task is finished or failed
    open_qf_on_error = true, -- opens quickfix when task fails
    open_qf_on_run = true, -- opens quickfix when running `run` task (`:JustRun`)
    open_qf_on_any = false; -- opens quickfix when running any task (overrides other open_qf options)
    telescope_borders = { -- borders for telescope window
        prompt = { "─", "│", " ", "│", "┌", "┐", "│", "│" }, 
        results = { "─", "│", "─", "│", "├", "┤", "┘", "└" },
        preview = { "─", "│", "─", "│", "┌", "┐", "┘", "└" }
    }
})
```

### Usage
You can configure your build tasks with justfile located in your Current Directory. These tasks are local and will be displayed only for this local project.

Any output coming from executing tasks will be directed into *quickfix* and *fidget* and upon completing/failing task the bell will play using `lua/just/build_success.wav` or `lua/just/build_error.wav` accordingly. This can be changed in `lua/just/init.lua` or same file in typescript (preferred, but requires executing TypescriptToLua and executing `tstl -p tsconfig.json`)

Commands:
- `Just` - If 0 args supplied runs `default` task, if 1 arg supplied runs task passes as that arg. If ran with bang (`!`) then stops currently running task before executing new one.
- `JustSelect` - Gives you selection of all tasks in `justfile`.
- `JustStop` - Stops currently executed task
- `JustCreateTemplate` - Creates template `justfile` with included "cheatsheet".
- `JustCreateMakeTemplate` - Creates make-like template `justfile` to allow compiling only changed files.

Only one task can be executed at same time.

## [More info](htts://github.com/al1-ce/just.nvim/blob/master/primer.md)

