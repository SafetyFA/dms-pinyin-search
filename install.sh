#!/bin/bash
set -e

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
mkdir -p /tmp/dms_pinyin

# 1. 生成 PinyinHelper.js
echo "[1/4] 生成 PinyinHelper.js ..."
if ! python3 -c "from pypinyin import pinyin" 2>/dev/null; then
    echo "  正在安装 pypinyin ..."
    if command -v pacman &>/dev/null; then
        pacman -S --noconfirm python-pypinyin 2>/dev/null || pip3 install pypinyin --break-system-packages -q
    else
        pip3 install pypinyin -q
    fi
fi
python3 << 'PYEOF' || { echo "pypinyin 安装失败"; exit 1; }
import json
from pypinyin import pinyin, Style
chars = [chr(i) for i in range(0x4e00, 0x9fff + 1)]
result = {}
for i in range(0, len(chars), 200):
    batch = chars[i:i+200]
    py = pinyin(batch, style=Style.NORMAL, errors='ignore')
    for c, p in zip(batch, py):
        if p and p[0]:
            result[c] = p[0]
items = []
for k, v in result.items():
    items.append('  "%s": "%s"' % (k, v))
map_str = "{\n" + ",\n".join(items) + "\n}"
js = """.pragma library

var pinyinMap = %s;

function toPinyinCompact(text) {
  var r = [];
  for (var i = 0; i < text.length; i++) {
    var c = text[i];
    var p = pinyinMap[c];
    if (p) r.push(p); else r.push(c.toLowerCase());
  }
  return r.join("");
}

function toPinyinInitials(text) {
  var r = [];
  for (var i = 0; i < text.length; i++) {
    var c = text[i];
    var p = pinyinMap[c];
    if (p) r.push(p[0]);
  }
  return r.join("");
}

function hasChinese(text) {
  for (var i = 0; i < text.length; i++)
    if (pinyinMap[text[i]]) return true;
  return false;
}
""" % map_str
with open("/tmp/dms_pinyin/PinyinHelper.js", "w", encoding="utf-8") as f:
    f.write(js)
print("  OK (%d 汉字)" % len(result))
PYEOF

# 2. 修改 AppSearchService.qml
echo "[2/4] 修改 AppSearchService.qml ..."
f="$DMS_DIR/Services/AppSearchService.qml"
cp "$f" "${f}.bak"
if ! grep -q "PinyinHelper" "$f"; then
    sed -i '/^import qs.Common$/a import "..\/Common\/PinyinHelper.js" as PinyinHelper' "$f"
fi
if ! grep -q "namePinyin" "$f"; then
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
            }' "$f"
fi
echo "  OK"

# 3. 修改 Scorer.js
echo "[3/4] 修改 Scorer.js ..."
f="$DMS_DIR/Modals/DankLauncherV2/Scorer.js"
cp "$f" "${f}.bak"
if ! grep -q "extraNames" "$f"; then
    sed -i 's/function calculateTextScore(name, query) {/function calculateTextScore(name, query, extraNames) {/' "$f"
    sed -i '/if (name.includes(query)) return Weights.substring/a\
    if (extraNames) {\
        for (var i = 0; i < extraNames.length; i++) {\
            var en = extraNames[i];\
            if (en === query) return Weights.exactMatch * 0.8;\
            if (en.startsWith(query)) return Weights.prefixMatch * 0.8;\
            if (en.includes(query)) return Weights.substring * 0.9;\
        }\
    }' "$f"
    sed -i 's/var textScore = calculateTextScore(name, q)/var textScore = calculateTextScore(name, q, item._extraSearchNames)/' "$f"
fi
echo "  OK"

# 4. 修改 Controller.qml
echo "[4/4] 修改 Controller.qml ..."
f="$DMS_DIR/Modals/DankLauncherV2/Controller.qml"
cp "$f" "${f}.bak"
if ! grep -q "PinyinHelper" "$f"; then
    sed -i '/^import "ItemTransformers.js" as Transform$/a import "..\/..\/Common\/PinyinHelper.js" as PinyinHelper' "$f"
fi
if ! grep -q "_extraSearchNames" "$f"; then
python3 << 'PYEOF'
import re
f = "/usr/share/quickshell/dms/Modals/DankLauncherV2/Controller.qml"
with open(f, 'r') as fh:
    c = fh.read()
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
            var name = item.name || "";
            var extra = [];
            var pinyin = PinyinHelper.toPinyinCompact(name);
            if (pinyin && pinyin !== name.toLowerCase()) {
                extra.push(pinyin);
                var initials = PinyinHelper.toPinyinInitials(name);
                if (initials && initials !== pinyin)
                    extra.push(initials);
            }
            if (extra.length > 0) item._extraSearchNames = extra;
            items.push(item);
        }

        var coreApps = AppSearchService.getCoreApps(query);
        for (var i = 0; i < coreApps.length; i++) {
            var item = transformCoreApp(coreApps[i]);
            var name = item.name || "";
            var extra = [];
            var pinyin = PinyinHelper.toPinyinCompact(name);
            if (pinyin && pinyin !== name.toLowerCase()) {
                extra.push(pinyin);
                var initials = PinyinHelper.toPinyinInitials(name);
                if (initials && initials !== pinyin)
                    extra.push(initials);
            }
            if (extra.length > 0) item._extraSearchNames = extra;
            items.push(item);
        }

        return items;
    }'''
if old in c:
    c = c.replace(old, new)
    with open(f, 'w') as fh:
        fh.write(c)
    print("  OK")
else:
    print("  未找到 searchApps 函数，跳过（可能已修改过）")
PYEOF
fi
echo "  OK"

# 复制生成的文件
cp /tmp/dms_pinyin/PinyinHelper.js "$DMS_DIR/Common/PinyinHelper.js"

echo ""
echo "=== 安装完成！重启 DMS 生效 ==="
echo "  systemctl --user restart dms"
echo ""
echo "备份文件（.bak）保存在原目录"
