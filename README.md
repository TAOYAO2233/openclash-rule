# openclash-rule

个人维护的 OpenClash / Mihomo 分流规则与配置模板合集，包含 Subconverter 订阅转换配置、按服务分类的规则列表，以及日常使用的 Shell、Windows 批处理和 Python 脚本。

仓库以配置文件为主，无需编译。使用代理配置时，需要自行准备客户端、兼容的内核和节点订阅；这里的模板不提供可直接使用的代理节点。

## 内容导航

- [配置怎么选](#配置怎么选)
- [快速开始](#快速开始)
- [规则列表](#规则列表)
- [单独引用规则](#单独引用规则)
- [目录结构与辅助脚本](#目录结构与辅助脚本)
- [常见问题](#常见问题)
- [规则来源](#规则来源)

## 配置怎么选

| 文件 | 用途与特点 |
| --- | --- |
| [`zijian/subconverter/zijian.ini`](zijian/subconverter/zijian.ini) | Subconverter 自定义配置，包含应用分流、地区分组、测速与故障转移，并引用基础 YAML 模板。 |
| [`zijian/Lite version.ini`](zijian/subconverter/Lite%20version.ini) | 另一套订阅转换配置，包含 AI、媒体、广告过滤等规则和多个节点分组；按需删减使用。 |
| [`zijian/subconverter/dnsfxl.ini`](zijian/subconverter/dnsfxl.ini) | 包含住宅 IP、雀魂、AI 等分流的订阅转换配置。 |
| [`qichiyu/qichiyu.ini`](qichiyu/qichiyu.ini) | 使用 `qichiyu/` 下补充规则的订阅转换配置，包含应用、地区及广告过滤分组。 |
| [`zijian/configs/config.yaml`](zijian/configs/config.yaml) | 含订阅提供者、DNS、TUN、策略组和规则提供者的 YAML 配置模板，包含 `relay` 分组。 |
| [`zijian/config dialer.yaml`](zijian/configs/config%20dialer.yaml) | 使用 `dialer-proxy` 的链式代理示例，需填写订阅地址和内联落地节点。 |
| [`zijian/configs/clash.yaml`](zijian/configs/clash.yaml) | 含两个订阅提供者和多级 `relay` 分组的 YAML 配置模板。 |
| [`zijian/overrides/fuxie.yaml`](zijian/overrides/fuxie.yaml) | 全局设置、DNS、策略组与规则的覆写参考，使用前需与原有配置核对合并。 |
| [`zijian/subconverter/base_template.yaml`](zijian/subconverter/base_template.yaml) | 供订阅转换引用的基础模板，包含 Fake-IP DNS、TUN 和嗅探设置，不能单独作为完整节点配置使用。 |
| [`zijian/examples/官方示例.yaml`](zijian/examples/官方示例.yaml) | 配置字段参考示例。 |
| [`zijian/openwrt/openclash`](zijian/openwrt/openclash) | OpenClash 的 OpenWrt UCI 配置参考，不是 Clash YAML 订阅文件。 |

YAML 模板包含 `mrs` 规则集、TUN、`dialer-proxy` 等内核相关字段，优先使用支持相应功能的 Mihomo 内核。部分模板保留了 `relay` 写法，使用前需确认内核版本是否支持；不能只凭文件名判断兼容性。

旧版 `zijian/` 根目录下的文件已按用途迁移至子目录，外部引用也需更新。路径对应关系见 [`zijian/README.md`](zijian/README.md#旧路径迁移)。

## 快速开始

### 方式一：通过订阅转换生成配置

适合已有节点订阅，希望使用本仓库策略组和分流规则的场景。

1. 准备支持 Subconverter 自定义配置的订阅转换服务。
2. 输入自己的节点订阅，选择适合客户端的 Clash / Mihomo 输出类型。
3. 在「远程配置」「自定义配置」或对应的 `config` 参数中填写所选 INI 文件的 Raw 地址，例如：

   ```text
   https://raw.githubusercontent.com/TAOYAO2233/openclash-rule/main/zijian/subconverter/zijian.ini
   ```

4. 生成配置后，检查节点、策略组和规则是否完整，再导入 OpenClash 或其他兼容客户端。
5. 在客户端中选择各服务使用的节点或策略组，并检查连接日志中的规则命中情况。

INI 文件用于订阅转换，不能作为完整 YAML 配置直接导入客户端。转换服务会处理你的订阅地址，请使用可信服务或自行部署。

`zijian.ini` 引用的 `base_template.yaml` 使用了 `private_domain`、`cn_domain`、`cn_ip` 等规则集名称。使用这一组合时，需要在最终配置中补齐对应的 `rule-providers`，或调整相关引用；基础模板本身未定义这些规则集。

### 方式二：修改 YAML 模板后导入

1. 下载所需 YAML 文件，保存为本地配置副本。
2. 将 `proxy-providers` 中的「订阅地址」「机场订阅」或空 URL 替换为自己的 Clash / Mihomo 格式节点订阅。
3. 如使用 `config dialer.yaml`，补全 `provider1.payload` 和 `provider2.payload` 中的落地、住宅节点信息，并分别配置 `🛫 前置节点` 和 `🛫 住宅前置节点`。不使用某个提供者时，应移除其示例配置并核对关联引用。
4. 按运行环境调整监听端口、DNS、TUN、控制面板路径和访问密码。部分模板的控制接口监听 `0.0.0.0:9090` 且 `secret` 为空，使用前应设置访问密码或限制监听范围。
5. 使用客户端的配置检查功能，检查通过后再启用。已安装 Mihomo 时，也可运行：

   ```bash
   mihomo -t -f ./config.yaml
   ```

链式代理需要实际的链路配置：`select` 策略组只负责选择出口，不会将组内节点依次串联。`config dialer.yaml` 的链路由落地节点提供者上的 `override.dialer-proxy` 建立；前置节点不要再选回同一落地节点，以免形成循环。

## 规则列表

`zijian/rules/` 下提供以下补充规则。文件采用 Clash 文本规则语法，例如 `DOMAIN-SUFFIX`、`DOMAIN-KEYWORD` 和 `IP-CIDR`。

| 规则文件 | 内容 |
| --- | --- |
| [`AI.list`](zijian/rules/AI.list) | OpenAI / ChatGPT、Claude、Gemini、Perplexity、Midjourney 等 AI 服务相关域名。 |
| [`Direct.list`](zijian/rules/Direct.list) | 直连补充规则，包含域名及 IP 段。 |
| [`ProxyLite.list`](zijian/rules/ProxyLite.list) | 代理访问补充规则。 |
| [`zhuzhaidaili.list`](zijian/rules/zhuzhaidaili.list) | 用于住宅代理分流的规则，包含 TikTok、Twitter 等相关条目。 |
| [`quehun.list`](zijian/rules/quehun.list) | 雀魂相关域名。 |
| [`hltv.list`](zijian/rules/hltv.list) | HLTV 相关域名及关键字。 |
| [`R18(sq).list`](zijian/rules/R18%28sq%29.list) | 成人内容及 BT 搜索相关域名、关键字。 |

[`qichiyu/`](qichiyu/) 也包含 `AI.list`、`Direct.list` 和 `ProxyLite.list`，内容与 `zijian/rules/` 版本不同，应按所选配置配套使用。

规则文件只有被当前配置引用后才会生效，各模板引用的列表并不完全相同。例如，`zijian.ini` 的 AI 分流引用的是上游 OpenAI 规则，而不是本仓库的 `zijian/rules/AI.list`。

## 单独引用规则

已有配置时，可以只添加需要的规则列表，无需替换整份配置。例如，在兼容的 Clash / Mihomo YAML 配置中引用 AI 列表：

```yaml
rule-providers:
  custom_ai:
    type: http
    behavior: classical
    format: text
    path: ./ruleset/custom_ai.list
    url: https://raw.githubusercontent.com/TAOYAO2233/openclash-rule/main/zijian/rules/AI.list
    interval: 86400

rules:
  - RULE-SET,custom_ai,🤖 AI
  # 后面继续保留原有规则和最终兜底规则
```

将上述条目合并到已有的 `rule-providers` 和 `rules` 中，并确保 `🤖 AI` 策略组已存在，或替换为实际使用的策略组名。

规则按从上到下的顺序匹配，补充规则应放在可能覆盖它的通用规则和最终 `MATCH` 规则之前。同一域名存在多条规则时，以先命中的规则为准。

## 目录结构与辅助脚本

```text
openclash-rule/
├── README.md          # 仓库说明
├── zijian/            # 自定义分流规则与代理配置
│   ├── configs/       # 完整 YAML 配置模板
│   ├── examples/      # 配置字段参考
│   ├── openwrt/       # OpenClash UCI 设置
│   ├── overrides/     # 覆写配置
│   ├── rules/         # .list 分流规则
│   └── subconverter/  # INI 配置与基础 YAML 模板
├── qichiyu/           # 另一套订阅转换配置及配套规则
├── sh-files/          # Linux 运维、视频处理和 Telegram 工具脚本
│   └── v2bx/          # V2bX 安装脚本
├── bat集合/           # Windows 网络接口等批处理脚本
└── python代码/        # 网络流量相关实验脚本
```

辅助脚本独立于分流配置，具体入口包括：

| 类别 | 文件 |
| --- | --- |
| 视频转换与处理 | [`convert_flv_copy_mp4.sh`](sh-files/convert_flv_copy_mp4.sh)、[`convert_flv_to_mp4.sh`](sh-files/convert_flv_to_mp4.sh)、[`viedo_master.sh`](sh-files/viedo_master.sh) |
| 视频下载与推流 | [`download_video.sh`](sh-files/download_video.sh)、[`stream_videos_with_interval.sh`](sh-files/stream_videos_with_interval.sh) |
| Telegram / TDL | [`tdl_commands.sh`](sh-files/tdl_commands.sh)、[`tdl_forward_commands.sh`](sh-files/tdl_forward_commands.sh) |
| 系统与服务管理 | [`linuxcheck.sh`](sh-files/linuxcheck.sh)、[`sshkey_manager.sh`](sh-files/sshkey_manager.sh)、[`monitor_xrayr.sh`](sh-files/monitor_xrayr.sh)、[`delete_old_files.sh`](sh-files/delete_old_files.sh) |

脚本使用说明见 [`sh-files/使用方法.md`](sh-files/使用方法.md)。运行前需阅读所选脚本并修改其中的目录、接口名和服务参数；视频处理依赖 FFmpeg，TDL 相关功能依赖 `tdl`。Windows 批处理中的网络接口名包含 `TAOYAO`，需按本机实际名称调整。

## 常见问题

**导入后没有节点或配置检查失败？**

检查是否误将 INI、基础模板或 UCI 配置当作完整 YAML 导入，再确认订阅 URL 和内联节点占位符已填写、策略组引用存在，以及内核支持所用字段。

**某个地区或住宅节点分组为空？**

这些分组通常通过节点名称的正则表达式筛选。检查订阅中的节点名称是否匹配模板中的 `filter` 或 INI 正则，并按需修改。

**规则没有命中或更新失败？**

确认当前配置确实引用了对应文件，再检查规则顺序、策略组名称以及客户端对 `raw.githubusercontent.com` 和上游规则地址的访问情况。部分模板使用 `GEOSITE` / `GEOIP` 或远程 `mrs` 数据，也需要对应数据库或规则资源可用。

## 规则来源

仓库配置引用或参考了以下项目，具体来源可查看各文件中的链接与注释：

- [ACL4SSR](https://github.com/ACL4SSR/ACL4SSR)
- [blackmatrix7/ios_rule_script](https://github.com/blackmatrix7/ios_rule_script)
- [MetaCubeX/meta-rules-dat](https://github.com/MetaCubeX/meta-rules-dat)

第三方规则的内容与可用性由对应上游维护。修改或反馈本仓库规则时，请注明文件路径、待调整域名、预期策略及实际命中情况，避免提交个人订阅地址或节点凭据。
