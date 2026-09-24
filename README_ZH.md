**中文** | [English](README.md)

# KeeStone

[![Release](https://img.shields.io/github/v/release/lyj404/keestone)](https://github.com/lyj404/keestone/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20Android-lightgrey)]()

基于 Flutter 的跨平台 KeePass 兼容密码管理器。

<p align="center">
  <img src="assets/images/screenshot.png" width="600" alt="桌面端">
</p>

## 功能

- KDBX 3.x / 4.x 全兼容（读写、合并同步）
- WebDAV 云同步、TOTP、指纹解锁、Key File 双因素认证
- CSV / KDBX 导入导出，兼容 Chrome、1Password、LastPass、Bitwarden 等
- 文件附件、条目历史、自定义字段、标签与分组
- 密码生成器、自动锁定/保存、剪贴板自动清除、过期提醒
- 本地密码健康审计（弱/重复/过期密码，不联网）
- 系统托盘、键盘快捷键、亮暗主题、中英文

## 安装

从 [Releases](https://github.com/lyj404/keestone/releases) 下载对应平台安装包。

| 平台            | 说明                                                           |
| --------------- | -------------------------------------------------------------- |
| Windows         | 下载 `KeeStone-*-windows-x64.zip`，解压运行 `keestone.exe`     |
| Debian / Ubuntu | `sudo apt install ./keestone_*_amd64.deb`                      |
| Arch Linux      | `yay -S keestone-bin` 或 `paru -S keestone-bin`                |
| Android         | 下载对应架构 APK（`arm64-v8a` / `armeabi-v7a` / `x86_64`）安装。APK 未上架任何应用商店，请仅从 GitHub Releases 下载 |

## 从源码构建

需要 Flutter / Dart SDK >= 3.13.0

```bash
git clone https://github.com/lyj404/keestone
cd keestone
flutter pub get
flutter run -d windows    # 或 linux / android
```

## 技术栈

[Flutter](https://flutter.dev) · [Riverpod](https://pub.dev/packages/flutter_riverpod) · [go_router](https://pub.dev/packages/go_router) · [kpasslib](https://pub.dev/packages/kpasslib) · [WebDAV](https://pub.dev/packages/webdav_client) · [local_auth](https://pub.dev/packages/local_auth)

## 密码健康

在**工具**、更多菜单或**设置**中打开「密码健康」（桌面端与移动端均可）。扫描完全在本地进行，不会上传任何数据。

| 检查项 | 说明 |
| ------ | ---- |
| 空密码 | 条目未设置密码 |
| 弱 / 一般密码 | 强度评分为弱或一般 |
| 重复密码 | 同一密码被两条及以上条目共用 |
| 已过期 | 过期时间已过 |
| 即将过期 | 7 天内过期 |

结果按严重度排序，点击可直接打开条目修改。报告中不会出现明文密码。

## 友链

- [LINUX DO 社区](https://linux.do/)

## 开源协议

[Apache License 2.0](LICENSE)
