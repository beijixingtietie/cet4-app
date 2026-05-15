# Flutter SDK 完整安装指南

## 当前状态

✅ Flutter SDK 已安装位置: [C:\Users\10713\flutter](file:///c:/Users/10713/flutter)
❌ Git for Windows 尚未安装

## 第一步: 安装 Git for Windows

1. 下载 Git: https://git-scm.com/download/win
2. 下载 `Windows Installer` 版本
3. 安装选项:
   - 选择默认选项
   - 安装时确保添加到 PATH 系统环境变量 (PATH)
   - Git Bash / Git CMD / Git GUI 都安装上

## 第二步: 验证 Git 安装验证

打开 PowerShell (管理员)
```powershell
git --version
```

## 第三步: 配置 Flutter 环境变量

### 方法1: 使用 Flutter 控制台方式运行配置
1. 右键 `C:\Users\10713\flutter\flutter_console.bat`
2. 进入后运行:
```
flutter --version
flutter doctor
```

### 方法2: 手动添加环境变量设置
1. 右键 "此电脑" -> 属性 -> 高级系统设置 -> 环境变量
2. 系统变量 Path 编辑，添加:
   ```
   C:\Users\10713\flutter\bin
   ```
3. 重启终端，运行:
   ```powershell
   flutter --version
   flutter doctor
   ```

## 第四步: 运行 Flutter Doctor

```
flutter doctor
```

## 第五步: 安装额外依赖

### Android Studio (可选)
1. 下载: https://developer.android.com/studio
2. 配置 `flutter config --android-sdk
3. 安装最新的 SDK 33+
4. 安装 Android SDK Platform-Tools 和 Build-Tools

### Visual Studio 2022
1. 下载: https://visualstudio.microsoft.com/
2. 安装 "C++ 桌面开发" 工作负载

## Build CET4 App 构建命令

完成上述步骤后，进入项目目录:
```
cd C:\Users\10713\Desktop\CET4_English\cet4_app
flutter build web --release
```

## 当前项目快速检查清单

- [ ] 安装 Git for Windows
- [ ] 验证 Git 命令工作
- [ ] 配置 Flutter 环境变量
- [ ] 运行 Flutter 运行 `flutter doctor` 没有错误
- [ ] 运行 `flutter build web`

## 联系方式

如遇到问题，运行 `flutter doctor -v` 获取详细信息。
