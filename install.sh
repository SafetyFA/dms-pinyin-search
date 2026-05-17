#!/bin/bash
set -e

# ============================================================
# DMS 拼音搜索补丁 — 一键安装脚本
# 为 DankMaterialShell 启动器添加拼音和首字母搜索
# ============================================================

DMS_DIR="/usr/share/quickshell/dms"

if [ "$(id -u)" -ne 0 ]; then
    echo "需要 root 权限：sudo $0"
    exit 1
fi

if [ ! -d "$DMS_DIR" ]; then
    echo "错误：未安装 DMS ($DMS_DIR)"
    exit 1
fi

echo "=== DMS 拼音搜索补丁 ==="

# ---- 步骤 1: 生成 PinyinHelper.js ----
echo "[1/4] 生成 PinyinHelper.js ..."

PYCMD=$(cat << 'PYEOF'
import json, sys
from pypinyin import pinyin, Style

chars = [chr(i) for i in range(0x4e00, 0x9fff + 1)]
result = {}
for i in range(0, len(chars), 200):
    batch = chars[i:i+200]
    py = pinyin(batch, style=Style.NORMAL, errors='ignore')
    for c, p in zip(batch, py):
        if p and p[0]:
            result[c] = p[0]

items = ["  \"%s\": \"%s\"" % (k, v) for k, v in result.items()]
map_str = "{\n" + ",\n".join(items) + "\n}"

js = """.pragma library

var pinyinMap = %s;

function toPinyinCompact(text) {
  var result = [];
  for (var i = 0; i < text.length; i++) {
    var char = text[i];
    var py = pinyinMap[char];
    if (py) {
      result.push(py);
    } else {
      result.push(char.toLowerCase());
    }
  }
  return result.join("");
}

function toPinyinInitials(text) {
  var result = [];
  for (var i = 0; i < text.length; i++) {
    var char = text[i];
    var py = pinyinMap[char];
    if (py) result.push(py[0]);
  }
  return result.join("");
}

function hasChinese(text) {
  for (var i = 0; i < text.length; i++) {
    if (pinyinMap[text[i]]) return true;
  }
  return false;
}
""" % map_str

with open("/tmp/dms_pinyin/PinyinHelper.js", "w", encoding="utf-8") as f:
    f.write(js)
print("OK (%d entries)" % len(result))
PYEOF

if python3 -c "from pypinyin import pinyin" 2>/dev/null; then
    python3 -c "$PYCMD"
else
    echo "正在安装 pypinyin ..."
    pip3 install pypinyin -q
    python3 -c "$PYCMD"
fi

# ---- 步骤 2: 修改 AppSearchService.qml ----
echo "[2/4] 修改 AppSearchService.qml ..."
FILE="$DMS_DIR/Services/AppSearchService.qml"
cp "$FILE" "${FILE}.bak"
if ! grep -q "PinyinHelper" "$FILE"; then
    sed -i '/^import qs.Common$/a import "..\/Common\/PinyinHelper.js" as PinyinHelper' "$FILE"
fi
if ! grep -q "namePinyin" "$FILE"; then
    sed -i '/} else if (id && id.includes(queryLower)) {/i\
            if (matchType === "none") {\
                const namePinyin = PinyinHelper.toPinyinCompact(name);\
                if (namePinyin && namePinyin.includes(queryLower)) {\
                    textScore = 450;\
                    matchType = "pinyin";\
                } else if (queryLower.length >= 2) {\
                    const initials = PinyinHelper.toPinyinInitials(name);\
                    if (initials && initials.includes(queryLower)) {\
                        textScore = 400;\
                        matchType = "pinyin_initial";\
                    }\
                }\
            }' "$FILE"
fi
echo "  OK"

# ---- 步骤 3: 修改 Scorer.js ----
echo "[3/4] 修改 Scorer.js ..."
FILE="$DMS_DIR/Modals/DankLauncherV2/Scorer.js"
cp "$FILE" "${FILE}.bak"
if ! grep -q "extraNames" "$FILE"; then
    sed -i 's/function calculateTextScore(name, query) {/function calculateTextScore(name, query, extraNames) {/' "$FILE"
    sed -i '/if (name.includes(query)) return Weights.substring/a\
\
    if (extraNames) {\
        for (var i = 0; i < extraNames.length; i++) {\
            var en = extraNames[i];\
            if (en === query) return Weights.exactMatch * 0.8;\
            if (en.startsWith(query)) return Weights.prefixMatch * 0.8;\
            if (en.includes(query)) return Weights.substring * 0.9;\
        }\
    }' "$FILE"
    sed -i 's/var textScore = calculateTextScore(name, q)/var textScore = calculateTextScore(name, q, item._extraSearchNames)/' "$FILE"
fi
echo "  OK"

# ---- 步骤 4: 修改 Controller.qml ----
echo "[4/4] 修改 Controller.qml ..."
FILE="$DMS_DIR/Modals/DankLauncherV2/Controller.qml"
cp "$FILE" "${FILE}.bak"
if ! grep -q "PinyinHelper" "$FILE"; then
    sed -i '/^import "ItemTransformers.js" as Transform$/a import "..\/..\/Common\/PinyinHelper.js" as PinyinHelper' "$FILE"
fi
if ! grep -q "_extraSearchNames" "$FILE"; then
    python3 -c "
with open('$FILE', 'r') as f:
    c = f.read()
old = '''    function searchApps(query) {
        var apps = AppSearchService.searchApplications(query);
        var items = [];

        for (var i = 0; i < apps.length; i++) {
            items.push(getOrTransformApp(apps[i]));
        }

        var coreApps = AppSearchService.getCoreApps(query);
        for (var i = 0; i < coreApps.length; i++) {
            items.push(transformCoreApp(coreApps[i]));
        }

        return items;
    }'''
new = '''    function searchApps(query) {
        var apps = AppSearchService.searchApplications(query);
        var items = [];

        for (var i = 0; i < apps.length; i++) {
            var item = getOrTransformApp(apps[i]);
            var name = item.name || '';
            var extra = [];
            var pinyin = PinyinHelper.toPinyinCompact(name);
            if (pinyin && pinyin !== name.toLowerCase()) {
                extra.push(pinyin);
                var initials = PinyinHelper.toPinyinInitials(name);
                if (initials && initials !== pinyin) {
                    extra.push(initials);
                }
            }
            if (extra.length > 0)
                item._extraSearchNames = extra;
            items.push(item);
        }

        var coreApps = AppSearchService.getCoreApps(query);
        for (var i = 0; i < coreApps.length; i++) {
            var item = transformCoreApp(coreApps[i]);
            var name = item.name || '';
            var extra = [];
            var pinyin = PinyinHelper.toPinyinCompact(name);
            if (pinyin && pinyin !== name.toLowerCase()) {
                extra.push(pinyin);
                var initials = PinyinHelper.toPinyinInitials(name);
                if (initials && initials !== pinyin) {
                    extra.push(initials);
                }
            }
            if (extra.length > 0)
                item._extraSearchNames = extra;
            items.push(item);
        }

        return items;
    }'''
if old in c:
    c = c.replace(old, new)
    with open('$FILE', 'w') as f:
        f.write(c)
    print('OK')
else:
    print('searchApps 格式不匹配，尝试模糊查找...')
    import re
    m = re.search(r'function searchApps\(query\)', c)
    if m: print('  找到 searchApps 函数，请手动检查')
"
fi
echo "  OK"

# ---- 复制文件 ----
cp /tmp/dms_pinyin/PinyinHelper.js "$DMS_DIR/Common/PinyinHelper.js"
echo ""
echo "=== 安装完成！请重启 DMS ==="
echo "  systemctl --user restart dms"
echo ""
echo "备份文件（.bak）保存在原目录"
