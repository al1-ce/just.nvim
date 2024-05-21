// TypeScript source for lazy.nvim
// to compile this file into lua source
// use 'tstl -p tsconfig.json'
// This part is written in TypeScript because of complexity
// and me not wanting to struggle with this in lua

import '@tstldefs/extensions'
import '@tstldefs/fidget'
import '@tstldefs/lua'
import '@tstldefs/plenary'
import '@tstldefs/telescope'
import '@tstldefs/vim'

let config = {
    message_limit: 32, // 15 is around cutoff of first word
    play_sound: false,
    copen_on_error: true,
    telescope_borders: {
        prompt: [ "─", "│", " ", "│", "┌", "┐", "│", "│" ],
        results: [ "─", "│", "─", "│", "├", "┤", "┘", "└" ],
        preview: [ "─", "│", "─", "│", "┌", "┐", "┘", "└" ]
    }
}

//------------------------------------------------------------------//
//                             IMPORTS                              //
//------------------------------------------------------------------//

let pickers = require("telescope.pickers") as typeof telescope.pickers;
let finders = require("telescope.finders") as typeof telescope.finders;
let conf = require("telescope.config").values as typeof telescope.config.values;
let actions = require("telescope.actions") as typeof telescope.actions;
let action_state = require("telescope.actions.state") as typeof telescope.actions.state;
let themes = require("telescope.themes") as typeof telescope.themes;
let async = require("plenary.job") as PlenaryJob
let progress = require("fidget.progress") as typeof fidget.progress;

let notify = require("notify");

let asyncWorker: PlenaryJob | null;

//------------------------------------------------------------------//
//                            FUNCTIONS                             //
//------------------------------------------------------------------//

function popup(message: string, errlvl: string = "info", title: string = "Info"): void {
    notify(message, errlvl, { title: title });
}

function getConfigDir(): string {
    // notify(vim.fn.fnamemodify(debug.getinfo(1).source.sub(2), ":p:h"), "info", {});
    return vim.fn.fnamemodify(debug.getinfo(1).source.sub(2), ":p:h");
    // return vim.fn.fnamemodify(vim.fn.expand("$MYVIMRC"), ":p:h");
}

function get_build_names(lang: string = ""): string[][] {
    let arr: string[] = [];
    // table.remove(tbl, 1);

    let pjustfile: string = `${vim.fn.getcwd()}/justfile`;
    if (vim.fn.filereadable(pjustfile) == 1) {
        let overrideList: string = vim.fn.system(`just -f ${pjustfile} --list`);
        let oarr: string[] = overrideList.split("\n");
        if (oarr[0].startsWith("error")) {
            popup(overrideList, "error", "Build");
            return [];
        }
        oarr.shift();
        oarr.pop();
        let rem: boolean = false;
        for (let i = 0; i < arr.length; ++i) {
            for (let j = 0; j < oarr.length; ++j) {
                let fnor: string =  arr[i].split(" ").filter(e => e !== '')[0];
                let fnov: string = oarr[j].split(" ").filter(e => e !== '')[0];
                // popup(`${fnor} : ${fnov}`);
                if (fnor == fnov) {
                    rem = true;
                }
            }
            if (rem) arr.splice(i, 1);
            rem = false;
        }
        arr = arr.concat(oarr);
    } else {
        popup("Justfile not found in project directory", "error", "Build");
        return [];
    }
    //////////////////// add vim.fn.cwd()
    // table.remove(tbl, #tbl);
    let tbl: string[][] = [];
    for (let i = 0; i < arr.length; ++i) {
        // popup(tbl[i]);
        let comment: string = arr[i].split("#")[1];
        let options: string[] = arr[i].split("#")[0].split(" ");
        options = options.filter(e => e !== '');
        // print(vim.inspect(options));
        let name = options[0];
        let langname = (name.split("_")[0]).toLowerCase();
        // popup(langname);
        if (langname == lang.toLowerCase() || lang == "" || langname == "any") {
            // tbl.push(name);
            let parts: string[] = name.split("_");
            let out: string;
            if (parts.length == 1) {
                out = parts[0];
            } else {
                out = `${parts[0]}: `;
                parts.shift();
                out += parts.join(" ");
            }
            let wd = 34;
            let rn = Math.max(0, wd - out.length);
            out += `${" ".repeat(rn)} ${comment == null ? "" : comment}`;
            tbl.push([out, name]);
        }
        // popup(`${name}: ${options.length}`, "info", "Info");
    }
    return tbl;
}

