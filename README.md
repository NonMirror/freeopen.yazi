# freeopen.yazi

[English](README.EN.md)

`freeopen.yazi` 为 macOS 和 Linux 上 Yazi 的交互式打开菜单底部添加一个 `...` 选项。你可以用任意已安装的 macOS 应用程序打开当前选中项，将选中项传给 Shell 命令，或从自定义目录中选择可执行工具。

文件、目录和混合多选都可以使用。插件会在一次操作中将所有选中项传给应用程序或命令。

没有 Windows 兼容，因为我不用。



## 安装

使用 Yazi 包管理器安装插件：

```text
ya pkg add NonMirror/freeopen
```

在 `init.lua` 中加载插件：

```lua
require("freeopen"):setup()
```

无需添加按键映射。插件扩展了 Yazi 原生的交互式 opener ，其默认按键为 <kbd>O</kbd>。

请将 `setup()` 放在其他注册或修改 opener 规则的初始化代码之后。插件只会添加到执行 `setup()` 时已经存在的 opener 规则中。

## 使用

1. 将光标停在文件或目录上，也可以选中多个项目。
2. 按 <kbd>O</kbd>。
3. 选择 opener 菜单底部的 `...`。
4. 按 <kbd>s</kbd> 选择 `Shell`，或按配置的按键选择自定义打开目录。在 macOS 上还可以按 <kbd>a</kbd> 选择 `Application`。

### Application

Application 仅在 macOS 上可用，在 Linux 菜单中被静默省略。在 macOS 上，Application 操作会扫描配置的应用程序目录，并打开 fzf 选择器。选中一个 `.app` 后，插件会执行相当于以下内容的命令：

```sh
open -a "/path/to/Application.app" "/path/to/target-1" "/path/to/target-2"
```

默认搜索目录为：

```text
/Applications
~/Applications
/System/Applications
```

### Shell

Shell 操作会提示你输入命令，并将每个选中路径作为经过引用的参数追加到命令末尾。例如，选中两个项目后输入：

```sh
file
```

实际执行的命令相当于：

```sh
file "/path/to/target-1" "/path/to/target-2"
```

### 自定义目录

`custom_openers` 中的每个条目都会在 `...` 菜单中添加一项。例如，以下配置会添加按键为 <kbd>t</kbd>、名称为 `Tools` 的选项，并使用 fzf 递归搜索 `~/Tools`：

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

在 macOS 上，选择器会列出 `.app` 应用程序包和普通可执行文件，选择 `.app` 时使用 `open -a`。在 Linux 上，选择器不会列出 `.app`，只会列出普通可执行文件。

## 配置

所有选项均为可选：

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

| 选项                          | 默认值                                  | 说明                                                         |
| ----------------------------- | --------------------------------------- | ------------------------------------------------------------ |
| `application_roots`           | `{ "/Applications", "~/Applications" }` | 仅限 macOS。递归搜索 `.app` 应用程序包的目录。`~/` 会使用 `HOME` 展开。 |
| `include_system_applications` | `true`                                  | 仅限 macOS。将 `/System/Applications` 添加到搜索目录。       |
| `fzf_args`                    | `{}`                                    | 在插件的默认显示参数之后传给 fzf 的额外参数。                |
| `shell_path`                  | `$SHELL`，其次为系统回退值              | Shell 操作使用的交互式 Shell。macOS 回退到 `/bin/zsh`，Linux 回退到 `/bin/sh`；该 Shell 必须支持 `+m` 和 `-ic` 参数。 |
| `custom_openers`              | `{}`                                    | 添加额外菜单项。每个条目都必须包含唯一的 `on`、`name` 和 `path` 字符串。 |
