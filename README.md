# DMS 拼音搜索补丁

为 DankMaterialShell 的启动器（Launcher）添加拼音搜索和拼音首字母搜索支持。

## 功能

- 输入 `weixin` 搜索到「微信」
- 输入 `wx` 搜索到「微信」
- 输入 `zfb` 搜索到「支付宝」
- 支持所有中文应用名的全拼和首字母搜索

## 修改的文件

| 文件 | 改动 |
|------|------|
| `/usr/share/quickshell/dms/Common/PinyinHelper.js` | **新增** — 20924 个汉字的拼音映射表 + 转换函数 |
| `/usr/share/quickshell/dms/Services/AppSearchService.qml` | 搜索时增加拼音/首字母匹配 |
| `/usr/share/quickshell/dms/Modals/DankLauncherV2/Controller.qml` | 给搜索结果附加拼音/首字母字段 |
| `/usr/share/quickshell/dms/Modals/DankLauncherV2/Scorer.js` | 打分时检查拼音/首字母字段 |

## 安装

### 方式一：一键脚本（推荐）

```bash
# 1. 安装依赖
sudo pip3 install pypinyin

# 2. 运行安装脚本
sudo bash ~/dms-pinyin-fix/install.sh

# 3. 重启 DMS
systemctl --user restart dms
```

脚本会自动生成拼音映射数据、打补丁、复制文件。原文件备份为 `.bak` 后缀保留在同目录。

### 方式二：手动安装（系统更新后重装）

```bash
# 需要 root 权限
sudo cp ~/dms-pinyin-fix/PinyinHelper.js /usr/share/quickshell/dms/Common/PinyinHelper.js
sudo cp ~/dms-pinyin-fix/AppSearchService.qml /usr/share/quickshell/dms/Services/AppSearchService.qml
sudo cp ~/dms-pinyin-fix/Controller.qml /usr/share/quickshell/dms/Modals/DankLauncherV2/Controller.qml
sudo cp ~/dms-pinyin-fix/Scorer.js /usr/share/quickshell/dms/Modals/DankLauncherV2/Scorer.js

# 重启 DMS
systemctl --user restart dms
```

### 方式三：全新电脑

```bash
# 1. 复制本目录到新电脑（U盘/scp 等）
# 2. 安装依赖
pip3 install pypinyin
# 3. 运行脚本
sudo bash install.sh
systemctl --user restart dms
```

## 备份

修改后的文件已保存在 `~/dms-pinyin-fix/` 目录下。

## 技术说明

### PinyinHelper.js

- 使用 `.pragma library` 声明为 QML 共享库
- `toPinyinCompact(text)` — 中文转拼音连写，如 `微信` → `weixin`
- `toPinyinInitials(text)` — 中文转拼音首字母，如 `微信` → `wx`
- `hasChinese(text)` — 检测是否包含中文

### 搜索优先级

```
name 精确匹配     (10000)  >  name 前缀     (5000)
> word boundary  (3000)    >  name 子串      (500)
> genericName 前缀 (800)   >  genericName 子串 (400)
> 拼音全拼       (450)     >  拼音首字母     (400)
> id            (350)      >  keyword       (300)
> comment       (50)      >  fuzzy         (100)
```
