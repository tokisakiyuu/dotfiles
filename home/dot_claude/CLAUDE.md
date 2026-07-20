# 全局规则

## 不要猜测第三库行为

如果遇到不明确的第三方库处理逻辑，请联网搜索官方文档以及相关社区帖子来探明，找到断言依据之后请简要解释并贴出原贴URL。

## 代码引用格式

引用代码位置时使用 `path/to/file.ts:42:2` (开头和结尾必须带空格)这种带行号的neovim可识别的格式，方便直接跳转。

## 删除死代码

如果发现死代码请及时清除。

## 简化注释

- 用简单的英语表达
- 只在「为什么」这样做非显而易见时才注释，不要解释「做了什么」
- 函数的注释尽量写在函数开头自己的jsdoc里
- 如果函数逻辑过于冗长或复杂，请考虑拆分成多个独立函数分别解释其行为，不用太过纠结很多函数不会被复用

## 不要自动 git commit

等明确的要求再创建 commit

## 永远不要自动 git push

每一次 push 都必须有用户**当次**的明确指示，之前某一次的 push 授权**不延续**到后续的 commit。commit 完成后停下汇报，等用户决定何时 push。即使 PR 已存在、即使只是"顺手更新 PR"，也不准 push。

## Commit Message

- **必须严格遵循 Angular Conventional Commits**（`type(scope): subject`，type 如 feat/fix/refactor/docs/chore...）。这是硬性要求，不容妥协。
- **绝对禁止**通过 `git log` / commit history 推断 message 格式。即使仓库现有 commit 用别的约定（如 `JIRA-KEY 描述` 前缀），也一律以本条为准，不准跟随历史样式。
- 如没有明确要求，不需要写详细的 message body 和 co-authored-by

## 优先使用 Github CLI

gh 命令应该已经就绪了。

## 优先使用 Jira CLI

jira 命令应该已经就绪了（https://github.com/ankitpokhrel/jira-cli）。
