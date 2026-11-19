# 自建分流规则与代理配置

按用途管理 Clash / Mihomo 配置、分流规则、订阅转换模板和 OpenClash 插件设置。

## 目录导航

| 目录 | 用途 | 文件 |
| --- | --- | --- |
| [rules/](rules/) | 分流规则集 | 7 个 `.list` 文件，见下表 |
| [configs/](configs/) | 完整配置 | `config.yaml`、`config dialer.yaml`、`clash.yaml` |
| [overrides/](overrides/) | 覆写配置 | `fuxie.yaml` |
| [subconverter/](subconverter/) | 订阅转换配置与基础模板 | `zijian.ini`、`dnsfxl.ini`、`Lite version.ini`、`base_template.yaml` |
| [openwrt/](openwrt/) | OpenClash 插件的 OpenWrt UCI 设置 | `openclash` |
| [examples/](examples/) | 配置参考 | `官方示例.yaml` |

## 分流规则

| 文件 | 用途 |
| --- | --- |
| [AI.list](rules/AI.list) | OpenAI、Claude、Gemini、Perplexity、Midjourney、Mistral、Grok 等 AI 服务 |
| [Direct.list](rules/Direct.list) | 直连补充列表 |
| [ProxyLite.list](rules/ProxyLite.list) | 代理补充列表 |
| [zhuzhaidaili.list](rules/zhuzhaidaili.list) | 需要住宅代理的网站，如 TikTok、Twitter |
| [quehun.list](rules/quehun.list) | 雀魂相关域名 |
| [hltv.list](rules/hltv.list) | HLTV 网站专用规则 |
| [R18(sq).list](rules/R18%28sq%29.list) | R18 网站、BT 搜索相关规则 |

## 配置说明

- [config.yaml](configs/config.yaml) 和 [clash.yaml](configs/clash.yaml)：包含订阅提供者、策略组、DNS 和分流规则的完整配置。
- [config dialer.yaml](configs/config%20dialer.yaml)：包含 `dialer-proxy` 链式代理设置的完整配置。
- [fuxie.yaml](overrides/fuxie.yaml)：覆写配置，包含全局设置、DNS、策略组和规则。
- [zijian.ini](subconverter/zijian.ini)：Subconverter 自定义配置，通过 `clash_rule_base` 引用同目录的 [base_template.yaml](subconverter/base_template.yaml)。基础模板提供 DNS、TUN 和流量嗅探设置。
- [dnsfxl.ini](subconverter/dnsfxl.ini) 和 [Lite version.ini](subconverter/Lite%20version.ini)：其他订阅转换配置方案。
- [openclash](openwrt/openclash)：OpenWrt UCI 格式的插件设置，`custom_template_url` 指向 `subconverter/zijian.ini`。
- [官方示例.yaml](examples/官方示例.yaml)：配置选项参考。

## 旧路径迁移

文件按以下对应关系迁移，文件名保持不变：

| 旧位置 | 新位置 |
| --- | --- |
| `zijian/*.list` | `zijian/rules/*.list` |
| `zijian/config.yaml`、`zijian/config dialer.yaml`、`zijian/clash.yaml` | `zijian/configs/` 下的同名文件 |
| `zijian/fuxie.yaml` | `zijian/overrides/fuxie.yaml` |
| `zijian/*.ini`、`zijian/base_template.yaml` | `zijian/subconverter/` 下的同名文件 |
| `zijian/openclash` | `zijian/openwrt/openclash` |
| `zijian/官方示例.yaml` | `zijian/examples/官方示例.yaml` |

本地配置中的相关 GitHub Raw 引用已同步更新，包括相邻 `openclash配置文件/` 目录中的 3 个 YAML；历史 `.bak-*` 备份保留原样。

发布到 GitHub 后，外部订阅转换服务、客户端和脚本也需要切换到新路径。旧路径未保留兼容副本；新地址需要在文件上传到对应仓库和分支后才能使用。
