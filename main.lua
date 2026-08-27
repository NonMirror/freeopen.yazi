local M = {}

local EVENT = "freeopen"
local OPENER = "freeopen"

local DEFAULT_ROOTS = {
	"/Applications",
	"~/Applications",
}

local DEFAULT_FZF_ARGS = {
	"--scheme=path",
	"--layout=reverse",
	"--height=80%",
	"--border",
	"--no-preview",
	"--prompt=Application> ",
}

local get_config = ya.sync(function(state)
	return state.config
end)

local initialize = ya.sync(function(state, config)
	local first = not state.initialized
	state.initialized = true
	state.config = config
	return first
end)

local function notify(content, level)
	ya.notify({
		title = "Free open",
		content = content,
		level = level or "error",
		timeout = 5,
	})
end

local function copy_strings(value)
	local result = {}
	if type(value) ~= "table" then
		return result
	end

	for _, item in ipairs(value) do
		if type(item) == "string" and item ~= "" then
			result[#result + 1] = item
		end
	end
	return result
end

local function append_unique(items, value)
	for _, item in ipairs(items) do
		if item == value then
			return
		end
	end
	items[#items + 1] = value
end

local function make_config(options)
	options = options or {}

	local roots
	if options.application_roots == nil then
		roots = copy_strings(DEFAULT_ROOTS)
	else
		roots = copy_strings(options.application_roots)
	end
	if options.include_system_applications ~= false then
		append_unique(roots, "/System/Applications")
	end

	local shell_path = options.shell_path
	if type(shell_path) ~= "string" or shell_path == "" then
		shell_path = os.getenv("SHELL")
	end
	if not shell_path or shell_path == "" then
		shell_path = "/bin/zsh"
	end

	return {
		application_roots = roots,
		fzf_args = copy_strings(options.fzf_args),
		shell_path = shell_path,
	}
end

local function register_opener()
	rt.opener[OPENER] = {
		{
			run = "ya pub " .. EVENT .. " --list %s",
			desc = "...",
		},
	}

	for _, rule in pairs(rt.open.rules:match()) do
		local uses, found = {}, false
		for _, name in ipairs(rule.use) do
			uses[#uses + 1] = name
			found = found or name == OPENER
		end

		if not found then
			uses[#uses + 1] = OPENER
			rt.open.rules:update({ id = rule.id }, { use = uses })
		end
	end
end

local function expand_home(path)
	local home = os.getenv("HOME")
	if not home then
		return path
	elseif path == "~" then
		return home
	elseif path:sub(1, 2) == "~/" then
		return home .. path:sub(2)
	end
	return path
end

local function existing_roots(config)
	local roots, seen = {}, {}
	for _, root in ipairs(config.application_roots) do
		root = expand_home(root)
		if not seen[root] then
			local cha = fs.cha(Url(root))
			if cha and cha.is_dir then
				seen[root] = true
				roots[#roots + 1] = root
			end
		end
	end
	return roots
end

local function pick_application(config)
	local roots = existing_roots(config)
	if #roots == 0 then
		notify("No application directories are available.")
		return
	end

	local finder, find_err = Command("find")
		:arg(roots)
		:arg({ "-name", "*.app", "-prune", "-print0" })
		:stdout(Command.PIPED)
		:spawn()
	if not finder then
		notify("Failed to scan applications: " .. tostring(find_err))
		return
	end

	local finder_stdout = finder:take_stdout()
	if not finder_stdout then
		finder:start_kill()
		finder:wait()
		notify("Failed to read the application list.")
		return
	end

	local fzf_args = copy_strings(DEFAULT_FZF_ARGS)
	for _, arg in ipairs(config.fzf_args) do
		fzf_args[#fzf_args + 1] = arg
	end
	for _, arg in ipairs({ "--read0", "--print0", "--no-multi", "--no-multi-line" }) do
		fzf_args[#fzf_args + 1] = arg
	end

	local permit = ui.hide()
	local fzf, fzf_err = Command("fzf")
		:arg(fzf_args)
		:stdin(finder_stdout)
		:stdout(Command.PIPED)
		:spawn()
	if not fzf then
		finder:start_kill()
		finder:wait()
		permit:drop()
		notify("Failed to start fzf: " .. tostring(fzf_err))
		return
	end

	local output, wait_err = fzf:wait_with_output()
	local find_status = finder:wait()
	permit:drop()

	if not output then
		notify("Failed to read fzf output: " .. tostring(wait_err))
		return
	elseif output.status.success then
		local selected = output.stdout:match("^[^%z]+")
		if selected and selected ~= "" then
			return selected
		end
	elseif output.status.code == 130 then
		return
	elseif output.status.code == 1 and find_status and find_status.success then
		notify("No applications were found.", "warn")
		return
	end

	notify("fzf exited with code " .. tostring(output.status.code))
end

local function open_with_application(application, targets)
	local args = { "-a", application }
	for _, target in ipairs(targets) do
		args[#args + 1] = target
	end

	local output, err = Command("open"):arg(args):output()
	if not output then
		notify("Failed to start open: " .. tostring(err))
	elseif not output.status.success then
		local detail = output.stderr:gsub("%s+$", "")
		notify(detail ~= "" and detail or "open exited with code " .. tostring(output.status.code))
	end
end

local function trim(value)
	return value:gsub("^%s+", ""):gsub("%s+$", "")
end

local function run_shell(config, targets)
	local command, event = ya.input({
		title = "Shell command:",
		pos = { "top-center", y = 3, w = 70 },
	})
	if event ~= 1 or not command or command == "" then
		return
	end

	local parts = { command }
	for _, target in ipairs(targets) do
		parts[#parts + 1] = ya.quote(target)
	end
	local interactive_command = table.concat(parts, " ")
	local output, err = Command(config.shell_path)
		:arg({ "+m", "-ic", interactive_command })
		:cwd(tostring(fs.cwd()))
		:output()

	if not output then
		notify("Failed to start shell: " .. tostring(err))
	elseif not output.status.success then
		local detail = trim(output.stderr)
		if detail == "" then
			detail = trim(output.stdout)
		end

		local code = output.status.code
		local message = code and "Shell command exited with code " .. tostring(code)
			or "Shell command was terminated"
		notify(detail ~= "" and message .. ":\n" .. detail or message)
	end
end

local function handle(targets)
	if type(targets) ~= "table" or #targets == 0 then
		notify("No files were provided.", "warn")
		return
	end

	local choice = ya.which({
		cands = {
			{ on = "a", desc = "Application" },
			{ on = "s", desc = "Shell" },
		},
		silent = false,
	})
	if not choice then
		return
	end

	local config = get_config()
	if choice == 1 then
		local application = pick_application(config)
		if application then
			open_with_application(application, targets)
		end
	elseif choice == 2 then
		run_shell(config, targets)
	end
end

function M:setup(options)
	if ya.target_os() ~= "macos" then
		notify("freeopen.yazi currently supports macOS only.", "warn")
		return
	end

	local first = initialize(make_config(options))
	register_opener()

	if first then
		ps.sub_remote(EVENT, function(targets)
			ya.async(function()
				handle(targets)
			end)
		end)
	end
end

return M
