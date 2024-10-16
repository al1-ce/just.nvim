local _M = {}

require("jsfunc");
local config = {
	message_limit = 32,
	play_sound = false,
	copen_on_error = true,
	copen_on_run = true,
	copen_on_any = false,
	telescope_borders = {
		prompt = {
			'─',
			'│',
			' ',
			'│',
			'┌',
			'┐',
			'│',
			'│'
		},
		results = {
			'─',
			'│',
			'─',
			'│',
			'├',
			'┤',
			'┘',
			'└'
		},
		preview = {
			'─',
			'│',
			'─',
			'│',
			'┌',
			'┐',
			'┘',
			'└'
		}
	}
};
local pickers = require("telescope.pickers");
local finders = require("telescope.finders");
local conf = require("telescope.config").values;
local actions = require("telescope.actions");
local action_state = require("telescope.actions.state");
local themes = require("telescope.themes");
local async = require("plenary.job");
local progress = require("fidget.progress");
local notify = require("notify");
local async_worker = nil;
local function popup(message, errlvl, title)
	if errlvl == nil then
		errlvl = "info"
	end;
	if title == nil then
		title = "Info"
	end
	local ok = pack2(pcall(require, "notify"))[1];
	if not ok then
		if errlvl == "error" then
			vim.api.nvim_err_writeln(message)
		else
			vim.api.nvim_echo({
				{
					message,
					"Normal"
				}
			}, false, {})
		end
	else
		notify(message, errlvl, {
			title = title
		})
	end
end;
local function info(message)
	popup(message, "info", "Just")
end;
local function error(message)
	popup(message, "error", "Just")
end;
local function warning(message)
	popup(message, "warning", "Just")
end;
local function inspect(val)
	print(vim.inspect(val))
end;
local function get_config_dir()
	return vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":p:h")
