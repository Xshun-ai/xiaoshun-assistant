# 校园助手

面向顺德职业技术大学学生的非官方 Flutter 校园客户端，支持 Android / Linux。

> **本项目是非官方客户端，与顺德职业技术大学无隶属关系。**

仓库地址：https://github.com/Xshun-ai/xiaoshun-assistant

## 开源范围

本仓库只包含学校直连功能。

## 功能

- 学校统一认证登录
- 课程表、成绩、绩点、教学计划
- 智慧学工综合评测总分与班级/专业排名
- 融合门户公告
- 校园地图（仓库不内置标注数据，需自行提供）
- 设置

## 环境要求

- Flutter 3.x（项目 SDK 约束 `^3.10.0`）
- Dart 3.10+
- Android SDK（构建 Android 时）
- Linux 桌面依赖（构建 Linux 时）

## 本地运行

```bash
flutter pub get
flutter run --dart-define=APP_ENV=dev
```

## 构建

```bash
flutter build apk --release --dart-define=APP_ENV=prod
```

Linux：

```bash
flutter build linux --release --dart-define=APP_ENV=prod
```

## Android 签名

Android 包名为 `io.github.xshunai.campusassistant`。

1. 复制 `android/key.properties.example` 为 `android/key.properties`。
2. 填入你自己的 keystore 路径和口令。
3. 不要提交 `android/key.properties`、`*.jks`、`*.keystore`。

调试构建不需要 release keystore；release 构建必须提供签名配置。

## 校园地图数据

`assets/json/campus_markers.json` 默认只包含分类和空的 `markers` 数组，仓库**不提供**具体校园标注点。

如需使用地图标注，请自行准备有权使用的数据并填入：

```json
{
  "categories": [{"id": 1, "name": "教学楼", "icon": "school"}],
  "markers": [
    {"id": 1, "lid": 1, "title": "教学楼1", "latitude": 22.800000, "longitude": 113.300000}
  ]
}
```

## 学校适配

本项目目前只适配顺德职业技术大学的统一认证与业务系统。相关地址集中在 `lib/constants/api_urls.dart`，SSO 门户路径在 `lib/services/sso_service.dart`。如果用于其他学校，需要自行修改这些配置，并确认已获得相应授权。

## 隐私与数据

- 校园账号密码与访问令牌保存在系统安全存储（Android Keystore / Linux Secret Service，通过 `flutter_secure_storage`）。
- 登录 Cookie、课表/成绩等业务缓存保存在应用私有目录；运行日志保存在应用支持目录，默认保留 7 天。
- 本项目不包含统计、广告或第三方追踪 SDK。
- 网络请求只发往学校系统，以及校园地图使用的高德瓦片服务。
- 日志可能包含学号、姓名等信息，可在调试构建的“日志工具”中查看和清理；卸载应用会清除本地数据。

## 安全说明

- 所有学校接口均使用 HTTPS，并启用系统默认证书校验；项目未实现证书固定（certificate pinning）。
- 调试面板只在 debug 构建中可用，并且需要构建时通过 `--dart-define=DEBUG_PANEL_PASSWORD=...` 设置口令。
- 不要提交任何 keystore、`key.properties`、token 或账号信息。

## 目录结构

```text
lib/
├── config/      构建环境配置
├── constants/   接口地址、颜色、尺寸等常量
├── features/    按业务域拆分的页面组件
├── models/      数据模型
├── pages/       页面与 Tab
├── services/    认证、SSO、教务、学工、门户等服务
├── ui/          共享 UI 组件与状态
└── utils/       加密、错误处理、加载状态等工具
```

## 测试与检查

```bash
flutter analyze
flutter test
```

## 第三方组件

见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 许可证

[MIT](LICENSE)。