/**
@summary Checks if argument is defined as keyword (i.e "FILEPATH", "FILEEXT") and
returns corresponding string. If argument is not keyword function returns single space
@param arg Argument to check
*/
function check_keyword_arg(arg: string): string {
    switch (arg) {
        // Full file path
        case "FILEPATH": return vim.fn.expand("%:p");
        // Full file name
        case "FILENAME": return vim.fn.expand("%:t");
        // File path without filename
        case "FILEDIR": return vim.fn.expand("%:p:h");
        // File extension
        case "FILEEXT": return vim.fn.expand("%:e");
        // File name without extension
        case "FILENOEXT": return vim.fn.expand("%:t:r");
        // Current directory
        case "CWD": return vim.fn.getcwd();
        // Relative file path
        case "RELPATH": return vim.fn.expand("%");
        // Relative file path without filename
        case "RELDIR": return vim.fn.expand("%:h");
        // Time and date consts
        case "TIME": return os.date("%H:%M:%S");
        // Date in Day/Month/Year format
        case "DATE": return os.date("%d/%m/%Y");
        // Date in Month/Day/Year format
        case "USDATE": return os.date("%m/%d/%Y");
        // User name
        case "USERNAME": return os.getenv("USER");
        // PC name
        case "PCNAME": return vim.fn.system("uname -a").split(" ")[1];
        // OS
        case "OS": return vim.fn.system("uname").split("\n")[0];
        default: return " ";
    }
}

function get_build_args(build_name: string): string[] {
    let justloc = "";
    let pjustfile: string = `${vim.fn.getcwd()}/justfile`;
    if (vim.fn.filereadable(pjustfile) == 1) { justloc = `just -f ${pjustfile}`; }

    if (justloc == ""){
        popup("Justfile not found in project directory", "error", "Build");
        return [];
    }

    let outshow = vim.fn.system(`${justloc} -s ${build_name}`);

    // Alias always goes first, Comment always goes second
    if (outshow.startsWith("alias")) { outshow = outshow.substring(outshow.indexOf("\n") + 1); }
    if (outshow.startsWith("#")) { outshow = outshow.substring(outshow.indexOf("\n") + 1); }

    let outinfo = outshow.split(":")[0];
    // print(vim.inspect(outinfo));
    let args = outinfo.split(" ");
    // table.remove(args, 1);
    args.shift();
    if (args.length == 0) return [];
    let argsout: string[] = [];
    for (let i = 0; i < args.length; ++i) {
        let arg = args[i];
        let keywd = check_keyword_arg(arg);
        if (keywd == " ") {
            let a: string = "";
            if (arg.includes("=")) {
                let argw: string[] = arg.split("=");
                a = vim.fn.input(`${argw[0]}: `, argw[1]);
            } else {
                a = vim.fn.input(`${arg}: `, "");
            }
            // table.inser;t(argsout, a);
            // print(vim.inspect(a));
            // argsout.push(`"${a}"`);
            argsout.push(`${a}`);
        } else {
            if (keywd == "") keywd = " ";
            argsout.push(`"${keywd}"`);
        }
    }
    // popup(`Command args: ${argsout.join(" ")}`);
    return argsout;
}

