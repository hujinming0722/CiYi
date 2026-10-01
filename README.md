# 诗忆 - 古诗背诵工具

基于 Flutter 开发的古诗背诵辅助工具，支持自定义文本导入、4 档难度挖空、备选字交互、薄弱分句复习等功能。

## 功能特性

### 文本导入
- 粘贴任意自定义文本（古诗、文言文、短文）
- 自动按 `。？！；` 分句，支持手动编辑（修改/合并/拆分/删除）
- 可选段落分组，背诵时可选全文或指定段落

### 背诵模式
- **4 档难度**（整篇统一）：
  - 等级 1：少量挖空（隐藏少量实词关键词）
  - 等级 2：保留句首 2~3 个字
  - 等级 3：仅保留句首 1 个字
  - 等级 4：仅保留标点
- 分句逐行展示，当前激活句高亮
- 上一句 / 下一句 / 点击切换激活句
- 显示当前句（仅展开当前句，不影响其他句）
- 重置全文 / 随时切换难度

### 备选字交互
- 页面下方显示 6 个备选字按钮（答案字 + 干扰字）
- 点击备选字 → 严格按顺序填入当前第一个空白
- 填对 → 填入并重新抽取备选字
- 填错 → 弹窗提示正确答案

### 辅助功能
- **提示一下**：显示当前句前 3 个字辅助回忆
- **默写输入**：手动输入当前句原文，自动比对标记对错
- **熟练 / 生疏**：手动标记分句掌握程度

### 复习机制
- 薄弱分句池：标记为生疏的分句统一收集
- 再次打开可选「从头完整背诵」或「仅复习生疏分句」
- 本地 SQLite 存储，无需联网

## 技术栈

- **框架**：Flutter 3.32.8 (Dart 3.8.1)
- **数据库**：sqflite（本地存储）
- **图标生成**：flutter_launcher_icons
- **支持平台**：Android / Linux Desktop

## 项目结构

```
lib/
├── main.dart                      # 应用入口
├── models/
│   └── poem.dart                  # 数据模型（篇目、段落分组）
├── database/
│   └── database_helper.dart       # SQLite 数据库操作
├── utils/
│   ├── sentence_splitter.dart     # 分句工具
│   └── difficulty_renderer.dart   # 难度渲染器（4 档挖空逻辑）
└── pages/
    ├── home_page.dart             # 首页（文本库）
    ├── text_input_page.dart       # 文本导入页
    ├── split_page.dart            # 分句预处理页
    ├── recite_page.dart           # 背诵主界面
    └── detail_page.dart           # 文本详情页
```

## 构建与运行

### 环境要求
- Flutter SDK 3.32+
- Java 17（Android 构建）
- Android SDK（含 NDK 27.0.12077973）

### 构建 APK
```bash
flutter pub get
flutter build apk --debug          # 调试版（约 90MB）
flutter build apk --release        # 发布版（约 15-25MB）
```

### 安装到手机
```bash
adb install build/app/outputs/flutter-apk/app-debug.apk
```

### Linux 桌面运行
```bash
flutter run -d linux
```

## 版本历史

- **v1.0.0**：初始版本
  - 文本导入、分句预处理、4 档难度背诵
  - 备选字交互、提示一下、默写输入
  - 熟练/生疏标记、薄弱分句复习池
  - 自定义应用图标
