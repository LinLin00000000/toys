# 检查是否以管理员权限运行
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "当前脚本未以管理员权限运行，将尝试提权..."
    Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
    exit
}

# 获取当前用户的主目录路径
$userHome = [environment]::GetFolderPath("UserProfile")
$customProgramDir = "$userHome\Program"

# 注册表路径和默认值
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion"
$defaultProgramFilesDir = "C:\Program Files"
$defaultProgramFilesDirX86 = "C:\Program Files (x86)"

# 检查是否有额外参数
param (
    [switch]$Restore
)

# 如果带有 -Restore 参数，执行复原逻辑
if ($Restore) {
    try {
        # 将注册表值复原为默认值
        Set-ItemProperty -Path $regPath -Name "ProgramFilesDir" -Value $defaultProgramFilesDir
        Write-Host "ProgramFilesDir 已复原为默认值：$defaultProgramFilesDir"

        Set-ItemProperty -Path $regPath -Name "ProgramFilesDir (x86)" -Value $defaultProgramFilesDirX86
        Write-Host "ProgramFilesDir (x86) 已复原为默认值：$defaultProgramFilesDirX86"
    }
    catch {
        Write-Error "复原注册表时出错：$($_.Exception.Message)"
    }
    Write-Host "操作完成！请重启电脑/重启explorer.exe/注销用户以确保更改生效。"
    exit
}

# 检查目标文件夹是否存在，如果不存在则创建
if (-Not (Test-Path -Path $customProgramDir)) {
    Write-Host "目标文件夹不存在，正在创建：$customProgramDir"
    try {
        New-Item -ItemType Directory -Path $customProgramDir | Out-Null
    }
    catch {
        Write-Error "创建目标文件夹失败：$($_.Exception.Message)"
        exit
    }
}
else {
    Write-Host "目标文件夹已存在：$customProgramDir"
}

# 修改注册表键值
try {
    # 设置 ProgramFilesDir
    Set-ItemProperty -Path $regPath -Name "ProgramFilesDir" -Value $customProgramDir
    Write-Host "ProgramFilesDir 修改为：$customProgramDir"

    # 设置 ProgramFilesDir (x86)
    Set-ItemProperty -Path $regPath -Name "ProgramFilesDir (x86)" -Value $customProgramDir
    Write-Host "ProgramFilesDir (x86) 修改为：$customProgramDir"
}
catch {
    Write-Error "修改注册表时出错：$($_.Exception.Message)"
}

# 提示用户操作完成
Write-Warning "注意：修改 ProgramFilesDir 可能导致某些软件无法正常运行！"
Write-Warning "建议在更改之前备份注册表：导出注册表项 HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion"
Write-Warning "如需恢复，请使用脚本参数 -Restore，将值改回默认路径（C:\Program Files 和 C:\Program Files (x86)）。"

Write-Host "操作完成！请执行以下操作以确保更改生效："
Write-Host "1. 重启电脑"
Write-Host "2. 或运行以下命令重启资源管理器："
Write-Host "   Stop-Process -Name explorer -Force; Start-Process explorer"
Write-Host "3. 或注销用户并重新登录"