// doesnt include aliases
function build_runner(build_name: string): void {
    if (asyncWorker != null) {
        popup("Build job is already running", "error", "Build");
        return;
    }

    let args: string[] = get_build_args(build_name);
    let justloc = "";
    let pjustfile: string = `${vim.fn.getcwd()}/justfile`;
    if (vim.fn.filereadable(pjustfile) == 1) { justloc = `just -f ${pjustfile}`; }

    if (justloc == ""){
        popup("Justfile not found in project directory", "error", "Build");
        return;
    }

    let handle = progress.handle.create({
        title: "",
        message: "Starting build job...",
        lsp_client: { name: "Build job" },
        percentage: 0
    })

    let command: string = `${justloc} -d . ${build_name} ${args.join(" ")}`;
    // popup(command);
    // let success: string = `aplay ${getConfigDir()}/res/build_success.wav -q`;
    // let error: string = `aplay ${getConfigDir()}/res/build_error.wav -q`;

    // USING AsyncRun
    // let lcom: string = `:AsyncRun /bin/bash -c '( ${command} ) && ( ${success} ) || ( ${error} )'`;
    // vim.cmd(lcom);

    // SECTION: ASYNC RUNNER
    // Own implementation depending on Plenary
    // I'm doing it because I prefer having control over those things
    // and AsyncRun was giving me some wierd errors at some places
    // and I can make it even prettier
    vim.schedule(function() {
        // vim.cmd("copen");
        vim.fn.setqflist([{text: "Starting build job: " + command}, {text: ""}], "r");
        // vim.cmd("wincmd p");
    });

    let stime = os.clock();

    function sleep(t: number): void {
        let sec = os.clock() + t;
        while (os.clock() < sec) {}
    }

    let onStdoutFunc = function(err: string, data: string) {
        vim.schedule(function() {
            if (asyncWorker == null) return;
            // TURNS OUT some languages like DART output
            // what should be in stderr to stdout
            // so we're just going to caddexpr everything
            if (data == "") data = " "; // punctuation space

            // Replacing all lowercase types with capital ones because
            // errorformat expects %t as capital letter
            // A bit uncivilised but what can I do there tbh...
            // It's not like anybody wants to write error parser for
            // every type of compiler or something, so, replacing first
            // thing that there is is a fine compromise
            // If you don't like this just comment those
            data = data.replace("warning", "Warning");
            data = data.replace("info", "Info");
            data = data.replace("error", "Error");
            data = data.replace("note", "Note");
            data = data.replaceAll("'", "''");
            data = data.replaceAll("\0", "");
            // popup(data);

            vim.cmd(`caddexpr '${data}'`);
            vim.cmd("cbottom");
            if (data.length > config.message_limit) data = data.slice(0, config.message_limit - 1) + "...";
            handle.message = data;
        });
    }
    let onStderrFunc = function(err: string, data: string) {
        let timer = vim.loop.new_timer();
        // Either fully after or fully before. I prefer after
        // vim.schedule(function() {
        timer.start(10, 0, vim.schedule_wrap(function() {
            if (asyncWorker == null) return;
            if (data == "") data = " "; // punctuation space
            data = data.replace("warning", "Warning");
            data = data.replace("info", "Info");
            data = data.replace("error", "Error");
            data = data.replace("note", "Note");
            data = data.replaceAll("'", "''");
            data = data.replaceAll("\0", "");

            // popup(data);
            vim.cmd(`caddexpr '${data}'`);
            vim.cmd("cbottom");
            if (data.length > config.message_limit) data = data.slice(0, config.message_limit - 1) + "...";
            handle.message = data;
        // });
        }));
    }

    // We want to be able to stop the job if something goes wrong
    // @ts-ignore
    asyncWorker = async.new({
        command: "bash",
        args: ["-c", `( ${command} )`],
        cwd: vim.fn.getcwd(),
        on_exit: function(j: any, ret: number) {
            let etime = os.clock() - stime;
            let timer = vim.loop.new_timer();
            // vim.schedule(function() {
            timer.start(50, 0, vim.schedule_wrap(function() {
                let status: string = "";
                if (asyncWorker == null) {
                    handle.message = "Cancelled";
                    handle.cancel();
                    status = "Cancelled";
                } else {
                    if (ret == 0) {
                        handle.message = "Finished";
                        handle.finish();
                        status = "Finished";
                    } else {
                        handle.message = "Failed";
                        handle.finish();
                        status = "Failed";
                        if (config.copen_on_error) vim.cmd("copen");
                    }
                }
                vim.fn.setqflist([
                    {text: ""},
                    {text: `${status} in ${string.format("%.2f", etime)} seconds`}
                ], "a");

                vim.cmd("cbottom");
                if (config.play_sound) {
                    if (ret == 0) {
                        // @ts-ignore
                        async.new({
                            command: "aplay",
                            args: [`${getConfigDir()}/build_success.wav`, "-q"]
                        }).start();
                    } else {
                        // @ts-ignore
                        async.new({
                            command: "aplay",
                            args: [`${getConfigDir()}/build_error.wav`, "-q"]
                        }).start();
                    }
                }
                asyncWorker = null;
            // });
            }));
        },
        on_stdout: onStdoutFunc,
        on_stderr: onStderrFunc,
    });

    asyncWorker?.start();
    // END SECTION: ASYNC RUNNER

    // popup("Done");
}

