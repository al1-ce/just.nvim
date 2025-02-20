// This is a rewrite of awful TypeScript variant of this plugin. Original code in ts was written
// as a alleviation of complexity but it eventually itself became complex and in addition to that
// ts-to-lua somehow "broke" and refused to properly call `:` (class/passing this) methods.

require("jsfunc");

let config = {
    message_limit: 32, // 15 is around cutoff of first word
    play_sound: false,
    copen_on_error: true,
    copen_on_run: true,
    copen_on_any: false,
    telescope_borders: {
        prompt: ['─', '│', ' ', '│', '┌', '┐', '│', '│'],
        results: ['─', '│', '─', '│', '├', '┤', '┘', '└'],
        preview: ['─', '│', '─', '│', '┌', '┐', '┘', '└']
    }
};

function can_load(module) {
    let ok = pack2(pcall(require, module))[1];
    return ok;
}

const async = require("plenary.job");

let progress = null;
let notify;

let pickers = null;
let finders;
let conf;
let actions;
let action_state;
let themes;

if (can_load("telescope")) {
    pickers = require("telescope.pickers");
    finders = require("telescope.finders");
    conf = require("telescope.config").values;
    actions = require("telescope.actions");
    action_state = require("telescope.actions.state");
    themes = require("telescope.themes");
}

if (can_load("fidget")) {
    progress = require("fidget.progress");
}

if (can_load("notify")) {
    notify = require("notify");
} else {
    notify = function(msg, errlvl, title) {
        if (errlvl == "error") {
            new vim.api.nvim_err_writeln(message);
        } else {
            new vim.api.nvim_echo([[message, "Normal"]], false, {})
        }
    }
}

let async_worker = null;

function popup(message, errlvl = "info", title = "Info") {
    notify(message, errlvl, { title: title });
}

function info(message) {
    popup(message, "info", "Just");
}

function error(message) {
    popup(message, "error", "Just");
}

function warning(message) {
    popup(message, "warning", "Just");
}

function inspect(val) {
    print(new vim.inspect(val));
}

function get_config_dir() {
    return new vim.fn.fnamemodify(new debug.getinfo(1).source.sub(2), ":p:h");
}

function get_task_names(lang = "") {
    let arr = [];

    let justfile = `${new vim.fn.getcwd()}/justfile`;
    if (new vim.fn.filereadable(justfile) == 1) {
        let taskList = new vim.fn.system(`just -f ${justfile} --list`);
        let taskArray = taskList.split('\n');

        if (taskArray[1].starts_with("error")) {
            error(taskList);
            return [];
        }
        // taskArray.shift();
        // taskArray.pop();
        new table.shift(taskArray);
        // new table.pop(taskArray);
        arr = taskArray;
    } else {
        error("Justfile not found in project directory");
        return [];
    }

    let tbl = [];

    for (let i = 0; i < arr.length; ++i) {
        let name, langname;
        let comment = arr[i + 1].split('#')[2];
        let options = arr[i + 1].split('#')[1].split(' ');
        options = new table.filter(options, a => a != "");
        if (options.length == 0) continue;
        name = options[1];
        langname = (name.split('_')[1]).lower();
        if (langname == lang.lower() || lang == "" || langname == "any") {
            let parts = name.split('_');
            let out = "";
            if (parts.length == 1) {
                out = parts[1];
            } else {
                out = `${parts[1]}: `;
                new table.shift(parts);
                out = `${out}${new table.concat(parts, ' ')}`;
            }
            if (pickers != null) {
                let width = 34;
                let repeatNum = new math.max(0, width - out.length);
                out = `${out}${' '.repeat(repeatNum)} ${comment == null ? "" : comment}`;
                new table.insert(tbl, [out, name]);
            } else {
                new table.insert(tbl, out);
            }
            let _null;
        }
    }
    return tbl;
}

