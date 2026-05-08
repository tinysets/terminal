# 本地构建注意事项

当前分支基于 `v1.24.10921.0`。在本机 Visual Studio 2022 环境下编译
`Terminal\CascadiaPackage` 时，需要额外注意下面两个环境变量。

## 1. 禁用 fmt 头文件里的 C4459 warning

```powershell
$env:CL = '/wd4459'
```

原因：当前 VS 编译器会在 vcpkg 里的 `fmt` 头文件上触发 `C4459` warning。
项目启用了 `/WX`，warning 会被当成 error，导致编译中断。

## 2. 显式锁定 MSVC toolset

```powershell
$env:VCToolsVersion = '14.44.35207'
```

原因：本机同时安装了多个 MSVC toolset。vcpkg 产物 `CLI11.lib` 与旧的
`14.38` toolset 链接时，会出现类似下面的 STL 符号缺失：

```text
unresolved external symbol __std_search_1
unresolved external symbol __std_remove_1
```

显式使用 `14.44.35207` 后，`TerminalApp.dll` 链接可以通过。

## 推荐构建命令

```powershell
$env:CL = '/wd4459'
$env:VCToolsVersion = '14.44.35207'

& "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" .\OpenConsole.sln /t:Terminal\CascadiaPackage /m /p:Configuration=Debug /p:Platform=x64 /p:VCToolsVersion=14.44.35207 /p:AppxSymbolPackageEnabled=false /p:RestorePackages=false
```

## 额外前提

这个 tag 需要 Windows SDK `10.0.22621.0`。不要用 `10.0.26100.0` 强行覆盖，
因为本机验证时会在 XAML 编译阶段失败。