export function build_select(opts: any): void {
    if (opts == null) opts = [];
    let tasks: string[][] = get_build_names();
    if (tasks.length == 0) return;
    let picker = pickers.new(opts, {
        prompt_title: "Build tasks",
        border: {},
        borderchars: config.telescope_borders.preview,
        finder: finders.new_table({
            results: tasks,
            entry_maker: (entry: any[]) => {
                return {
                    value: entry,
                    display: entry[0],
                    ordinal: entry[0]
                }
            }
        }),
        sorter: conf.generic_sorter(opts),
        attach_mappings: (buf: any, map: any) => {
            actions.select_default.replace(() => {
                actions.close(buf);
                let selection = action_state.get_selected_entry();
                let build_name = selection.value[2];
                build_runner(build_name);
            });
            return true;
        }
    });
    picker.find();
}

export function run_task_select(): void {
    let tasks: string[][] = get_build_names();
    if (tasks.length == 0) {
        popup(`There are no tasks defined in justfile`, "warn", "Build");
        return;
    }

    build_select(themes.get_dropdown({borderchars: config.telescope_borders}));
}

export function run_task_default(): void {
    let tasks: string[][] = get_build_names();
    if (tasks.length == 0) {
        popup(`There are no tasks defined in justfile`, "warn", "Build");
        return;
    }
    for (let i = 0; i < tasks.length; ++i) {
        let opts: string[] = tasks[i][1].split("_");
        if (opts.length == 1) {
            if (opts[0].toLowerCase() == "default") {
                build_runner(tasks[i][1]);
                return;
            }
        }
    }
    popup(`Could not find default task. \nPlease select task from list.`, "warn", "Build");
    run_task_select();
}

export function run_task_build(): void {
    let tasks: string[][] = get_build_names();
    if (tasks.length == 0) {
        popup(`There are no tasks defined in justfile`, "warn", "Build");
        return;
    }
    for (let i = 0; i < tasks.length; ++i) {
        let opts: string[] = tasks[i][1].split("_");
        if (opts.length == 1) {
            if (opts[0].toLowerCase() == "build") {
                build_runner(tasks[i][1]);
                return;
            }
        }
    }
    popup(`Could not find build task. \nPlease select task from list.`, "warn", "Build");
    run_task_select();
}

export function run_task_run(): void {
    let tasks: string[][] = get_build_names();
    if (tasks.length == 0) {
        popup(`There are no tasks defined in justfile`, "warn", "Build");
        return;
    }
    for (let i = 0; i < tasks.length; ++i) {
        let opts: string[] = tasks[i][1].split("_");
        if (opts.length == 1) {
            if (opts[0].toLowerCase() == "run") {
                build_runner(tasks[i][1]);
                return;
            }
        }
    }
    popup(`Could not find run task. \nPlease select task from list.`, "warn", "Build");
    run_task_select();
}

