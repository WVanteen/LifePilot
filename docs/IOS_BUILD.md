# iOS 平台构建说明

当前第一周 ZIP 不附带 Flutter SDK 自动生成的 iOS 原生平台目录；Dart/Flutter 代码为跨平台代码。

在 macOS 上安装 Flutter、Xcode 和 CocoaPods，打开含 `pubspec.yaml` 的项目目录：

```bash
flutter create --project-name lifepilot --platforms=ios --org com.example .
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter doctor -v
flutter run
```

如已有 iOS 平台文件，先检查差异，勿用覆盖选项破坏签名或配置。