end;
local function get_task_names(lang)
	if lang == nil then
		lang = ""
	end
	local arr = {};
	local justfile = string.format([=[%s/justfile]=], vim.fn.getcwd());
	if vim.fn.filereadable(justfile) == 1 then
		local taskList = vim.fn.system(string.format([=[just -f %s --list]=], justfile));
		local taskArray = taskList:split('\n');
		if taskArray[1]:starts_with("error") then
			error(taskList);
			return {}
		end;
		table.shift(taskArray);
		arr = taskArray
	else
		error("Justfile not found in project directory");
		return {}
	end;
	local tbl = {};
	do
		local i = 0
		while i < # arr do
			local name;
			local langname;
			local comment = arr[i + 1]:split('#')[2];
			local options = arr[i + 1]:split('#')[1]:split(' ');
			options = table.filter(options, function(a)
				return a ~= ""
			end);
			if # options == 0 then
				goto continue
			end;
			name = options[1];
			langname = name:split('_')[1]:lower();
			if langname == lang:lower() or lang == "" or langname == "any" then
				local parts = name:split('_');
				local out = "";
				if # parts == 1 then
					out = parts[1]
				else
					out = string.format([=[%s: ]=], parts[1]);
					table.shift(parts);
					out = string.format([=[%s%s]=], out, table.concat(parts, ' '))
				end;
				local width = 34;
				local repeatNum = math.max(0, width - # out);
				out = string.format([=[%s%s %s]=], out, (function()
					local __tmp = ' '
					return __tmp["repeat"](__tmp, repeatNum)
				end)(), (function()
					if comment == nil then
						return "";
					else
						return comment;
					end
				end)());
				table.insert(tbl, {
					out,
					name
				});
				local _null
			end
			::continue::
			i = i + 1
		end
	end;
	return tbl
end;
local function check_keyword_arg(arg)
	repeat
		local caseExp = arg
		if caseExp == "FILEPATH" then
			return vim.fn.expand("%:p")
		elseif caseExp == "FILENAME" then
			return vim.fn.expand("%:t")
		elseif caseExp == "FILEDIR" then
			return vim.fn.expand("%:p:h")
		elseif caseExp == "FILEEXT" then
			return vim.fn.expand("%:e")
		elseif caseExp == "FILENOEXT" then
			return vim.fn.expand("%:t:r")
		elseif caseExp == "CWD" then
			return vim.fn.getcwd()
		elseif caseExp == "RELPATH" then
			return vim.fn.expand('%')
		elseif caseExp == "RELDIR" then
			return vim.fn.expand("%:h")
		elseif caseExp == "TIME" then
			return os.date("%H:%M:%S")
		elseif caseExp == "DATE" then
			return os.date("%d/%m/%Y")
		elseif caseExp == "USDATE" then
			return os.date("%m/%d/%Y")
		elseif caseExp == "USERNAME" then
			return os.getenv("USER")
		elseif caseExp == "PCNAME" then
			return (function()
				local __tmp = vim.fn.system("uname -a")
				return __tmp:split(" ")
			end)()[2]
		elseif caseExp == "OS" then
			return (function()
				local __tmp = vim.fn.system("uname")
				return __tmp:split("\n")
			end)()[1]
		else
			break
		end
	until (false);
	return " "
end;
local function get_task_args(task_name)
	local justfile = string.format([=[%s/justfile]=], vim.fn.getcwd());
	if vim.fn.filereadable(justfile) ~= 1 then
		error("Justfile not found in project directory")
	end;
	local task_info = vim.fn.system(string.format([=[just -f %s -s %s]=], justfile, task_name));
	if task_info:starts_with("alias") then
		task_info = task_info:sub(task_info:find('\n') + 1)
	end;
	if task_info:starts_with('#') then
		task_info = task_info:sub(task_info:find('\n') + 1)
	end;
	local task_signature = task_info:split(':')[1];
	local task_args = task_signature:split(' ');
	table.shift(task_args);
	if # task_args == 0 then
		return {}
	end;
	local out_args = {};
	do
		local i = 0
		while i < # task_args do
			local arg = task_args[i + 1];
			local keyword = check_keyword_arg(arg);
			if keyword == ' ' then
				local ask = "";
				if arg:contains('=') then
					local arg_comp = arg:split('=');
					ask = vim.fn.input(string.format([=[%s: ]=], arg_comp[1]), arg_comp[2])
				else
					ask = vim.fn.input(string.format([=[%s: ]=], arg), "")
				end;
				table.insert(out_args, string.format([=[%s]=], ask))
			else
				if keyword == "" then
					keyword = ' '
				end;
				table.insert(out_args, string.format([=[%s]=], keyword))
			end
			i = i + 1
		end
	end;
	return out_args
end;
local function task_runner(task_name)
	if async_worker ~= nil then
		error("Task is already running");
		return;
	end;
	local args = get_task_args(task_name);
	local justfile = string.format([=[%s/justfile]=], vim.fn.getcwd());
	if vim.fn.filereadable(justfile) ~= 1 then
		error("Justfile not found in project directory");
		return;
	end;
	local handle = progress.handle.create({
		title = "",
		message = string.format([=[Starting task "%s"]=], task_name),
		lsp_client = {
			name = "Just"
		},
		percentage = 0
	});
	local command = string.format([=[just -f %s -d . %s %s]=], justfile, task_name, table.concat(args, " "));
	local should_open_qf = (config.copen_on_run and task_name == "run") or config.copen_on_any;
	if should_open_qf then
		vim.cmd("copen")
	end;
	vim.fn.setqflist({
		{
			text = string.format([=[Starting task: %s]=], command)
		},
		{
			text = ""
		}
	}, 'r');
	if should_open_qf then
		vim.cmd("wincmd p")
	end;
	local start_time = os.clock();
	local append_qf_data = function(data)
		if async_worker == nil then
			return;
		end;
		if data == "" then
			data = " "
		end;
		data = data:replace("warning", "Warning");
		data = data:replace("info", "Info");
		data = data:replace("error", "Error");
		data = data:replace("note", "Note");
		data = data:replace_all("'", "''");
		data = data:replace_all("\0", "");
		vim.cmd(string.format([=[caddexpr '%s']=], data));
		vim.cmd("cbottom");
		if # data > config.message_limit then
			data = string.format([=[%s...]=], data:sub(1, config.message_limit))
		end;
		handle.message = data
	end;
	local on_stdout_func = function(err, data)
		vim.schedule(function()
			append_qf_data(data)
		end)
	end;
	local on_stderr_func = function(err, data)
		local timer = vim.loop.new_timer();
		timer:start(10, 0, vim.schedule_wrap(function()
			append_qf_data(data)
		end))
	end;
	async_worker = async:new({
		command = "bash",
		args = {
			"-c",
			string.format([=[( %s )]=], command)
		},
		cwd = vim.fn.getcwd(),
		on_exit = function(j, ret)
			local end_time = os.clock() - start_time;
			local timer = vim.loop.new_timer();
			timer:start(50, 0, vim.schedule_wrap(function()
				local status = "";
				if async_worker == nil then
					handle.message = "Cancelled";
					handle:cancel();
					status = "Cancelled"
				else
					if ret == 0 then
						handle.message = "Finished";
						handle:finish();
						status = "Finished"
					else
						handle.message = "Failed";
						handle:finish();
						status = "Failed";
						if config.copen_on_error then
							vim.cmd("copen");
							vim.cmd("wincmd p")
						end
					end
				end;
				vim.fn.setqflist({
					{
						text = ""
					},
					{
						text = string.format([=[%s in %s seconds]=], status, string.format("%.2f", end_time))
					}
				}, 'a');
				vim.cmd("cbottom");
				if config.play_sound then
					if ret == 0 then
						(function()
							local __tmp = async:new({
								command = "aplay",
								args = {
									string.format([=[%s/build_success.wav]=], get_config_dir()),
									"-q"
								}
							})
							return __tmp:start()
						end)()
					else
						(function()
							local __tmp = async:new({
								command = "aplay",
								args = {
									string.format([=[%s/build_error.wav]=], get_config_dir()),
									"-q"
								}
							})
							return __tmp:start()
						end)()
					end
				end;
				async_worker = nil
			end))
		end,
		on_stdout = on_stdout_func,
		on_stderr = on_stderr_func
	});
	handle.message = string.format([=[Executing task %s]=], task_name);
	if async_worker ~= nil then
		async_worker:start()
	end
end;
local function task_select(opts)
	if opts == nil then
		opts = {}
	end;
	local tasks = get_task_names();
	if # tasks == 0 then
		return;
	end;
	local picker = pickers.new(opts, {
		prompt_title = "Just tasks",
		border = {},
		borderchars = config.telescope_borders.preview,
		finder = finders.new_table({
			results = tasks,
			entry_maker = function(entry)
				return {
					value = entry,
					display = entry[1],
					ordinal = entry[1]
				}
			end
		}),
		sorter = conf.generic_sorter(opts),
		attach_mappings = function(buf, map)
			actions.select_default:replace(function()
				actions.close(buf);
				local selection = action_state.get_selected_entry();
				local build_name = selection.value[2];
				task_runner(build_name)
			end);
			return true
		end
	});
	picker:find()
end;
local function run_task_select()
	local tasks = get_task_names();
	if # tasks == 0 then
		warning("There are no tasks defined in justfile");
		return;
	end;
	task_select(themes.get_dropdown({
		borderchars = config.telescope_borders
	}))
end;
local function run_task_name(task_name)
	local tasks = get_task_names();
	if # tasks == 0 then
		warning("There are no tasks defined in justfile");
		return;
	end;
	do
		local i = 0
		while i < # tasks do
			local opts = tasks[i + 1][2]:split('_');
			if # opts == 1 then
				if opts[1]:lower() == task_name then
					task_runner(tasks[i + 1][2]);
					return;
				end
			end
			i = i + 1
		end
	end;
	warning("Could not find just task. \nPlease select task from list.");
	run_task_select()
end;
local function run_task_default()
	run_task_name("default")
end;
local function run_task_build()
	run_task_name("build")
end;
local function run_task_run()
	run_task_name("run")
end;
local function run_task_test()
	run_task_name("test")
end;
local function stop_current_task()
	if async_worker ~= nil then
		async_worker:shutdown()
	end;
	async_worker = nil
end;
local function add_task_template()
	local justfile = string.format([=[%s/justfile]=], vim.fn.getcwd());
	if vim.fn.filereadable(justfile) == 1 then
		local opt = vim.fn.confirm("Justfile already exists in this project, create anyway?", "&Yes\n&No", 2);
		if opt ~= 1 then
			return;
		end
	end;
	local f = io.open(justfile, "w");
	local empty = "";
	f:write(string.format([=[#!/usr/bin/env -S just --justfile%s
# just reference  : https://just.systems/man/en/

@default:
    just --list
]=], empty));
	f:close();
	info("Template justfile created")
end;
local function add_make_task_template()
	local justfile = string.format([=[%s/justfile]=], vim.fn.getcwd());
	if vim.fn.filereadable(justfile) == 1 then
		local opt = vim.fn.confirm("Justfile already exists in this project, create anyway?", "&Yes\n&No", 2);
		if opt ~= 1 then
			return;
		end
	end;
	local f = io.open(justfile, "w");
	local empty = "";
	f:write(string.format([=[#!/usr/bin/env -S just --justfile%s
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
]=], empty));
	f:close();
	info("Template make justfile created")
end;
local function table_to_dict(tbl)
	local out = {};
	for key, value, __ in pairs(tbl) do
		out[key] = value
	end;
	return out
end;
local function get_bool_option(opts, key, p_default)
	if opts[key] ~= nil then
		if opts[key] == true then
			return true
		end;
		if opts[key] == false then
			return false
		end
	end;
	return p_default
end;
local function get_any_option(opts, key, p_default)
	if opts[key] ~= nil then
		return opts[key]
	end;
	return p_default
end;
local function get_subtable_option(opts, key, sub_key, p_default)
	if opts[key] ~= nil then
		local o = opts[key];
		if o[sub_key] ~= nil then
			return o[sub_key]
		end
	end;
	return p_default
end;
local function setup(opts)
	opts = table_to_dict(opts);
	config.message_limit = get_any_option(opts, "fidget_message_limit", config.message_limit);
	config.play_sound = get_bool_option(opts, "play_sound", config.play_sound);
	config.copen_on_error = get_bool_option(opts, "open_qf_on_error", config.copen_on_error);
	config.copen_on_run = get_bool_option(opts, "open_qf_on_run", config.copen_on_run);
	config.copen_on_any = get_bool_option(opts, "open_qf_on_any", config.copen_on_any);
	config.telescope_borders.prompt = get_subtable_option(opts, "telescope_borders", "prompt", config.telescope_borders.prompt);
	config.telescope_borders.results = get_subtable_option(opts, "telescope_borders", "results", config.telescope_borders.results);
	config.telescope_borders.preview = get_subtable_option(opts, "telescope_borders", "preview", config.telescope_borders.preview);
	vim.api.nvim_create_user_command("JustDefault", run_task_default, {
		desc = "Run default task with just"
	});
	vim.api.nvim_create_user_command("JustBuild", run_task_build, {
		desc = "Run build task with just"
	});
	vim.api.nvim_create_user_command("JustRun", run_task_run, {
		desc = "Run run task with just"
	});
	vim.api.nvim_create_user_command("JustTest", run_task_test, {
		desc = "Run test task with just"
	});
	vim.api.nvim_create_user_command("JustSelect", run_task_select, {
		desc = "Open task picker"
	});
	vim.api.nvim_create_user_command("JustStop", stop_current_task, {
		desc = "Stops current task"
	});
	vim.api.nvim_create_user_command("JustCreateTemplate", add_task_template, {
		desc = "Creates template for just"
	});
	vim.api.nvim_create_user_command("JustMakeTemplate", add_make_task_template, {
		desc = "Creates make-like template for just"
	});
	if config.play_sound and vim.fn.executable("aplay") ~= 1 then
		config.play_sound = false;
		error("Failed to find 'aplay' binary on system. Disabling just.nvim play_sound")
	end
end
_M.task_select = task_select;
_M.run_task_select = run_task_select;
_M.run_task_name = run_task_name;
_M.run_task_default = run_task_default;
_M.run_task_build = run_task_build;
_M.run_task_run = run_task_run;
_M.run_task_test = run_task_test;
_M.stop_current_task = stop_current_task;
_M.add_task_template = add_task_template;
_M.add_make_task_template = add_make_task_template;
_M.setup = setup
return _M
