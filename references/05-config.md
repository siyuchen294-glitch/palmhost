# 05 · 配置管理：踩过的最贵的一个坑

## 问题

早期版本把**整份配置**写进 `data/config.json`。启动时读它当配置，保存时把内存里整份 CFG 写回去。

看起来没问题，直到我在代码里调参数：

```
代码 DEFAULTS 里 group_rate_per_min 从 6 改成 12 → 没生效
代码 DEFAULTS 里 group_lurk_eval_gap 从 15 改成 8 → 没生效
```

排查半天才发现：`config.json` 里存着**旧版的全量快照**，启动时用旧值覆盖了新默认值。代码越改，文件越「顽固」。

## 解法（v14 起）

确立一条铁律：

> **代码里的 `DEFAULTS` 是唯一事实来源；`data/config.json` 只存「用户确实改过的项」。**

```
启动：CFG = DEFAULTS 打底  →  叠加 config.json 里的覆盖项
保存：只写 diff(DEFAULTS) + _version
```

实机上迁移后的 `config.json` 只有两行：

```json
{ "voice_name": "xiaoyi", "_version": 14 }
```

这才是正确形态：**只有偏离默认值的项才落盘**。

## `_version` 是干什么的

每次改动 `DEFAULTS` 的结构（新增/删除参数），就把 `_version` +1。启动时对比文件里的版本号，决定是否需要迁移：

- 版本落后 → 自动裁剪掉已废弃的键
- 版本相同 → 直接叠加

不设版本号的话，删除某个参数后旧文件里的残键会永远留着，成为幽灵配置。

## 可复用的原则

这套模式适用于任何「有默认值 + 允许用户覆盖」的应用：

| 反模式 | 正模式 |
| --- | --- |
| 启动时整份序列化持久化 | 只持久化与默认值的差异 |
| 默认值写在文件里 | 默认值写在代码里（可版本管理、可 diff） |
| 用户改了什么都写回去 | 与默认值相同的项视为未修改，直接丢弃 |
| 无版本概念 | 带 `_version`，结构变更时迁移 |

## 代价

- 用户想知道「我现在用的是啥」，得看 `/config`（会合并默认值输出全量），不能直接看文件
- 参数改名时必须写迁移逻辑，不能假装没发生

但相比「改代码不生效、且找不到原因」，这点代价完全值得。

## 当前默认值速览

| 参数 | 值 | 含义 |
| --- | --- | --- |
| model / temperature | deepseek-chat / 0.9 | 对话模型 |
| max_turns / context_limit_chars | 12 / 6000 | 记忆轮数 / 压缩阈值 |
| reply_max_chars | 1200 | 单条回复上限 |
| sticker_enabled / max / prob / cooldown | true / 100 / 0.25 / 120s | 表情包 |
| sticker_save_from_others | true | 是否收录别人发的图 |
| auto_approve_friend | false | 好友申请需人工批 |
| voice_mode / voice_name | mirror / xiaoyi | 语音 |
| group_default_mode | mention | 非白名单群默认 |
| group_rate_per_min / group_min_gap_sec | 12 / 2 | 群限流 |
| group_lurk_eval_gap | 8s | 潜水时判断间隔 |
| group_engage_ttl / group_mute_ttl | 150s / 900s | 活跃保持 / 被嫌烦静默 |
| group_sleep_min / group_context_min | 10 / 10 | 休眠阈值 / 上下文窗口（分钟） |
| group_buffer_max | 60 | 群消息缓冲条数 |
