# DMS 拼音搜索补丁

为 DankMaterialShell 启动器添加拼音全拼和首字母搜索支持。

## 功能

- `weixin` → 微信
- `wx` → 微信
- `zfb` → 支付宝
- 支持所有中文应用名

## 安装

### 一键安装（推荐）

```bash
git clone https://github.com/SafetyFA/dms-pinyin-search.git
cd dms-pinyin-search
sudo bash install.sh
systemctl --user restart dms
```

### 手动安装

```bash
sudo cp PinyinHelper.js /usr/share/quickshell/dms/Common/
sudo cp AppSearchService.qml /usr/share/quickshell/dms/Services/
sudo cp Controller.qml /usr/share/quickshell/dms/Modals/DankLauncherV2/
sudo cp Scorer.js /usr/share/quickshell/dms/Modals/DankLauncherV2/
systemctl --user restart dms
```

## 修改的文件

| 文件 | 改动 |
|------|------|
| `Common/PinyinHelper.js` | **新增** — 20924 汉字拼音映射 + 转换函数 |
| `Services/AppSearchService.qml` | 搜索加入拼音/首字母匹配 |
| `Modals/DankLauncherV2/Controller.qml` | 搜索结果附加拼音/首字母字段 |
| `Modals/DankLauncherV2/Scorer.js` | 打分阶段检查拼音/首字母 |

## 技术说明

- `toPinyinCompact(text)` — 中文转拼音连写（微信 → weixin）
- `toPinyinInitials(text)` — 中文转首字母（微信 → wx）

搜索优先级：拼音全拼(450) > 拼音首字母(400)，介于 genericName(400) 和 id(350) 之间。
