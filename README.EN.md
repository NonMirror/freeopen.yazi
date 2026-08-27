# freeopen.yazi

[简体中文](README.md)

`freeopen.yazi` adds a catch-all `...` entry to Yazi's interactive opener menu on macOS and Linux. Use it to open the current selection with any installed macOS application, pass the selection to a shell command, or choose an executable from a custom directory.

Files and directories are both supported. A mixed selection is passed to the chosen application or command in one operation.

Windows is not supported because I don't use it.

## Installation

Install the plugin with Yazi's package manager:

```sh
ya pkg add NonMirror/freeopen
```

Load it near the end of `init.lua`:

```lua
require("freeopen"):setup()
```

No keymap entry is required. The plugin extends Yazi's native interactive opener, which is bound to <kbd>O</kbd> by default.

Keep `setup()` after any other initialization code that registers or changes opener rules. The plugin appends itself to the opener rules that exist when setup runs.

## Usage

1. Hover a file or directory, or select multiple entries.
2. Press <kbd>O</kbd>.
3. Choose `...` at the bottom of the opener menu.
4. Press <kbd>s</kbd> for Shell or the configured key for a custom opener directory. On macOS, <kbd>a</kbd> also selects Application.

### Application

Application is available on macOS only. It is silently omitted from the Linux menu. On macOS, the action scans the configured application directories and opens an fzf picker. After you select an `.app`, the plugin runs the equivalent of:

```sh
open -a "/path/to/Application.app" "/path/to/target-1" "/path/to/target-2"
```

The default search roots are:

```text
/Applications
~/Applications
/System/Applications
```

### Shell

The Shell action prompts for a command and appends every selected path as a quoted argument. For example, entering:

```sh
file
```

for two selected entries runs the equivalent of:

```sh
file "/path/to/target-1" "/path/to/target-2"
```

### Custom opener directories

Each entry in `custom_openers` adds another action to the `...` menu. For example, this configuration adds <kbd>t</kbd> `Tools` and recursively searches `~/Tools` with fzf:

```lua
require("freeopen"):setup({
	custom_openers = {
		{
			on = "t",
			name = "Tools",
			path = "~/Tools",
		},
	},
})
```

On macOS, the picker includes `.app` bundles and executable regular files. Selecting an `.app` uses `open -a`. On Linux, `.app` bundles are omitted and the picker includes executable regular files only.

## Configuration

All options are optional:

```lua
require("freeopen"):setup({
	application_roots = {
		"/Applications",
		"~/Applications",
	},
	include_system_applications = true,
	fzf_args = {
		"--cycle",
	},
	shell_path = "/bin/zsh",
	custom_openers = {
		{
			on = "t",
			name = "Tools",
			path = "~/Tools",
		},
	},
})
```

| Option                        | Default                                 | Description                                                  |
| ----------------------------- | --------------------------------------- | ------------------------------------------------------------ |
| `application_roots`           | `{ "/Applications", "~/Applications" }` | macOS only. Directories searched recursively for `.app` bundles. `~/` is expanded using `HOME`. |
| `include_system_applications` | `true`                                  | macOS only. Adds `/System/Applications` to the search roots. |
| `fzf_args`                    | `{}`                                    | Additional arguments passed to fzf after the plugin's display defaults. |
| `shell_path`                  | `$SHELL`, then an OS fallback           | Interactive shell used for Shell actions. The fallback is `/bin/zsh` on macOS and `/bin/sh` on Linux. It must accept the `+m` and `-ic` options. |
| `custom_openers`              | `{}`                                    | Additional menu actions. Each entry requires unique `on`, `name`, and `path` strings. |
