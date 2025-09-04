![Platform:macOS](https://img.shields.io/badge/platform-macOS-blue)
![Platform:windows](https://img.shields.io/badge/platform-windows-blue)
![Platform:linux](https://img.shields.io/badge/platform-linux-blue)
![github actions](https://github.com/dongyuwei/hallelujahIM/actions/workflows/github-actions-ci.yml/badge.svg)
[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](http://www.gnu.org/licenses/gpl-3.0)
[![GitHub downloads](https://img.shields.io/github/downloads/dongyuwei/hallelujahIM/total?label=Downloads&labelColor=27303D&color=0D1117&logo=github&logoColor=FFFFFF&style=flat)](https://github.com/dongyuwei/hallelujahIM/releases)

**中文版** | [English Version](README-En.md)

# 🚀 哈利路亚英文输入法 Enhanced

> **本增强版包含 6 项重大改进，显著提升用户体验！**

## ✨ Enhanced 增强功能

### 1️⃣ ⏎ **智能 Enter 键行为**
- **Enter 提交原始输入** - 当未进行候选词导航时
- **Enter 提交选中候选词** - 当已导航选择候选词时
- 保持自然打字流程，尊重用户意图

### 2️⃣ 🚀 **智能 Space 键快速选择**
- **Space 立即选择首个推荐候选词**
- 候选词列表中移除原始输入，仅显示建议词
- 无需导航即可快速选择最佳推荐

### 3️⃣ 📐 **默认横向候选词显示**
- 使用**紧凑横向布局**，更好利用屏幕空间
- 更熟悉高效的界面设计
- 最优屏幕空间利用

### 4️⃣ ⬆️⬇️ **即时箭头键展开**
- 上下箭头键**立即展开**候选词面板
- 无需按两次 - 首次按键即生效
- 流畅响应的导航体验

### 5️⃣ 🔢 **智能数字键选择**
- 数字键 (1-9) 正确选择**当前可见行**的候选词
- 消除视觉位置与实际选择的混淆
- 完美支持多行候选词显示

### 6️⃣ 🔧 **增强可靠性与调试**
- 更好的 macOS 输入法框架 (IMK) 同步
- 全面的调试和错误处理
- 更可靠的候选词选择和导航

---

哈利路亚英文输入法 是 Mac(10.9+ OSX)及 Windows 平台上一款智能英语输入法。其特性如下：

1. 离线词库较大较全，词频精准。参见 Google's [1/3 million most frequent English words](http://norvig.com/ngrams/count_1w.txt).
2. 内置拼写校正功能。不用担心拼写错误，能记住大概字形、发音，本输入法就会自动显示最可能的候选词。
3. 具备 Text-Expander 功能。 本输入法会自动读取定义在用户目录下的`~/.you_expand_me.json` 文件，你可以定义自己常用的词组，比如 `{"yem":"you expand me"}`，那么当输入 `yem` 时会显示 `you expand me`。修改该文件内容后需要重启输入法进程才能生效。
4. 即时翻译功能(显示音标，及英文单词的中文释义)。
5. 支持按拼音来输出对应英文。如输入`suanfa`，输入法会候选词中会显示 `algorithm`。
6. 支持按英文单词的模糊音来输入。 如输入 `cerrage` 或者 `kerrage` 可以得到 `courage` 候选词，也可以输入 `aosome` 或者 `ausome` 来得到 `awesome` 候选词。
7. 按键盘右侧`shift` 键可以在智能英语输入模式与传统英语输入模式间切换。
8. 选词方式：数字键 1~9 及 `Enter` 回车键和 `Space` 空格键均可选词提交。`Space` 空格键选词默认会自动附加一个空格在单词后面，可以在配置页面关闭自动附加空格功能。`Enter` 回车键选词则不会附加空格。

# 下载与安装

## 🚀 **增强版下载（推荐）**

**HallelujahIM Enhanced** - 包含6项重大用户体验改进：

- **macOS 10.12 及以上版本**： 下载 **增强版最新版** : https://github.com/SuperAL/hallelujahIM-enhanced/releases/latest 下载 pkg 自动安装文件

## 📦 **原版下载**

1. 下载编译好的输入法应用（注意：不要点击 "Clone or download"，要从下面的链接下载 pkg 文件或者 exe 文件）

- macOS 10.12 及以上版本： 下载 **原版** : https://github.com/dongyuwei/hallelujahIM/releases/latest 下载 pkg 自动安装文件
- macOS 10.9 ~ 10.11 老版本（Deprecated version）: https://github.com/dongyuwei/hallelujahIM/releases/tag/v1.1.1 需要手动安装 app 文件
- **Windows 版本**: 基于 PIME 移植到 Windows 平台，https://github.com/dongyuwei/Hallelujah-Windows 下载 exe 安装文件
- Linux：https://github.com/fcitx-contrib/fcitx5-hallelujah 感谢[Qijia Liu](https://github.com/eagleoflqj)！
- Android: https://github.com/dongyuwei/Hallelujah-Android 测试版
- iOS: https://github.com/my-private-code/Luckey-SimpleKeyboard 测试版

2. 打开下载后的 hallelujah .pkg 文件，会自动安装、注册、激活哈利路亚输入法。

> **⚠️ Attention:** Mac系统如果本输入法不能正常使用，请退出当前用户重新登录，在 Input source 中手动删除再重新添加 Hallelujah 输入法.

> **⚠️ Attention:** macOS 14 以上系统用户需要在 Input source 中手动添加 Hallelujah 输入法：
<img width="651" alt="image" src="https://github.com/user-attachments/assets/f68fbe99-f62b-496d-9233-3de6f1ad2f87" />
<img width="581" alt="image" src="https://github.com/user-attachments/assets/b2573ad0-3dbf-44c9-80f2-127c96811c66" />



注意：因为本程序不是通过 App store 发布的，Macos 会有下面的安全警告。选中 hallelujah pkg 安装程序，右键点击 `Open` 来打开，即可开始安装输入法。

![unidentified](https://github.com/dongyuwei/hallelujahIM/blob/master/snapshots/unidentified.png?raw=true)

# 为什么叫 hallelujah 这个名字?

主要是受这篇文章启发： [hallelujah_autocompletion](https://daringfireball.net/2006/10/hallelujah_autocompletion).

# 少数派网友（@北堂岚舞）测评

[英文拼写心里「没底」？这个输入法能把拼音补全为英文：哈利路亚输入法](https://sspai.com/post/56572)

# 偏好设置

点击输入法的 `Preferences` 或者直接访问本地 HTTP 服务: http://localhost:62718/index.html
![preference](https://github.com/dongyuwei/hallelujahIM/blob/master/snapshots/preference.png)

## 编译本输入法

1. `open hallelujah.xcworkspace` 使用 Xcode 打开 `hallelujah.xcworkspace` 工程，注意不是打开 `hallelujah.xcodeproj`。
2. `command + b` 构建.
3. 构建编译后的输入法可以拷贝到 `/Library/Input\ Methods/` 目录内测试。

## 如何调试输入法？

1. 使用 `NSLog()` 在关键或可疑处打 log 日志。
2. 没有 log 输出时，可以查看崩溃日志，位置可通过 `ls -l ~/Library/Logs/DiagnosticReports/ | grep hallelujah` 命令来查找。
3. 深思熟虑。
4. 使用 debug 版 build，在 Xcode 中 `Debug` -> `Attach to Process By PID or Name...` 。这个流程可以 work，但 Xcode 反应会较慢，需要在合适的地方加断点。大杀器，不得已而用之。
5. 自动化测试（后续重构目标就是可测试性要加强）。

## 格式化代码

- `sh format-code.sh`

## CI build

`sh build.sh`

## local dev script

`sh dev.sh`

## 构建安装包 pkg

`bash package/build-package.bash`

## DeepWiki
https://www.deepwiki.com/dongyuwei/hallelujahIM

## 开源协议

GPL3(GNU GENERAL PUBLIC LICENSE Version 3)

## 构建 libmarisa.a

1. The static `libmarisa.a` lib was built from [marisa-trie](https://github.com/s-yata/marisa-trie) @`006020c1df76d0d7dc6118dacc22da64da2e35c4`.
2. To build the `libmarisa.a` lib, run:

```bash
git clone git://github.com/s-yata/marisa-trie.git
cd marisa-trie
brew install autoconf automake libtool -verbose ## proxychains4 -f /usr/local/etc/proxychains.conf brew install autoconf automake libtool -verbose
autoreconf -i
./configure --enable-static
make
## ls -alh lib/marisa/.libs/libmarisa.a
make install ## we can use marisa-build marisa-lookup marisa-reverse-lookup marisa-common-prefix-search marisa-predictive-search marisa-dump marisa-benchmark cli commands to do some tests and pre-build the trie data.
```

## 感谢以下开源项目:

1. [marisa-trie](https://github.com/s-yata/marisa-trie)，输入时前缀匹配的数据结构及算法实现，特点是高性能、节省空间，可以预先构建好 trie 树再反序列化到内存中。
2. dictionary/cedict.json is transformed from [cc-cedict](https://cc-cedict.org/wiki/)，拼音-英语词库。
3. [cmudict](http://www.speech.cs.cmu.edu/cgi-bin/cmudict) and https://github.com/mphilli/English-to-IPA， 国际音标。
4. [GCDWebServer](https://github.com/swisspol/GCDWebServer)，用于用户使用偏好配置。
5. [talisman](https://github.com/Yomguithereal/talisman)，使用其中的 phonex 算法，实现模糊近似音输入。
6. [MDCDamerauLevenshtein](https://github.com/modocache/MDCDamerauLevenshtein)，配合 talisman 的 phonex 算法，在音似词中按 Damerau Levenshtein 编辑距离筛选最接近的候选词。
7. [鼠鬚管 squirrel 输入法](https://github.com/rime/squirrel) 哈利路亚输入法安装包 pkg 的制作 copy/参考了 squirrel 的实现。

## 贡献代码

提交 PR 之前请执行 `sh format-code.sh` 格式化代码。

## 问题反馈，意见和建议

请提交问题单到 https://github.com/dongyuwei/hallelujahIM/issues

## 咨询服务

提供输入法功能定制开发。联系方式：

- 微信: dongyuwei
- gmail: newdongyuwei

### 一些截图

auto suggestion from local dictionary:<br/>
![auto-suggestion](https://github.com/dongyuwei/hallelujahIM/blob/master/snapshots/suggestions.png)
![auto-suggestion](https://github.com/dongyuwei/hallelujahIM/blob/master/snapshots/suggestions2.png)
![auto-suggestion](https://github.com/dongyuwei/hallelujahIM/blob/master/snapshots/suggestions3.png)

Text Expander: <br/>
![Text Expander](https://github.com/dongyuwei/hallelujahIM/blob/textExpander/snapshots/text_expander1.png)
![Text Expander](https://github.com/dongyuwei/hallelujahIM/blob/textExpander/snapshots/text_expander2.png)

translation(inspired by [MacUIM](https://github.com/uim/uim/wiki/What%27s-uim%3F)):<br/>
![translation](https://github.com/dongyuwei/hallelujahIM/blob/master/snapshots/translation.png)

spell check:<br/>
![spell-check](https://github.com/dongyuwei/hallelujahIM/blob/master/snapshots/check.png)
![spell-check](https://github.com/dongyuwei/hallelujahIM/blob/master/snapshots/check2.png)
![spell-check](https://github.com/dongyuwei/hallelujahIM/blob/master/snapshots/check3.png)
![spell-check](https://github.com/dongyuwei/hallelujahIM/blob/master/snapshots/check4.png)
![spell-check](https://github.com/dongyuwei/hallelujahIM/blob/master/snapshots/check5.png)

pinyin in, English out: <br/>
![pinyin](https://github.com/dongyuwei/hallelujahIM/blob/master/snapshots/gaoji.png)
![pinyin](https://github.com/dongyuwei/hallelujahIM/blob/master/snapshots/binmayong.png)
![pinyin](https://github.com/dongyuwei/hallelujahIM/blob/master/snapshots/kexikehe.png)
![pinyin](https://github.com/dongyuwei/hallelujahIM/blob/master/snapshots/laozi.png)
![pinyin](https://github.com/dongyuwei/hallelujahIM/blob/master/snapshots/roujiamo.png)
![pinyin](https://github.com/dongyuwei/hallelujahIM/blob/master/snapshots/xiangbudao.png)

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=dongyuwei/hallelujahIM&type=Date)](https://star-history.com/#dongyuwei/hallelujahIM&Date)
