# 更新日志

## [2.1.0] - 2026-04-02

### 新特性
- **Codex adversarial-review 插件**：用官方 [Codex 插件](https://github.com/openai/codex-plugin-cc)（`codex@openai-codex`）替代内置 `adversarial-review` skill。代码审查使用 `/codex:adversarial-review`，Codex 不可用时自动回退到 Claude 的 `code-reviewer` agent。插件已包含在默认安装中。
- **技能重命名**：将 `/update` 恢复为 `/update-config`——目录从 `skills/update/` 重命名为 `skills/update-config/`。安装器升级时自动清理旧的 `skills/update` 和 `skills/adversarial-review` 目录。
- **Smart-merge enabledPlugins 策略变更**：从"existing wins"改为"union"——新插件会自动补充到现有配置中，确保升级用户自动获得 `codex@openai-codex` 等新插件。

### 设计理念
- Codex 插件提供官方维护的对抗式审查实现，共享运行时，集成度更高
- 带命名空间的技能命令（`update-config`）防止在所有仓库中意外覆盖项目级 `/update` 命令
- enabledPlugins 的 union 合并确保升级用户自动获得新插件，同时保留现有配置
- 回退审查路径（`code-reviewer` agent）确保没有 Codex CLI 也能正常审查代码

### 注意事项
- Codex 插件需要通过 `codex login` 认证（运行 `/codex:setup` 检查状态）
- `docs/adversarial-review-showcase.md` 作为历史参考保留
- CHANGELOG 中 `update_config` 和 `adversarial-review` 的历史条目保持原样
- 安装器迁移逻辑自动删除旧的 `skills/update` 和 `skills/adversarial-review` 目录

## [2.0.0] - 2026-03-27

### 新特性
- **Auto 模式默认启用**：`settings.json` 现在默认使用 `defaultMode: "auto"` 替代 `bypassPermissions`。Auto 模式（于 2026-03-24 发布）让 Claude 能自主批准安全操作同时拦截高风险操作——更适合高级用户的安全中间地带。安装器会自动检测 Claude Code 版本，低于 2.1.80 的版本自动降级为 `bypassPermissions`。

### 设计理念
- Auto 模式在执行前对每个工具调用进行风险分类，安全操作自动执行，高风险操作被拦截
- `install.sh` 中的版本检测（`_supports_auto_mode`）确保向后兼容，无需用户干预
- 区分"Claude Code 未安装"和"版本过旧"两种情况，提供不同的警告信息

### 注意事项
- Auto 模式需要 Claude Sonnet 4.6 或 Opus 4.6 模型，Haiku、claude-3 系列及第三方服务商（Bedrock、Vertex、Foundry）不支持
- Auto 模式在 Team 计划中为研究预览版，Enterprise 和 API 支持正在逐步推出
- `sed -i` 回退方案替换为可移植的 `sed > tmp && mv`，兼容 macOS

## [1.9.4] - 2026-03-27

### 新特性
- **paper-reading 技能**：用纯 PDF + pymupdf4llm 自动提取流程替换了不稳定的 ar5iv HTML + Playwright 截图方案。图表、矢量图和表格现在通过 `pymupdf4llm.to_markdown(write_images=True)` 直接从 PDF 提取，并自动过滤和重命名。

### 设计理念
- ar5iv 覆盖率不完整——很多论文没有 HTML 版本，导致截图流程完全失败
- pymupdf4llm 将 `get_images()`、`cluster_drawings()` 和 `get_pixmap(clip=...)` 封装为单次调用，自动处理栅格图和矢量图
- 添加优雅降级：纯理论类论文（无实质图表）只输出纯文字摘要

### 注意事项
- 需要安装 `pymupdf4llm` 包（会自动安装 `pymupdf` 作为依赖）
- OCR 默认关闭（`use_ocr=False`），避免对 tesseract 的依赖
- 模板图片占位符从硬编码的 `figure_X.png` 改为 HTML 注释引导

## [1.9.3] - 2026-03-26

### 新特性
- **PUA 插件**：新增 [tanweai/pua](https://github.com/tanweai/pua) 作为新插件组——AI Agent 生产力倍增器，支持多语言（中/英/日），强制穷举式问题解决和系统化调试

### 设计理念
- PUA 是社区热门插件，显著提升 Agent 的持续性和问题解决深度
- 作为可选组（默认关闭）加入，保持轻量安装，不影响不需要的用户

### 注意事项
- 新增市场 `pua-skills`（共 7 个市场，22 个插件）
- install.sh 和 install.ps1 均已更新，支持新插件组、菜单项、调度和卸载
- README.md 和 README.zh-CN.md 均已更新插件表格

## [1.9.2] - 2026-03-20

### 新特性
- **内置 MesloLGS NF 字体**：将在线下载 JetBrainsMono Nerd Font（GitHub ~30MB zip）替换为内置 4 个 MesloLGS NF .ttf 文件（总计约 10MB）——字体安装即时完成，无网络依赖

### 设计理念
- GitHub Release 下载在网络差的环境中缓慢且不稳定，会阻塞整个安装流程
- MesloLGS NF 是成熟的 Nerd Font（Powerlevel10k 使用），提供状态栏所需的相同 Powerline/图标字形
- 将约 10MB 字体内置到仓库是可接受的权衡，优于安装时需要网络访问

### 注意事项
- 字体文件来自 romkatv/powerlevel10k-media（Apache 2.0 许可）
- install.sh 和 install.ps1 均已更新，不再使用 curl/wget/Invoke-WebRequest 下载字体
- 终端字体提示从 'JetBrainsMono Nerd Font' 改为推荐 'MesloLGS NF'

## [1.9.1] - 2026-03-17

### 新特性
- **paper-reading pymupdf 修复**：修复对抗式代码审查发现的 5 个问题——移除阻塞 PDF 图表提取的 Step 1/Step 3 矛盾描述，添加矢量图检测引导（`get_drawings()`/`get_text("dict")`），修复输出路径一致性，明确 `extract_image` 与基于 clip 渲染方式的区别，添加 pymupdf 可用性预检
- **对抗式审查展示**：添加 adversarial-review 技能展示，4 张截图演示跨模型审查工作流（范围分析 → 审查者召集 → 裁决综合 → 主导判断）

### 设计理念
- Step 1 的"无法截图图表"提示与新的 Path B pymupdf 工作流矛盾——按流程操作的 Agent 会在到达图表提取步骤前就停下来
- 矢量图检测至关重要，因为许多研究论文将折线图、图表和表格编码为矢量/文本对象而非栅格图
- `extract_image(xref)` 返回不带页面级注释的原始嵌入图片——基于 clip 的渲染对大多数图表类型更安全，应作为默认方式

### 注意事项
- Path B PDF 图表提取需要 pymupdf（`pip install pymupdf`）
- 对抗式审查展示截图来自真实审查 session

## [1.9.0] - 2026-03-14

### 新特性
- **claude-health 插件**：在交互式安装器中新增 [claude-health](https://github.com/tw93/claude-health) 作为独立插件组——为 Claude Code 会话提供健康检查和状态面板
- **状态栏 Bug 修复**：修复 context 大小为空时 `fmt_ctx()` 的整数比较错误——`local s=$1` 改为 `local s=${1:-0}`，防止 `[: : integer expression expected` 警告

### 设计理念
- claude-health 作为独立组（类似 claude-mem）而非 Essential 的一部分——它是可选的，用户可能不希望有健康监控开销
- 状态栏修复使用 shell 参数展开默认值（`${1:-0}`），POSIX 兼容，同时处理空值和未设置的变量

### 注意事项
- claude-health 市场来源：`tw93/claude-health`（GitHub）
- 插件总数：6 个市场 21 个（之前是 5 个市场 20 个）

## [1.8.2] - 2026-03-13

### 新特性
- **StatusLine 和 Lessons 现在是独立菜单选项**：原来的"Hooks"项拆分为"StatusLine"（渐变进度条 & 用量显示）和"Lessons"（lessons.md 模板 + SessionStart 自动加载 hook）。用户可以单独安装任一项
- **条件式 settings.json 合并**：`statusLine` 和 `hooks.SessionStart` 字段只在对应菜单项被选中时才合并/包含
- **自动启用 settings.json**：选择 StatusLine 或 Lessons 但尚无 settings.json 时会自动启用（配置所必需）
- **jq 不可用警告**：全新安装时没有 jq 会提示无法从 settings.json 中去除未选中字段

### 设计理念
- 解决 issue #12：不想要状态栏的用户现在可以单独取消选择
- 原"Hooks"项将两个不相关的功能捆绑在一起——状态栏显示和 lessons 自动加载，使用场景不同
- `install_statusline()` 现在只复制 `statusline.sh`（而非 hooks/ 下的所有文件），避免未来的 hook 文件被错误捆绑

### 注意事项
- 已有用户重新运行安装器且取消选择 StatusLine/Lessons 时，现有配置保持不变（安全升级——安装器不会删除之前安装的设置）
- 在没有 jq 的系统上，带有部分选择的全新安装会复制完整的 settings.json 模板并警告包含了额外字段

## [1.8.0] - 2026-03-11

### 新特性
- **`/update_config` 技能**：会话内更新命令——在 Claude Code 中输入 `/update_config`，即可检查新版本并重新运行交互式安装器，无需离开当前会话。对比已安装版本和远程 VERSION，下载最新 `install.sh` 并启动交互式选择器。

### 设计理念
- 基于技能的方案（相比独立脚本）让用户只需一个斜杠命令就能在任意 Claude Code 会话中更新，无需切换终端
- 复用现有的 `install.sh` 远程模式和智能合并——无需维护新的更新逻辑

### 注意事项
- 需要网络访问以获取远程 VERSION 和安装器
- 安装器的智能合并会保留现有 `settings.json` 自定义，且永不覆盖 `lessons.md`

## [1.7.0] - 2026-03-11

### 新特性
- **状态栏显示所有虚拟环境**：状态栏现在可检测 conda（包括 `base`）、Python venv、poetry 和 pipenv 环境。优先级：conda > venv/poetry/pipenv
- **README 文档修复**：交互式菜单示例现在列出 humanizer 技能；状态栏描述现在提及虚拟环境显示
- **字体安装改进**：优先使用 `fc-list` 检测而非文件名 glob（可捕获系统安装的字体）；添加明确的下载超时（连接 10s，总计 120s），防止卡住
- **更新状态栏截图**：替换为当前外观的展示图

### 设计理念
- 显示 conda `base` 是有用的——用户希望确认当前激活的环境，即使是默认环境
- `fc-list` 比文件名 glob 更可靠，因为系统打包的字体可能使用不同的命名规范
- 120s 的下载超时与 Nerd Font zip 大小（约 30MB）在慢速连接下匹配，同时避免无限期挂起

### 注意事项
- 虚拟环境检测依赖环境变量（`CONDA_DEFAULT_ENV`、`VIRTUAL_ENV`）；未设置这些变量的手动激活环境不会被检测到
- conda 和 venv 同时激活时，conda 优先

## [1.6.0] - 2026-03-11

### 新特性
- **jq 自动安装（bash）**：`install.sh` 现在通过包管理器（brew/apt/dnf/yum/pacman/apk）自动安装 jq，或将预构建二进制下载到 `~/.claude/bin/jq`——settings.json 智能合并不再静默跳过
- **状态栏显示 conda 环境**：在目录和 git 分支段之间显示当前激活的 conda 环境名
- **重新安装时跳过市场**：安装器在重试前检查 `~/.claude/plugins/marketplaces/{name}` 是否存在，节省重复安装的约 75 秒
- **Emoji 检测 + 文字回退**：状态栏检测 UTF-8 locale、终端类型和 Nerd Font 可用性——在不支持的终端上回退为文字标签（`M:`、`D:`、`py:`、`br:`）
- **Nerd Font 自动安装**：安装器下载并安装 JetBrainsMono Nerd Font 以支持 Powerline git 分支图标；提示用户设置终端字体

### 设计理念
- jq 安装采用分层方案：先检查 PATH，再检查 `~/.claude/bin/`，然后是包管理器（带 sudo），最后是静态二进制下载（无需 sudo）——覆盖 CI、macOS、Linux 桌面和最小化容器
- conda 显示包括所有环境（含 `base`），增强环境感知
- 市场目录检查是"已注册"的最快可靠指标——避免 `claude plugin marketplace add` 在重复添加时报错导致的 5×3s 重试超时
- 图标回退链：emoji（UTF-8 终端）> Nerd Font（fc-list 检测到）> 文字标签（哑终端/非 UTF-8 终端）——确保状态栏始终可读

### 注意事项
- jq 二进制下载需要 `curl` 或 `wget` 及网络访问；包管理器安装可能需要 `sudo`
- Nerd Font 下载约 30MB；用户安装后需手动设置终端字体
- conda 显示读取 `$CONDA_DEFAULT_ENV`——适用于 conda activate，但不适用于直接操作 `python` 路径

## [1.5.1] - 2026-03-09

### 新特性
- **远程安装现在默认交互式**：一行安装（`curl | bash`、`bash <(curl ...)`）会启动交互式选择器——当 stdin 是管道时从 `/dev/tty` 读取键盘，当 stdin 是 tty 时直接从 stdin 读取
- **`confirm()` 提示也支持管道 stdin**：卸载确认提示现在通过相同设备配对输出和输入（管道时用 `/dev/tty`，正常时用 stdout+stdin）
- **集中式终端检测**：单一 `can_interact()` 函数替代了 `parse_args`、`interactive_menu` 和 `confirm` 中的重复检查

### 设计理念
- `bash <(curl ...)` 已保留终端 stdin；`/dev/tty` 回退专门处理 stdin 携带脚本的 `curl URL | bash` 情况
- 当 fd 0 是 tty 时，交互式菜单优先使用 stdin，只将 `/dev/tty` 作为回退——不会影响缺少 `/dev/tty` 的容器
- 只在 stdin 和 `/dev/tty` 均不可用时（如无头 CI）回退到默认安装（仅 essential 插件）

## [1.5.0] - 2026-03-09

### 新特性
- **Windows 交互式安装器**：`install.ps1` 现在与 bash 版本具有相同的方向键交互菜单，使用 `[Console]::ReadKey()` 进行导航
- **Windows CLI 简化**：PowerShell 参数精简为 `-All`、`-Uninstall`、`-Version`、`-DryRun`、`-Force`（与 bash 对齐）
- **Windows 插件组对齐**：Essential（13 个）+ claude-mem（1 个）+ AI Research（6 个）结构现在与 bash 安装器一致
- **Windows 语言规则清理**：取消选择的语言目录会自动删除，与 bash 行为一致

## [1.4.0] - 2026-03-09

### 新特性
- **交互式安装器**：不带参数运行 `./install.sh` 会启动多选菜单——按数字切换组件，Enter 确认
- **插件组简化**：13 个通用插件合并为一个 Essential 组（默认开启）；claude-mem 单独拆出作为独立切换项（默认关闭）
  - Essential（13 个）：everything-claude-code, superpowers, code-review, context7, commit-commands, document-skills, playwright, feature-dev, code-simplifier, ralph-loop, frontend-design, example-skills, github
  - claude-mem（1 个）：独立分出——每 session 注入约 3k tokens（观测索引 + session 摘要）
- **语言规则按需安装**：在交互模式下，Python/TypeScript/Go 规则默认关闭——只安装项目需要的
- **自动清理**：选择特定语言规则时，之前安装的未选中语言目录会自动删除
- **方向键交互菜单**：↑↓ 导航，Enter 切换，Submit 按钮确认
- **CLI 简化**：删除 8 个组件选择标志（`--rules`、`--plugins`、`--mcp`、`--skills`、`--lessons`、`--hooks`、`--claude-md`、`--settings`）；只保留 `--all`、`--uninstall`、`--version`、`--dry-run`、`--force`
- **`--all` 现在安装全部**：包括 MCP 和所有插件组（之前不包括 MCP）

### 设计理念
- 解决 context 累积问题（#7）：默认安装会将约 9k tokens 的规则（包括未使用的语言）+ 大量插件技能列表注入每个 session
- 交互式菜单取代了记忆 CLI 标志的需要——用户一目了然看到所有选项及合理默认值
- CLI 标志删除：组件选择标志与交互式菜单冗余；`--all` 是唯一需要的非交互式安装路径
- claude-mem 单独分出——它是唯一在 SessionStart 时注入约 3k tokens 的插件（观测索引 + session 摘要）；其他 Extended 插件只注册工具/技能名称
- 保留非交互式回退：无 tty 的无头/CI 安装只安装 essential 插件（不含 MCP）；显式 `--all` 安装全部包括 MCP 和所有插件组
- 未知/已删除的 CLI 标志现在报错退出，而非静默降级

### 注意事项
- `--all` 现在安装全部（所有插件、MCP、所有语言规则）
- 远程安装（`bash <(curl ...)`）现在默认显示交互式菜单（v1.5.1+）；添加 `--all` 可非交互式完整安装

## [1.3.0] - 2026-03-09

### 新特性
- 完整卸载现在默认包括插件和 MCP（之前省略）
- 安装警告追踪：合并或插件安装失败时跳过版本戳记并报告警告数
- 卸载前将 `settings.json` 备份为 `settings.json.bak`
- `--all` 标志现在可与其他标志组合（如 `--all --mcp` 安装全部加 MCP）
- Windows 安装器检查 bash 可用性并在缺失时警告（状态栏和 hooks 需要）
- 对抗式审查技能不再需要缺失的 `brain/principles.md`；改用 `reviewer-lenses.md` 作为自包含来源

### Bug 修复
- VERSION 环境变量经过净化，防止远程安装中的命令注入
- 重复安装不再创建嵌套目录（如 `paper-reading/paper-reading/`）
- `stat` 回退顺序修复：优先尝试 Linux `stat -c %Y`，macOS `stat -f %m` 作为回退
- Windows 安装器 AI Research 组中缺少 `tokenization` 插件（5/6 → 6/6）

### 文档
- 自我改进循环措辞说明："auto-saved" → "Claude 根据 CLAUDE.md 指令驱动的纠错写入"
- 卸载示例注释更新为"（含插件和 MCP）"
- 手动插件安装文档更新，包含所有市场 `add` 命令和 `name@marketplace` 语法

### 设计理念
- 警告追踪防止用户误以为部分失败的安装是最新版本
- 卸载时备份 settings 防止意外丢失安装器合并的用户配置
- VERSION 净化关闭了远程安装路径中的真实攻击向量（`bash -c` 接受不可信输入）

### 注意事项
- `bypassPermissions` 默认保持不变（按设计为高级用户配置）
- 对抗式审查仍需要对立 CLI（`codex`/`claude`）——这是设计行为，不是 bug

## [1.2.0] - 2026-03-07

### 新特性
- Windows 支持，带 PowerShell 安装器（`install.ps1`）
- 对抗式代码审查技能（通过对立 AI CLI 进行跨模型审查）
- AI Research 技能组新增 tokenization 插件（huggingface-tokenizers、sentencepiece）
- 跨平台网页搜索日期指令（系统命令 + 回退方案）
- README 导航中新增 Codex 分支链接

### Bug 修复
- 第三方 API 用户的状态栏非阻塞处理
- Bash 3.2 兼容性（用字符串匹配替换关联数组）
- 安装器网络操作重试逻辑（5 次）
- 用量 API 限速时回退到过期缓存

### 设计理念
- PowerShell 安装器镜像 bash 安装器逻辑，实现 Windows 对等
- 对抗式审查替代 codex-cli MCP——跨模型挑战比同模型委派产出更高质量的审查
- 网页搜索日期指令通过优先验证系统时钟确保查询包含当前年份

### 注意事项
- PowerShell 安装器需要 `winget` 安装 `jq`/`gh` 依赖
- 对抗式审查需要安装对立 CLI（Claude 用户需要 `codex`，Codex 用户需要 `claude`）
- 旧仓库名（`claude-code-config`）的 GitHub 重定向仍有效，但规范 URL 现在是 `awesome-claude-code-config`

## [1.1.0] - 2026-03-05

### 新特性
- 渐变状态栏，显示模型、费用和 context 用量
- CLAUDE.md 中的版本变更日志策略
- 项目重命名为 `awesome-claude-code-config`
- 安装器中移除备份逻辑（由智能合并替代）

### 设计理念
- 状态栏提供会话状态的即时感知，不打断工作流
- 变更日志策略确保设计决策与代码同步可追溯

### 注意事项
- 状态栏从 OS 密钥链读取 API 凭证——需要密钥链访问权限
- 重命名可能导致现有书签失效；GitHub 重定向透明处理

## [1.0.0] - 2026-03-02

### 新特性
- 安装器重构：远程安装、智能合并、插件组、卸载、版本管理
- 增强 paper-reading 技能，含深度优先分析和多视角评估
- CLAUDE.md 中的 Code Review 规则
- Codex CLI MCP 服务器集成

### 设计理念
- 插件优先架构：从开源生态安装技能，而非内置捆绑
- 智能合并在升级时保留用户自定义配置
- paper-reading 技能使用 Andrew Ng 的三视角框架进行平衡评估

### 注意事项
- 插件安装器需要 Python 3 和网络访问 GitHub
- MCP 服务器需要单独配置凭证（Lark、GitHub PAT）

## [0.1.0] - 2026-02-25

### 新特性
- 初始版本，包含 CLAUDE.md 全局指令
- 基于 lessons 的自我纠正循环记忆系统
- 插件市场，含 AI 研究、MCP 服务器和 paper-reading 技能
- 飞书/Lark MCP 和 Context7 集成
- 支持插件组的安装器

### 设计理念
- Lessons 驱动的自我改进：记录纠正 → 自动注入 → 稳定模式提升至 CLAUDE.md
- 插件市场分离关注点：CLAUDE.md 管理行为，插件提供领域技能

### 注意事项
- 首个公开版本——API 和配置格式可能变更
