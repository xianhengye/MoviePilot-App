# iPhone Duo 与直板 iPhone 的自适应导航

此 fork 在保持单一 WKWebView、前端路由及权限校验的基础上，为展开后的宽屏增加原生侧栏。

## 显示行为

| 窗口状态 | 导航与操作 |
| --- | --- |
| iPhone 18 等直板机型竖屏、Duo 外屏或窄窗口 | 保留原底部标签栏和独立动作按钮 |
| regular 宽度和高度、可用宽度至少 640 pt、高度至少 500 pt | 标签栏变为侧栏，展示原主入口及已授权的“更多”目录；搜索位于侧栏底部 |
| 直板机型横屏／compact 高度 | 保留底部导航，不挤出狭窄的内容列 |
| 宽屏且内容列至少 600 pt、页内分类不超过 4 项 | 顶部直接展示分段分类；窄屏、大字号或更多分类仍使用下拉菜单 |
| 网页全屏展示 | 同时收起侧栏、底栏及其占位 |
| 网页浮层打开 | 禁用背景导航，防止越过当前业务弹窗 |

侧栏使用 UIKit 的 sidebar 列表样式、系统材质和 Dynamic Type。通常宽 240 pt，中等宽度窗口可收窄至 200 pt，内容列至少保留 440 pt。无障碍字号使用 280 pt 侧栏；空间不足时保留底部导航。布局使用 leading/trailing 约束，支持从右到左语言。

展开、折叠、旋转、尺寸类别和安全区变化只重新量测现有宿主，不创建另一份 WKWebView，不重新登录、不加载页面、不发送路由切换命令。选择入口或分类时，选中状态仍等待前端确认。返回手势在展开时只作用于内容列；尺寸变化时取消过期的手势快照。快捷面板锚点及宽度随内容列更新。

这里不根据 `iPhone19,4` 等设备标识决定布局，也不将 hinge 角度直接解释为内容尺寸。系统的尺寸类别、窗口几何和安全区才是布局依据；这也覆盖分屏、窗口缩放及未来机型。

## 官方依据

- [Apple HIG — Layout](https://developer.apple.com/design/human-interface-guidelines/layout)：依据 size classes 和可用空间布局；宽屏可将 tab bar 改为 sidebar、展开 overflow 中的操作；保留相同功能。
- [Apple HIG — Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars)
- [Apple HIG — Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)
- [UIHingeInteraction](https://developer.apple.com/documentation/uikit/uihingeinteraction)：系统可提供 hinge 状态，但此导航无需读取角度即可响应布局变化。

## 验证

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer zsh scripts/test-core.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project ios/MoviePilot.xcodeproj -scheme MoviePilot \
  -destination 'platform=iOS Simulator,id=你的模拟器UUID' \
  -only-testing:MoviePilotLayoutTests CODE_SIGNING_ALLOWED=NO
```

`MoviePilotLayoutTests` 在真实 ShellController 上注入合成导航快照和本地 HTML，验证宽窄反复切换、同一网页与输入保留、隐藏底栏后释放安全区、全屏、横屏、背景导航禁用、大字号及 RTL。测试不连接 MoviePilot 实例，也不使用真实登录凭据。

真机验收需要在 Duo 上分别展开／折叠并旋转，检查搜索键盘、弹窗、返回和真实业务列表；直板 iPhone 18 则检查竖屏和横屏。模拟尺寸测试不能替代特定硬件的系统行为验证。

个人签名只用于本机构建，不提交 Apple 账号、Team ID、证书或 provisioning profile。主 App 与 Widgets 继续使用同一共享组。