export function run_task_test(): void {
    let tasks: string[][] = get_build_names();
    if (tasks.length == 0) {
        popup(`There are no tasks defined in justfile`, "warn", "Build");
        return;
    }
    for (let i = 0; i < tasks.length; ++i) {
        let opts: string[] = tasks[i][1].split("_");
        if (opts.length == 1) {
            if (opts[0].toLowerCase() == "test") {
                build_runner(tasks[i][1]);
                return;
            }
        }
    }
    popup(`Could not find test task. \nPlease select task from list.`, "warn", "Build");
    run_task_select();
}

export function stop_current_task(): void {
    asyncWorker?.shutdown();
    asyncWorker = null;
}

export function add_build_template(): void {
    let pjustfile: string = `${vim.fn.getcwd()}/justfile`;
    if (vim.fn.filereadable(pjustfile) == 1) {
        let opt = vim.fn.confirm("Justfile already exists in this project, create anyway?", "&Yes\n&No", 2);
        if (opt != 1) return;
    }

    let f = io.open(pjustfile, "w");
    f.write(
        `#!/usr/bin/env -S just --justfile` + '\n' +
        `# just reference  : https://just.systems/man/en/` + '\n' +
        `` + '\n' +
        `@default:` + '\n' +
        `    just --list` + '\n' +
        `` + '\n' +
        `` + '\n'
    );
    f.close();

    popup("Template justfile created", "info", "Build");
}

function tableToDict(tbl: any) {
    let out: any = {};
    for (let [key, value] of Object.entries(tbl)) {
        out[key as string] = value;
    }
    return out;
}

function getBoolOption(opts: any, key: string, p_default: boolean): boolean {
    if (key in opts) {
        if (opts[key] == true) return true;
        if (opts[key] == false) return false;
    }
    return p_default;
}

function getAnyOption(opts: any, key: string, p_default: any): any {
    if (key in opts) {
        return opts[key];
    }
    return p_default;
}

function getSubTableOption(opts: any, key1: string, key2: string, p_default: any): any {
    if (key1 in opts) {
        let o = opts[key1];
        if (key2 in o) {
            return o[key2];
        }
    }
    return p_default;
}

function error(msg: string): void {
    let [ok, ignore] = pcall(require, "notify");
    if (!ok) {
        vim.api.nvim_err_writeln(msg);
    } else {
        require("notify")(msg, "error");
    }
}

export function setup(opts: any): void {
    opts = tableToDict(opts);

    config.message_limit = getAnyOption(opts, "fidget_message_limit", config.message_limit);
    config.play_sound = getBoolOption(opts, "play_sound", config.play_sound);
    config.copen_on_error = getBoolOption(opts, "open_qf_on_error", config.copen_on_error);
    config.telescope_borders.prompt = getSubTableOption(opts, "telescope_borders", "prompt", config.telescope_borders.prompt);
    config.telescope_borders.results = getSubTableOption(opts, "telescope_borders", "results", config.telescope_borders.results);
    config.telescope_borders.preview = getSubTableOption(opts, "telescope_borders", "preview", config.telescope_borders.preview);

    vim.api.nvim_create_user_command("JustDefault", run_task_default, { desc: "Run default task with just" })
    vim.api.nvim_create_user_command("JustBuild", run_task_build, { desc: "Run build task with just" })
    vim.api.nvim_create_user_command("JustRun", run_task_run, { desc: "Run run task with just" })
    vim.api.nvim_create_user_command("JustTest", run_task_test, { desc: "Run test task with just" })
    vim.api.nvim_create_user_command("JustSelect", run_task_select, { desc: "Open task picker" })
    vim.api.nvim_create_user_command("JustStop", stop_current_task, { desc: "Stops current task" })
    vim.api.nvim_create_user_command("JustCreateTemplate", add_build_template, { desc: "Creates template for just" })

    if (config.play_sound && vim.fn.executable("aplay") != 1) {
        config.play_sound = false;
        error("Failed to find 'aplay' binary on system. Disabling just.nvim play_sound");
    }
}