function check_keyword_arg(arg) {
    switch (arg) {
        // Full file path
        case "FILEPATH": return new vim.fn.expand("%:p");
        // Full file name
        case "FILENAME": return new vim.fn.expand("%:t");
        // File path without filename
        case "FILEDIR": return new vim.fn.expand("%:p:h");
        // File extension
        case "FILEEXT": return new vim.fn.expand("%:e");
        // File name without extension
        case "FILENOEXT": return new vim.fn.expand("%:t:r");
        // Current directory
        case "CWD": return new vim.fn.getcwd();
        // Relative file path
        case "RELPATH": return new vim.fn.expand('%');
        // Relative file path without filename
        case "RELDIR": return new vim.fn.expand("%:h");
        // Time and date consts
        case "TIME": return new os.date("%H:%M:%S");
        // Date in Day/Month/Year format
        case "DATE": return new os.date("%d/%m/%Y");
        // Date in Month/Day/Year format
        case "USDATE": return new os.date("%m/%d/%Y");
        // User name
        case "USERNAME": return new os.getenv("USER");
        // PC name
        case "PCNAME": return new vim.fn.system("uname -a").split(" ")[2];
        // OS
        case "OS": return new vim.fn.system("uname").split("\n")[1];
        default: break;
    }
    return " ";
}

function get_task_args(task_name) {
    let justfile = `${new vim.fn.getcwd()}/justfile`;

    if (new vim.fn.filereadable(justfile) != 1) {
        error("Justfile not found in project directory");
    }

    let task_info = new vim.fn.system(`just -f ${justfile} -s ${task_name}`)

    if (task_info.starts_with("alias")) { task_info = task_info.sub(task_info.find('\n') + 1); }
    if (task_info.starts_with('#')) { task_info = task_info.sub(task_info.find('\n') + 1); }

    // taskname ARG1 ARG2: dep1 dep2
    let task_signature = task_info.split(':')[1];
    let task_args = task_signature.split(' ');
    new table.shift(task_args);

    if (task_args.length == 0) return {args: [], all: true, fail: false};
    let out_args = [];

    for (let i = 0; i < task_args.length; ++i) {
        let arg = task_args[i + 1];
        let keyword = check_keyword_arg(arg);
        if (keyword == ' ') {
            let ask = "";
            if (arg.contains('=')) {
                let arg_comp = arg.split('=');
                ask = new vim.fn.input(`${arg_comp[1]}: `, arg_comp[2]);
            } else {
                ask = new vim.fn.input(`${arg}: `, "");
            }

            if (`${ask}` == "") {
                error("Must provide a valid argument");
                return { args: [], all: false, fail: true };
            }

            new table.insert(out_args, `${ask}`);
        } else {
            if (keyword == "") keyword = ' ';
            new table.insert(out_args, `${keyword}`);
        }
    }

    return {args: out_args, all: out_args.length == task_args.length, fail: false};
}

