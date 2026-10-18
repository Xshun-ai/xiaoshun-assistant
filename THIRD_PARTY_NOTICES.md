# 第三方组件与声明

本项目使用或参考了以下第三方组件。完整许可证文本以各组件自带文件为准。

## package_info_plus

- 版本：9.0.1
- 许可证：BSD-3-Clause
- 版权：Copyright 2017 The Chromium Authors
- 位置：`third_party/package_info_plus/`
- 说明：本仓库保留了该组件的 `LICENSE` 文件；`android/build.gradle` 有一处 Kotlin 构建兼容性调整，未修改业务逻辑。

完整许可证见 `third_party/package_info_plus/LICENSE`。

## coordTransform

- 项目：https://github.com/wandergis/coordTransform
- 用途：WGS-84 / GCJ-02 坐标转换算法参考
- 许可证：MIT
- 版权：Copyright (c) 2015 记忆的残骸

```text
The MIT License (MIT)

Copyright (c) 2015 记忆的残骸

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Flutter 与 pub.dev 依赖

其余 Dart/Flutter 依赖均为 pub.dev 上的公开包，其许可证随包分发。可使用 `flutter pub deps` 查看依赖树，并在 pub 缓存或各包目录中查看对应 `LICENSE` 文件。

## 高德地图瓦片

校园地图使用了高德地图的公开瓦片服务。该服务受高德地图的服务条款约束，使用前请自行确认合规性。
