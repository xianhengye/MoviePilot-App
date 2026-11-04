# iPhone Duo 系统导航与原版隔离

## 两套界面实现

- `ios/MoviePilot/ShellController.swift` 与 `BottomNavigationView.swift` 保留上游 `aee8fc31ef29ad36a5833529df1f71b95fe8e41f` 的原始内容。Python 回归校验 SHA-256，防止 Duo 调整意外改动原版导航。
- `DeviceShellFactory` 在建立认证后的界面时选择实现。只有已确认的 Duo 型号 `iPhone19,4` 使用 `Duo/DuoShellController.swift`；iPhone 18、其他直板机型、iPad 和未知型号使用原版。
- 真机通过 `uname` 获取型号，模拟器使用系统的 `SIMULATOR_MODEL_IDENTIFIER`。不根据屏幕宽度、设备名称或系统版本猜测型号。
- 两套界面通过 `NativeShell` 共用原有登录、WebCoordinator、单一 WebView 和业务通信。协议遵循在独立文件声明，不修改原版界面文件。
- Duo 独立维护导航宿主；上游修复需分别审查并移植到两个实现。新增 Duo 型号须验证后加入策略。

## Duo 使用系统侧边控制区

Duo 使用 `UITabBarController` 管理主入口和 `UISearchTab`，各入口由 `UINavigationController` 管理工具栏。菜单和页面动作声明 `axisBehavior = .verticalPreferred`，自定义根容器通过 `childForPreferredVerticalBarBehavior` 将配置传给活动系统容器。

不另建应用侧边竖栏、不固定右侧宽度、不额外增加底部或侧边安全区。系统将工具栏、Tab bar 和搜索整合到其侧边控制区；折叠外屏及展开分屏时的位置随窗口环境改变。左侧分屏 App 的控件可以位于左外缘，右侧 App 位于右外缘，位置由 UIKit 决定。

选择主入口仍先发送路由意图，等待前端权限守卫确认快照后才更新选中项。搜索继续使用原前端动作。折叠、旋转、分屏只改变同一系统容器的布局，不创建新网页或重登。布局通信读取实际宿主的安全区，不重复扣除系统控制区。

## 官方接口

- [UITabBarController](https://developer.apple.com/documentation/uikit/uitabbarcontroller)
- [UISearchTab](https://developer.apple.com/documentation/uikit/uisearchtab)
- [UIVerticalBarEdge](https://developer.apple.com/documentation/uikit/uiverticalbaredge)
- [preferredVerticalBarBehavior](https://developer.apple.com/documentation/uikit/uiviewcontroller/preferredverticalbarbehavior)
- [Apple HIG — Layout](https://developer.apple.com/design/human-interface-guidelines/layout)

`verticalBarEdge` 表示系统当前偏好的边缘；无需手工重排侧边控件。此方案保留默认 automatic 行为，不按每个页面反复启停系统竖栏。

## 验证

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer zsh scripts/test-core.sh
python3 -m unittest discover -s scripts/tests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project ios/MoviePilot.xcodeproj -scheme MoviePilot \
  -destination 'platform=iOS Simulator,id=你的模拟器UUID' \
  -only-testing:MoviePilotLayoutTests CODE_SIGNING_ALLOWED=NO
```

合成测试验证系统控制器层级、入口与搜索、单一网页与输入状态保留、路由确认、全屏／浮层禁用，以及非 Duo 仍运行原版。模拟器尺寸测试不能证明 iOS 27.1+ 的真机侧边控制区摆放，折叠和左右分屏必须另行真机验收。

个人签名只用于本机构建，不提交 Team ID、账号、证书或描述文件。
