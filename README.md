# 弈筹机

弈筹机是一款德州扑克牌局记录、胜率计算与行动线复盘工具。App 使用 SwiftUI 原生实现，计算逻辑在本地完成，不依赖接口，不集成第三方 SDK。

## 核心功能

- 牌局页：录入小盲、大盲、我的手牌、公共牌、最多 9 位玩家的位置、手牌与码量。
- 复盘页：以长方形 9 人桌展示座位、底池、下注、行动顺序与摊牌结果。
- 行动线：按玩家顺序记录下注、跟注、加注、弃牌、过牌、全下等动作。
- 胜率计算：结合已知手牌、公共牌、随机补牌与行动阶段计算当前胜率。
- 开牌逻辑：全下或河牌跟注后展示此前隐藏的手牌并给出结果。

## 隐私与网络

- 不需要登录账号。
- 不连接服务器。
- 不上传牌局、手牌、码量或行动线。
- 不使用广告、分析或第三方追踪 SDK。
- 用户输入的数据仅用于当前设备上的本地计算与展示。

## 构建信息

- App 名称：弈筹机
- Bundle ID：`liyan.startdezhou`
- 版本：`1.0 (1)`
- 平台：iOS / iPadOS
- 技术栈：SwiftUI、Foundation、Combine

## 发布材料

- App Store 截图：`AppStoreScreenshots/`
- 支持页：`docs/support.html`
- 隐私政策：`docs/privacy-policy.html`
- 商店文案：`AppStoreRelease/app-store-metadata-zh-Hans.md`

## App Store 链接

- Support URL：https://jackliyan.github.io/startdezhou/support.html
- Privacy Policy URL：https://jackliyan.github.io/startdezhou/privacy-policy.html

## 品牌

© 2026 莫深造物 / MOSEN STUDIO