function task_runner(task_name) {
    if (async_worker != null) {
        error("Task is already running");
        return;
    }

    let arg_obj = get_task_args(task_name);

    if (arg_obj.fail) return;
    if (arg_obj.all != true) {
        error("Failed to get all arguments or not enough arguments supplied");
        return;
    }

    let args = arg_obj.args;

    let justfile = `${new vim.fn.getcwd()}/justfile`;

    if (new vim.fn.filereadable(justfile) != 1) {
        error("Justfile not found in project directory");
        return;
    }

    let handle = null;
    if (progress != null) {
        handle = new progress.handle.create({
            title: "",
            message: `Starting task "${task_name}"`,
            lsp_client: { name: "Just" },
            percentage: 0
        });
    }

    let command = `just -f ${justfile} -d . ${task_name} ${new table.concat(args, " ")}`;

    let should_open_qf = (config.copen_on_run && task_name == "run") || config.copen_on_any;
    if (should_open_qf) new vim.cmd("copen");
    new vim.fn.setqflist([{ text: `Starting task: ${command}` }, { text: "" }], 'r');
    if (should_open_qf) new vim.cmd("wincmd p");

    let start_time = new os.clock();

    let append_qf_data = function (data) {
        if (async_worker == null) return;
        // TURNS OUT some languages like DART output
        // what should be in stderr to stdout
        // so we're just going to caddexpr everything
        if (data == nil) data = "";
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
        data = data.replace_all("'", "''");
        data = data.replace_all("\0", "");

        new vim.cmd(`caddexpr '${data}'`);
        // new vim.cmd("cbottom");
        if (data.length > config.message_limit) data = `${data.sub(1, config.message_limit)}...`;
        if (handle != null) handle.message = data;
    }

    let on_stdout_func = function (err, data) {
        new vim.schedule(() => append_qf_data(data));
    }

    let on_stderr_func = function (err, data) {
        new vim.schedule(() => append_qf_data(data));
        // Either fully after or fully before. I prefer after
        // new vim.defer_fn(function () { append_qf_data(data); }, 10);
    }

    let just_args = [
        "-f",
        justfile,
        "-d",
        ".",
        task_name,
    ]

    for (let arg of args) {
        new table.insert(just_args, arg);

    }

    async_worker = async.new({
        // command: "bash",
        // args: ["-c", `( ${command} )`],
        command: "just",
        args: just_args,
        env: new vim.fn.environ(),
        cwd: new vim.fn.getcwd(),
        on_exit: function (j, ret) {
            let end_time = new os.clock() - start_time;
            new vim.defer_fn(function () {
                let status = "";
                if (async_worker == null) {
                    if (handle != null) {
                        handle.message = "Cancelled";
                        handle.cancel();
                    }
                    status = "Cancelled";
                } else {
                    if (ret == 0) {
                        if (handle != null) {
                            handle.message = "Finished";
                            handle.finish();
                        }
                        status = "Finished";
                    } else {
                        if (handle != null) {
                            handle.message = "Failed";
                            handle.finish();
                        }
                        status = "Failed";
                        if (config.copen_on_error) {
                            new vim.cmd("copen");
                            new vim.cmd("wincmd p");
                        }
                    }
                }
                new vim.fn.setqflist([
                    { text: "" },
                    { text: `${status} in ${new string.format("%.2f", end_time)} seconds` }
                ], 'a');

                new vim.cmd("cbottom");

                if (config.play_sound) {
                    if (ret == 0) {
                        async.new({
                            command: "aplay",
                            args: [`${get_config_dir()}/build_success.wav`, "-q"]
                        }).start();
                    } else {
                        async.new({
                            command: "aplay",
                            args: [`${get_config_dir()}/build_error.wav`, "-q"]
                        }).start();
                    }
                }
                async_worker = null;
            }, 50);
        },
        on_stdout: on_stdout_func,
        on_stderr: on_stderr_func,
        on_start: function() {
            if (handle != null) handle.message = `Executing task ${task_name}`;
        }
    });

    if (async_worker != null) async_worker.start();
}

export function task_select(opts) {
    if (opts == null) opts = [];
    let tasks = get_task_names();
    if (tasks.length == 0) return;
    // let has_telescope = pack2(pcall(require, "telescope"))[1];
    //
    // if (!has_telescope) {
    //     let sel = new vim.fn.inputlist(tasks);
    //     // TODO: implement
    // }

    if (pickers != null) {
        let picker = new pickers.new(opts, {
            prompt_title: "Just tasks",
            border: {},
            borderchars: config.telescope_borders.preview,
            finder: new finders.new_table({
                results: tasks,
                entry_maker: (entry) => {
                    return {
                        value: entry,
                        display: entry[1],
                        ordinal: entry[1]
                    }
                }
            }),
            sorter: new conf.generic_sorter(opts),
            attach_mappings: (buf, map) => {
                actions.select_default.replace(() => {
                    new actions.close(buf);
                    let selection = new action_state.get_selected_entry();
                    let build_name = selection.value[2];
                    task_runner(build_name);
                });
                return true;
            }
        });
        picker.find();
    } else {
        new vim.ui.select(tasks, {
            prompt: "Select task"
        }, function(choice) {
            task_runner(choice);
        });
    }
}

export function run_task_select() {
    let tasks = get_task_names();
    if (tasks.length == 0) {
        warning("There are no tasks defined in justfile");
        return;
    }

    if (pickers != null) {
        task_select(new themes.get_dropdown({ borderchars: config.telescope_borders }));
    } else {
        task_select();
    }
}

export function run_task_name(task_name) {
    let tasks = get_task_names();
    if (tasks.length == 0) {
        warning("There are no tasks defined in justfile");
        return;
    }
    for (let i = 0; i < tasks.length; ++i) {
        let opts = tasks[i + 1][2].split('_');
        if (opts.length == 1) {
            if (opts[1].lower() == task_name) {
                task_runner(tasks[i + 1][2]);
                return;
            }
        }
    }
    warning("Could not find just task. \nPlease select task from list.");
    run_task_select();
}

export function stop_current_task() {
    if (async_worker != null) async_worker.shutdown();
    async_worker = null;
}

