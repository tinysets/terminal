# 左侧 tab 影子列表右键菜单问题排查记录

日期：2026-05-08

## 结论

这次问题已经确认。之前在左侧 tab 影子列表的空白处右键没有菜单，核心原因是：

1. 最初右键菜单挂在 DataTemplate 的根 `Grid.ContextFlyout` 上，而不是 `ListViewItem` 容器上。
2. 如果根 `Grid` 没有覆盖整行可点击区域，短标题后面的空白区域就不属于这个 `Grid` 的命中区域。
3. 右键落在 `Grid` 外面的 `ListViewItem` 空白区域时，不会触发模板根元素的上下文菜单入口。

最终修复分成两步：

- `Grid Width="172"`
- `Background="Transparent"`
- `ContextRequested="_OnTabShadowListItemContextRequested"`

`Background="Transparent"` 很关键。透明背景不是视觉背景，而是让 XAML 元素参与命中测试，空白处也能接收右键。

后续为了让左侧列表和顶部 tab 的菜单完全一致，左侧不再维护自己的 `MenuFlyout`。现在左侧 item 的 `ContextRequested` 会转发到对应 tab 的真实顶部菜单：

```cpp
if (const auto flyout = tab.TabViewItem().ContextFlyout())
{
    flyout.ShowAt(element);
    eventArgs.Handled(true);
}
```

这样左侧列表只是一个 tab 影子入口，菜单内容仍然由 `Tab::_CreateContextMenu()` 维护。

## 之前验证为什么被误导

前面的几次“改了仍然不行”并不能完全作为代码行为证据，因为当时运行的不是最新构建输出。

当时发现：

```text
bin\x64\Debug\TerminalApp.dll
  Length        : 20170240
  LastWriteTime : 2026/5/8 17:11:47

AppPackages\loose\TerminalApp.dll
  Length        : 20080128
  LastWriteTime : 2026/5/8 15:36:01
```

也就是说，编译输出已经更新，但 loose package 里仍然是旧的 `TerminalApp.dll`。继续用这个包验证，会把“代码没生效”误判成“方案没解决问题”。

正确部署方式不是手工复制 DLL 或资源，而是使用项目文档里的 recipe 部署方式：

```powershell
& "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\DeployAppRecipe.exe" `
  .\src\cascadia\CascadiaPackage\bin\x64\Debug\CascadiaPackage.build.appxrecipe
```

这个命令会更新 `bin\x64\Debug\AppX` 里的完整 layout，并重新部署 `WindowsTerminalDev`。

## 官方 API 依据

官方文档说明：

- 设置 `ContextFlyout` 后，系统会自动显示和隐藏上下文菜单。
- `ContextRequested` 会被标记为 handled。
- 只有在需要接收已经被控件内部处理过的路由事件时，才应该使用 `AddHandler(..., handledEventsToo: true)`。

参考：

- https://learn.microsoft.com/en-us/uwp/api/windows.ui.xaml.uielement.contextflyout
- https://learn.microsoft.com/en-us/windows/windows-app-sdk/api/winrt/microsoft.ui.xaml.uielement.addhandler

因此最终方案不需要手写 `RightTapped`。当前使用 `ContextRequested` 是因为左侧列表需要复用顶部 tab 已经创建好的 `ContextFlyout`，避免维护两套菜单。

## 日志验证方式

不用截图验证。当前验证入口是在菜单打开处打日志：

```text
C:\Users\lihang.zhao\AppData\Local\Packages\WindowsTerminalDev_8wekyb3d8bbwe\LocalState\wt-tab-shadow-debug.log
```

验证时使用 UI Automation 读取真实 `ListViewItem` 矩形，然后在标题区域、中间区域、右侧空白区域分别右键。

早期验证模板根元素命中区域时的一次通过记录：

```text
ITEM_RECT: x=37 y=88 width=214 height=40
[TabShadow] Template MenuFlyout Opening targetType=Windows.UI.Xaml.Controls.Grid targetWidth=172.000000 targetHeight=32.000000
[TabShadow] Template MenuFlyout Opening targetType=Windows.UI.Xaml.Controls.Grid targetWidth=172.000000 targetHeight=32.000000
[TabShadow] Template MenuFlyout Opening targetType=Windows.UI.Xaml.Controls.Grid targetWidth=172.000000 targetHeight=32.000000
```

这三条 `Template MenuFlyout Opening` 分别对应：

- 标题区域
- item 中间区域
- item 右侧空白区域

菜单同源改造后，在左侧 item 右侧空白区域右键，UI Automation 能读到顶部 tab 的完整菜单项：

```text
ITEM_RECT: x=197 y=248 width=215 height=40; clicked=(394,268)
Change tab color
Rename tab
Duplicate tab
Split tab
Move tab
Export text
Find
Close
Close tab
```

对应日志：

```text
[TabShadow] Item ContextRequested actualWidth=172.000000 actualHeight=32.000000 tabTitle=Windows PowerShell listX=161.614822 listY=20.012589
```

因此已经确认：现在右键点击左侧 tab 影子列表 item 的空白区域，会进入 `ContextRequested`，并打开对应顶部 tab 的同源右键菜单。

## 后续注意

如果以后再调试 packaged app 的 XAML/UI 行为，先确认三件事：

1. `MSBuild Terminal\CascadiaPackage` 是否真的成功。
2. `DeployAppRecipe.exe` 是否把最新 layout 部署到 `bin\x64\Debug\AppX`。
3. 日志是否来自 `WindowsTerminalDev_8wekyb3d8bbwe` 的 `LocalState`，而不是商店版 Terminal 或旧 loose package。

不要只看 UI 现象判断代码是否生效。
