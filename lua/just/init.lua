
local ____modules = {}
local ____moduleCache = {}
local ____originalRequire = require
local function require(file, ...)
    if ____moduleCache[file] then
        return ____moduleCache[file].value
    end
    if ____modules[file] then
        local module = ____modules[file]
        ____moduleCache[file] = { value = (select("#", ...) > 0) and module(...) or module(file) }
        return ____moduleCache[file].value
    else
        if ____originalRequire then
            return ____originalRequire(file)
        else
            error("module '" .. file .. "' not found")
        end
    end
end
____modules = {
["init"] = function(...) 
-- Lua Library inline imports
local __TS__StringSplit
do
    local sub = string.sub
    local find = string.find
    function __TS__StringSplit(source, separator, limit)
        if limit == nil then
            limit = 4294967295
        end
        if limit == 0 then
            return {}
        end
        local result = {}
        local resultIndex = 1
        if separator == nil or separator == "" then
            for i = 1, #source do
                result[resultIndex] = sub(source, i, i)
                resultIndex = resultIndex + 1
            end
        else
            local currentPos = 1
            while resultIndex <= limit do
                local startPos, endPos = find(source, separator, currentPos, true)
                if not startPos then
                    break
                end
                result[resultIndex] = sub(source, currentPos, startPos - 1)
                resultIndex = resultIndex + 1
                currentPos = endPos + 1
            end
            if resultIndex <= limit then
                result[resultIndex] = sub(source, currentPos)
            end
        end
        return result
    end
end

local function __TS__StringStartsWith(self, searchString, position)
    if position == nil or position < 0 then
        position = 0
    end
    return string.sub(self, position + 1, #searchString + position) == searchString
end

local function __TS__ArrayFilter(self, callbackfn, thisArg)
    local result = {}
    local len = 0
    for i = 1, #self do
        if callbackfn(thisArg, self[i], i - 1, self) then
            len = len + 1
            result[len] = self[i]
        end
    end
    return result
end

local function __TS__CountVarargs(...)
    return select("#", ...)
end

local function __TS__ArraySplice(self, ...)
    local args = {...}
    local len = #self
    local actualArgumentCount = __TS__CountVarargs(...)
    local start = args[1]
    local deleteCount = args[2]
    if start < 0 then
        start = len + start
        if start < 0 then
            start = 0
        end
    elseif start > len then
        start = len
    end
    local itemCount = actualArgumentCount - 2
    if itemCount < 0 then
        itemCount = 0
    end
    local actualDeleteCount
    if actualArgumentCount == 0 then
        actualDeleteCount = 0
    elseif actualArgumentCount == 1 then
        actualDeleteCount = len - start
    else
        actualDeleteCount = deleteCount or 0
        if actualDeleteCount < 0 then
            actualDeleteCount = 0
        end
        if actualDeleteCount > len - start then
            actualDeleteCount = len - start
        end
    end
    local out = {}
    for k = 1, actualDeleteCount do
        local from = start + k
        if self[from] ~= nil then
            out[k] = self[from]
        end
    end
    if itemCount < actualDeleteCount then
        for k = start + 1, len - actualDeleteCount do
            local from = k + actualDeleteCount
            local to = k + itemCount
            if self[from] then
                self[to] = self[from]
            else
                self[to] = nil
            end
        end
        for k = len - actualDeleteCount + itemCount + 1, len do
            self[k] = nil
        end
    elseif itemCount > actualDeleteCount then
        for k = len - actualDeleteCount, start + 1, -1 do
            local from = k + actualDeleteCount
            local to = k + itemCount
            if self[from] then
                self[to] = self[from]
            else
                self[to] = nil
            end
        end
    end
    local j = start + 1
    for i = 3, actualArgumentCount do
        self[j] = args[i]
        j = j + 1
    end
    for k = #self, len - actualDeleteCount + itemCount + 1, -1 do
        self[k] = nil
    end
    return out
end

local function __TS__ArrayIsArray(value)
    return type(value) == "table" and (value[1] ~= nil or next(value) == nil)
end

local function __TS__ArrayConcat(self, ...)
    local items = {...}
    local result = {}
    local len = 0
    for i = 1, #self do
        len = len + 1
        result[len] = self[i]
    end
    for i = 1, #items do
        local item = items[i]
        if __TS__ArrayIsArray(item) then
            for j = 1, #item do
                len = len + 1
                result[len] = item[j]
            end
        else
            len = len + 1
            result[len] = item
        end
    end
    return result
end

local function __TS__StringSubstring(self, start, ____end)
    if ____end ~= ____end then
        ____end = 0
    end
    if ____end ~= nil and start > ____end then
        start, ____end = ____end, start
    end
    if start >= 0 then
        start = start + 1
    else
        start = 1
    end
    if ____end ~= nil and ____end < 0 then
        ____end = 0
    end
    return string.sub(self, start, ____end)
end

local function __TS__StringIncludes(self, searchString, position)
    if not position then
        position = 1
    else
        position = position + 1
    end
    local index = string.find(self, searchString, position, true)
    return index ~= nil
end

local __TS__StringReplace
do
    local sub = string.sub
    function __TS__StringReplace(source, searchValue, replaceValue)
        local startPos, endPos = string.find(source, searchValue, nil, true)
        if not startPos then
            return source
        end
        local before = sub(source, 1, startPos - 1)
        local replacement = type(replaceValue) == "string" and replaceValue or replaceValue(nil, searchValue, startPos - 1, source)
        local after = sub(source, endPos + 1)
        return (before .. replacement) .. after
    end
end

local __TS__StringReplaceAll
do
    local sub = string.sub
    local find = string.find
    function __TS__StringReplaceAll(source, searchValue, replaceValue)
        if type(replaceValue) == "string" then
            local concat = table.concat(
                __TS__StringSplit(source, searchValue),
                replaceValue
            )
            if #searchValue == 0 then
                return (replaceValue .. concat) .. replaceValue
            end
            return concat
        end
        local parts = {}
        local partsIndex = 1
        if #searchValue == 0 then
            parts[1] = replaceValue(nil, "", 0, source)
            partsIndex = 2
            for i = 1, #source do
                parts[partsIndex] = sub(source, i, i)
                parts[partsIndex + 1] = replaceValue(nil, "", i, source)
                partsIndex = partsIndex + 2
            end
        else
            local currentPos = 1
            while true do
                local startPos, endPos = find(source, searchValue, currentPos, true)
                if not startPos then
                    break
                end
                parts[partsIndex] = sub(source, currentPos, startPos - 1)
                parts[partsIndex + 1] = replaceValue(nil, searchValue, startPos - 1, source)
                partsIndex = partsIndex + 2
                currentPos = endPos + 1
            end
            parts[partsIndex] = sub(source, currentPos)
        end
        return table.concat(parts)
    end
end

local function __TS__StringSlice(self, start, ____end)
    if start == nil or start ~= start then
        start = 0
    end
    if ____end ~= ____end then
        ____end = 0
    end
    if start >= 0 then
        start = start + 1
    end
    if ____end ~= nil and ____end < 0 then
        ____end = ____end - 1
    end
    return string.sub(self, start, ____end)
end
-- End of Lua Library inline imports
local ____exports = {}
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local themes = require("telescope.themes")
local async = require("plenary.job")
local progress = require("fidget.progress")
local notify = require("notify")
local asyncWorker
local function popup(message, errlvl, title)
    if errlvl == nil then
        errlvl = "info"
    end
    if title == nil then
        title = "Info"
    end
    notify(message, errlvl, {title = title})
end
local function getConfigDir()
    return vim.fn.fnamemodify(
        debug.getinfo(1).source:sub(2),
        ":p:h"
    )
end
local function get_build_names(lang)
    if lang == nil then
        lang = ""
    end
    local arr = {}
    local pjustfile = vim.fn.getcwd() .. "/justfile"
    if vim.fn.filereadable(pjustfile) == 1 then
        local overrideList = vim.fn.system(("just -f " .. pjustfile) .. " --list")
        local oarr = __TS__StringSplit(overrideList, "\n")
        if __TS__StringStartsWith(oarr[1], "error") then
            popup(overrideList, "error", "Build")
            return {}
        end
        table.remove(oarr, 1)
        table.remove(oarr)
        local rem = false
        do
            local i = 0
            while i < #arr do
                do
                    local j = 0
                    while j < #oarr do
                        local fnor = __TS__ArrayFilter(
                            __TS__StringSplit(arr[i + 1], " "),
                            function(____, e) return e ~= "" end
                        )[1]
                        local fnov = __TS__ArrayFilter(
                            __TS__StringSplit(oarr[j + 1], " "),
                            function(____, e) return e ~= "" end
                        )[1]
                        if fnor == fnov then
                            rem = true
                        end
                        j = j + 1
                    end
                end
                if rem then
                    __TS__ArraySplice(arr, i, 1)
                end
                rem = false
                i = i + 1
            end
        end
        arr = __TS__ArrayConcat(arr, oarr)
    else
        popup("Justfile not found in project directory", "error", "Build")
        return {}
    end
    local tbl = {}
    do
        local i = 0
        while i < #arr do
            local comment = __TS__StringSplit(arr[i + 1], "#")[2]
            local options = __TS__StringSplit(
                __TS__StringSplit(arr[i + 1], "#")[1],
                " "
            )
            options = __TS__ArrayFilter(
                options,
                function(____, e) return e ~= "" end
            )
            local name = options[1]
            local langname = string.lower(__TS__StringSplit(name, "_")[1])
            if langname == string.lower(lang) or lang == "" or langname == "any" then
                local parts = __TS__StringSplit(name, "_")
                local out
                if #parts == 1 then
                    out = parts[1]
                else
                    out = parts[1] .. ": "
                    table.remove(parts, 1)
                    out = out .. table.concat(parts, " ")
                end
                local wd = 34
                local rn = math.max(0, wd - #out)
                out = out .. (string.rep(
                    " ",
                    math.floor(rn)
                ) .. " ") .. (comment == nil and "" or comment)
                tbl[#tbl + 1] = {out, name}
            end
            i = i + 1
        end
    end
    return tbl
end
---
-- @summary Checks if argument is defined as keyword (i.e "FILEPATH", "FILEEXT") and
-- returns corresponding string. If argument is not keyword function returns single space
-- @param arg Argument to check
local function check_keyword_arg(arg)
    repeat
        local ____switch20 = arg
        local ____cond20 = ____switch20 == "FILEPATH"
        if ____cond20 then
            return vim.fn.expand("%:p")
        end
        ____cond20 = ____cond20 or ____switch20 == "FILENAME"
        if ____cond20 then
            return vim.fn.expand("%:t")
        end
        ____cond20 = ____cond20 or ____switch20 == "FILEDIR"
        if ____cond20 then
            return vim.fn.expand("%:p:h")
        end
        ____cond20 = ____cond20 or ____switch20 == "FILEEXT"
        if ____cond20 then
            return vim.fn.expand("%:e")
        end
        ____cond20 = ____cond20 or ____switch20 == "FILENOEXT"
        if ____cond20 then
            return vim.fn.expand("%:t:r")
        end
        ____cond20 = ____cond20 or ____switch20 == "CWD"
        if ____cond20 then
            return vim.fn.getcwd()
        end
        ____cond20 = ____cond20 or ____switch20 == "RELPATH"
        if ____cond20 then
            return vim.fn.expand("%")
        end
        ____cond20 = ____cond20 or ____switch20 == "RELDIR"
        if ____cond20 then
            return vim.fn.expand("%:h")
        end
        ____cond20 = ____cond20 or ____switch20 == "TIME"
        if ____cond20 then
            return os.date("%H:%M:%S")
        end
        ____cond20 = ____cond20 or ____switch20 == "DATE"
        if ____cond20 then
            return os.date("%d/%m/%Y")
        end
        ____cond20 = ____cond20 or ____switch20 == "USDATE"
        if ____cond20 then
            return os.date("%m/%d/%Y")
        end
        ____cond20 = ____cond20 or ____switch20 == "USERNAME"
        if ____cond20 then
            return os.getenv("USER")
        end
        ____cond20 = ____cond20 or ____switch20 == "PCNAME"
        if ____cond20 then
            return __TS__StringSplit(
                vim.fn.system("uname -a"),
                " "
            )[2]
        end
        ____cond20 = ____cond20 or ____switch20 == "OS"
        if ____cond20 then
            return __TS__StringSplit(
                vim.fn.system("uname"),
                "\n"
            )[1]
        end
        do
            return " "
        end
    until true
end
local function get_build_args(build_name)
    local justloc = ""
    local pjustfile = vim.fn.getcwd() .. "/justfile"
    if vim.fn.filereadable(pjustfile) == 1 then
        justloc = "just -f " .. pjustfile
    end
    if justloc == "" then
        popup("Justfile not found in project directory", "error", "Build")
        return {}
    end
    local outshow = vim.fn.system((justloc .. " -s ") .. build_name)
    if __TS__StringStartsWith(outshow, "alias") then
        outshow = __TS__StringSubstring(
            outshow,
            (string.find(outshow, "\n", nil, true) or 0) - 1 + 1
        )
    end
    if __TS__StringStartsWith(outshow, "#") then
        outshow = __TS__StringSubstring(
            outshow,
            (string.find(outshow, "\n", nil, true) or 0) - 1 + 1
        )
    end
    local outinfo = __TS__StringSplit(outshow, ":")[1]
    local args = __TS__StringSplit(outinfo, " ")
    table.remove(args, 1)
    if #args == 0 then
        return {}
    end
    local argsout = {}
    do
        local i = 0
        while i < #args do
            local arg = args[i + 1]
            local keywd = check_keyword_arg(arg)
            if keywd == " " then
                local a = ""
                if __TS__StringIncludes(arg, "=") then
                    local argw = __TS__StringSplit(arg, "=")
                    a = vim.fn.input(argw[1] .. ": ", argw[2])
                else
                    a = vim.fn.input(arg .. ": ", "")
                end
                argsout[#argsout + 1] = a
            else
                if keywd == "" then
                    keywd = " "
                end
                argsout[#argsout + 1] = ("\"" .. keywd) .. "\""
            end
            i = i + 1
        end
    end
    return argsout
end
local MESSAGE_LIMIT = 32
local PLAY_SOUND = false
local function build_runner(build_name)
    if asyncWorker ~= nil then
        popup("Build job is already running", "error", "Build")
        return
    end
    local args = get_build_args(build_name)
    local justloc = ""
    local pjustfile = vim.fn.getcwd() .. "/justfile"
    if vim.fn.filereadable(pjustfile) == 1 then
        justloc = "just -f " .. pjustfile
    end
    if justloc == "" then
        popup("Justfile not found in project directory", "error", "Build")
        return
    end
    local handle = progress.handle.create({title = "", message = "Starting build job...", lsp_client = {name = "Build job"}, percentage = 0})
    local command = (((justloc .. " -d . ") .. build_name) .. " ") .. table.concat(args, " ")
    vim.schedule(function()
        vim.fn.setqflist({{text = "Starting build job: " .. command}, {text = ""}}, "r")
    end)
    local stime = os.clock()
    local function sleep(t)
        local sec = os.clock() + t
        while os.clock() < sec do
        end
    end
    local function onStdoutFunc(err, data)
        vim.schedule(function()
            if asyncWorker == nil then
                return
            end
            if data == "" then
                data = " "
            end
            data = __TS__StringReplace(data, "warning", "Warning")
            data = __TS__StringReplace(data, "info", "Info")
            data = __TS__StringReplace(data, "error", "Error")
            data = __TS__StringReplace(data, "note", "Note")
            data = __TS__StringReplaceAll(data, "'", "''")
            data = __TS__StringReplaceAll(data, "\0", "")
            vim.cmd(("caddexpr '" .. data) .. "'")
            vim.cmd("cbottom")
            if #data > MESSAGE_LIMIT then
                data = __TS__StringSlice(data, 0, MESSAGE_LIMIT - 1) .. "..."
            end
            handle.message = data
        end)
    end
    local function onStderrFunc(err, data)
        local timer = vim.loop.new_timer()
        timer:start(
            10,
            0,
            vim.schedule_wrap(function()
                if asyncWorker == nil then
                    return
                end
                if data == "" then
                    data = " "
                end
                data = __TS__StringReplace(data, "warning", "Warning")
                data = __TS__StringReplace(data, "info", "Info")
                data = __TS__StringReplace(data, "error", "Error")
                data = __TS__StringReplace(data, "note", "Note")
                data = __TS__StringReplaceAll(data, "'", "''")
                data = __TS__StringReplaceAll(data, "\0", "")
                vim.cmd(("caddexpr '" .. data) .. "'")
                vim.cmd("cbottom")
                if #data > MESSAGE_LIMIT then
                    data = __TS__StringSlice(data, 0, MESSAGE_LIMIT - 1) .. "..."
                end
                handle.message = data
            end)
        )
    end
    asyncWorker = async:new({
        command = "bash",
        args = {"-c", ("( " .. command) .. " )"},
        cwd = vim.fn.getcwd(),
        on_exit = function(j, ret)
            local etime = os.clock() - stime
            local timer = vim.loop.new_timer()
            timer:start(
                50,
                0,
                vim.schedule_wrap(function()
                    local status = ""
                    if asyncWorker == nil then
                        handle.message = "Cancelled"
                        handle:cancel()
                        status = "Cancelled"
                    else
                        if ret == 0 then
                            handle.message = "Finished"
                            handle:finish()
                            status = "Finished"
                        else
                            handle.message = "Failed"
                            handle:finish()
                            status = "Failed"
                        end
                    end
                    vim.fn.setqflist(
                        {
                            {text = ""},
                            {text = ((status .. " in ") .. string.format("%.2f", etime)) .. " seconds"}
                        },
                        "a"
                    )
                    vim.cmd("cbottom")
                    if PLAY_SOUND then
                        if ret == 0 then
                            async:new({
                                command = "aplay",
                                args = {
                                    getConfigDir() .. "/build_success.wav",
                                    "-q"
                                }
                            }):start()
                        else
                            async:new({
                                command = "aplay",
                                args = {
                                    getConfigDir() .. "/build_error.wav",
                                    "-q"
                                }
                            }):start()
                        end
                    end
                    asyncWorker = nil
                end)
            )
        end,
        on_stdout = onStdoutFunc,
        on_stderr = onStderrFunc
    })
    if asyncWorker ~= nil then
        asyncWorker:start()
    end
end
function ____exports.build_select(opts)
    if opts == nil then
        opts = {}
    end
    local tasks = get_build_names()
    if #tasks == 0 then
        return
    end
    local picker = pickers.new(
        opts,
        {
            prompt_title = "Build tasks",
            border = {},
            borderchars = {
                " ",
                " ",
                " ",
                " ",
                "┌",
                "┐",
                "┘",
                "└"
            },
            finder = finders.new_table({
                results = tasks,
                entry_maker = function(entry)
                    return {value = entry, display = entry[1], ordinal = entry[1]}
                end
            }),
            sorter = conf.generic_sorter(opts),
            attach_mappings = function(buf, map)
                actions.select_default:replace(function()
                    actions.close(buf)
                    local selection = action_state.get_selected_entry()
                    local build_name = selection.value[2]
                    build_runner(build_name)
                end)
                return true
            end
        }
    )
    picker:find()
end
local telescopeConfig = {borderchars = {prompt = {
    " ",
    " ",
    " ",
    " ",
    "┌",
    "┐",
    " ",
    " "
}, results = {
    " ",
    " ",
    " ",
    " ",
    "├",
    "┤",
    "┘",
    "└"
}, preview = {
    " ",
    " ",
    " ",
    " ",
    "┌",
    "┐",
    "┘",
    "└"
}}}
function ____exports.run_task_select()
    local tasks = get_build_names()
    if #tasks == 0 then
        popup("There are no tasks defined in justfile", "warn", "Build")
        return
    end
    ____exports.build_select(themes.get_dropdown(telescopeConfig))
end
function ____exports.run_task_default()
    local tasks = get_build_names()
    if #tasks == 0 then
        popup("There are no tasks defined in justfile", "warn", "Build")
        return
    end
    do
        local i = 0
        while i < #tasks do
            local opts = __TS__StringSplit(tasks[i + 1][2], "_")
            if #opts == 1 then
                if string.lower(opts[1]) == "default" then
                    build_runner(tasks[i + 1][2])
                    return
                end
            end
            i = i + 1
        end
    end
    popup("Could not find default task. \nPlease select task from list.", "warn", "Build")
    ____exports.run_task_select()
end
function ____exports.run_task_build()
    local tasks = get_build_names()
    if #tasks == 0 then
        popup("There are no tasks defined in justfile", "warn", "Build")
        return
    end
    do
        local i = 0
        while i < #tasks do
            local opts = __TS__StringSplit(tasks[i + 1][2], "_")
            if #opts == 1 then
                if string.lower(opts[1]) == "build" then
                    build_runner(tasks[i + 1][2])
                    return
                end
            end
            i = i + 1
        end
    end
    popup("Could not find build task. \nPlease select task from list.", "warn", "Build")
    ____exports.run_task_select()
end
function ____exports.run_task_run()
    local tasks = get_build_names()
    if #tasks == 0 then
        popup("There are no tasks defined in justfile", "warn", "Build")
        return
    end
    do
        local i = 0
        while i < #tasks do
            local opts = __TS__StringSplit(tasks[i + 1][2], "_")
            if #opts == 1 then
                if string.lower(opts[1]) == "run" then
                    build_runner(tasks[i + 1][2])
                    return
                end
            end
            i = i + 1
        end
    end
    popup("Could not find run task. \nPlease select task from list.", "warn", "Build")
    ____exports.run_task_select()
end
function ____exports.run_task_test()
    local tasks = get_build_names()
    if #tasks == 0 then
        popup("There are no tasks defined in justfile", "warn", "Build")
        return
    end
    do
        local i = 0
        while i < #tasks do
            local opts = __TS__StringSplit(tasks[i + 1][2], "_")
            if #opts == 1 then
                if string.lower(opts[1]) == "test" then
                    build_runner(tasks[i + 1][2])
                    return
                end
            end
            i = i + 1
        end
    end
    popup("Could not find test task. \nPlease select task from list.", "warn", "Build")
    ____exports.run_task_select()
end
function ____exports.stop_current_task()
    if asyncWorker ~= nil then
        asyncWorker:shutdown()
    end
    asyncWorker = nil
end
function ____exports.add_build_template()
    local pjustfile = vim.fn.getcwd() .. "/justfile"
    if vim.fn.filereadable(pjustfile) == 1 then
        local opt = vim.fn.confirm("Justfile already exists in this project, create anyway?", "&Yes\n&No", 2)
        if opt ~= 1 then
            return
        end
    end
    local f = io.open(pjustfile, "w")
    f:write((((((((((((("#!/usr/bin/env -S just --justfile" .. "\n") .. "# just reference  : https://just.systems/man/en/") .. "\n") .. "") .. "\n") .. "@default:") .. "\n") .. "    just --list") .. "\n") .. "") .. "\n") .. "") .. "\n")
    f:close()
    popup("Template justfile created", "info", "Build")
end
function ____exports.setup(opts)
    if opts.play_sound ~= nil then
        if opts.play_sound == true then
            PLAY_SOUND = true
        end
    end
    vim.api.nvim_create_user_command("JustDefault", ____exports.run_task_default, {desc = "Run default task with just"})
    vim.api.nvim_create_user_command("JustBuild", ____exports.run_task_build, {desc = "Run build task with just"})
    vim.api.nvim_create_user_command("JustRun", ____exports.run_task_run, {desc = "Run run task with just"})
    vim.api.nvim_create_user_command("JustTest", ____exports.run_task_test, {desc = "Run test task with just"})
    vim.api.nvim_create_user_command("JustSelect", ____exports.run_task_select, {desc = "Open task picker"})
    vim.api.nvim_create_user_command("JustStop", ____exports.stop_current_task, {desc = "Stops current task"})
    vim.api.nvim_create_user_command("JustCreateTemplate", ____exports.add_build_template, {desc = "Creates template for just"})
end
return ____exports
 end,
}
return require("init", ...)