function run_task_cmd(args) {
    if (args.bang) stop_current_task();

    if (args.fargs.length == 0) {
        run_task_name("default");
    } else {
        run_task_name(args.fargs[1]);
    }
}

export function add_task_template() {
    let justfile = `${new vim.fn.getcwd()}/justfile`;
    if (new vim.fn.filereadable(justfile) == 1) {
        let opt = new vim.fn.confirm("Justfile already exists in this project, create anyway?", "&Yes\n&No", 2);
        if (opt != 1) return;
    }

    let f = new io.open(justfile, "w");
    let empty = "";
    f.write(
        `#!/usr/bin/env -S just --justfile${empty}
# just reference  : https://just.systems/man/en/

@default:
    just --list
`
    );
    f.close();

    info("Template justfile created");
}

export function add_make_task_template() {
    let justfile = `${new vim.fn.getcwd()}/justfile`;
    if (new vim.fn.filereadable(justfile) == 1) {
        let opt = new vim.fn.confirm("Justfile already exists in this project, create anyway?", "&Yes\n&No", 2);
        if (opt != 1) return;
    }

    let f = new io.open(justfile, "w");
    let empty = "";
    f.write(
        `#!/usr/bin/env -S just --justfile${empty}
# just reference  : https://just.systems/man/en/

@default:
    just --list

build file: (track file) && (hash file)
    echo "Compiling file"

# Don't forget to add '.hashes' to gitignore
[private]
[no-exit-message]
track file:
    #!/usr/bin/env bash
    [ ! -f .hashes ] && touch .hashes
    [[ "$(md5sum {{file}} | head -c 32)" == "$(grep " {{file}}$" .hashes | head -c 32)" ]] && exit 1 || exit 0

[private]
hash file: (track file)
    #!/usr/bin/env bash
    echo "$(grep -v " {{file}}$" .hashes)" > .hashes && md5sum {{file}} >> .hashes
`
    );
    f.close();

    info("Template make justfile created");

}

function table_to_dict(tbl) {
    let out = {};
    for (let [key, value] in tbl) {
        out[key] = value;
    }
    return out;
}

function get_bool_option(opts, key, p_default) {
    if (opts[key] != null) {
        if (opts[key] == true) return true;
        if (opts[key] == false) return false;
    }
    return p_default;
}

function get_any_option(opts, key, p_default) {
    if (opts[key] != null) {
        return opts[key];
    }
    return p_default;
}

function get_subtable_option(opts, key, sub_key, p_default) {
    if (opts[key] != null) {
        let o = opts[key];
        if (o[sub_key] != null) {
            return o[sub_key];
        }
    }
    return p_default;
}

export function setup(opts) {
    opts = table_to_dict(opts);

    config.message_limit = get_any_option(opts, "fidget_message_limit", config.message_limit);
    config.play_sound = get_bool_option(opts, "play_sound", config.play_sound);
    config.copen_on_error = get_bool_option(opts, "open_qf_on_error", config.copen_on_error);
    config.copen_on_run = get_bool_option(opts, "open_qf_on_run", config.copen_on_run);
    config.copen_on_any = get_bool_option(opts, "open_qf_on_any", config.copen_on_any)
    config.telescope_borders.prompt = get_subtable_option(opts, "telescope_borders", "prompt", config.telescope_borders.prompt);
    config.telescope_borders.results = get_subtable_option(opts, "telescope_borders", "results", config.telescope_borders.results);
    config.telescope_borders.preview = get_subtable_option(opts, "telescope_borders", "preview", config.telescope_borders.preview);

    new vim.api.nvim_create_user_command("Just", run_task_cmd, { nargs: "?", bang: true, desc: "Run task" })
    new vim.api.nvim_create_user_command("JustSelect", run_task_select, { nargs: 0, desc: "Open task picker" })
    new vim.api.nvim_create_user_command("JustStop", stop_current_task, { nargs: 0, desc: "Stops current task" })
    new vim.api.nvim_create_user_command("JustCreateTemplate", add_task_template, { nargs: 0, desc: "Creates template for just" })
    new vim.api.nvim_create_user_command("JustCreateMakeTemplate", add_make_task_template, { nargs: 0, desc: "Creates make-like template for just" })

    if (config.play_sound && new vim.fn.executable("aplay") != 1) {
        config.play_sound = false;
        error("Failed to find 'aplay' binary on system. Disabling just.nvim play_sound");
    }
}



