# security_check.ps1
# 用法: .\security_check.ps1
#
# 设计思路(参照官方security_guards.py的核心理念):
# 不依赖人记住"这个subagent当初为什么被授予了这些权限",
# 而是维护一份"预期权限"清单,用脚本自动比对实际文件里写的tools字段,
# 任何超出预期的权限授予,都会被明确标记出来,而不是被悄悄忽略。

# 预期权限清单:每个subagent"应该"拥有的最大权限范围
# 如果实际文件里的tools超出这个范围,判定为过度授权
$expectedPermissions = @{
    "drafter.md"        = @()                  # 纯生成任务,不应该有任何工具
    "reviewer.md"       = @()                  # 纯判断任务,不应该有任何工具(Day45/58反复强调的红线)
    "syntax-checker.md" = @("Read", "Grep")    # 允许读文件和搜索,但不允许写入
}

# 危险权限清单:无论哪个subagent,只要出现这些工具,都要重点标红
# (这些工具具备"修改/删除/执行"能力,风险等级最高)
$dangerousTools = @("Write", "Edit", "Bash", "Delete")

Write-Host "===== 安全自查:各subagent权限扫描 =====" -ForegroundColor Cyan

$agentDir = ".claude\agents"
if (-not (Test-Path $agentDir)) {
    Write-Host "❌ 找不到 $agentDir 目录" -ForegroundColor Red
    exit 1
}

$hasViolation = $false

Get-ChildItem -Path $agentDir -Filter "*.md" | ForEach-Object {
    $fileName = $_.Name
    $content = Get-Content $_.FullName -Raw

    # 从frontmatter里提取 tools: 这一行的值
    if ($content -match "tools:[ \t]*(.*)") {
        $toolsLine = $matches[1].Trim()
    } else {
        $toolsLine = ""
    }

    $toolsLine = $toolsLine -replace "`r", ""   # 防御Windows换行符残留
    $actualTools = @()
    if ($toolsLine -ne "") {
        $actualTools = $toolsLine -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    }

    Write-Host "`n--- $fileName ---"
    if ($actualTools.Count -eq 0) {
        Write-Host "  实际权限: (无)"
    } else {
        Write-Host "  实际权限: $($actualTools -join ', ')"
    }

    # 检查1:是否在预期清单里
    if ($expectedPermissions.ContainsKey($fileName)) {
        $expected = $expectedPermissions[$fileName]
        $extra = $actualTools | Where-Object { $_ -notin $expected }
        if ($extra.Count -gt 0) {
            Write-Host "  ❌ 超出预期权限: $($extra -join ', ')" -ForegroundColor Red
            $hasViolation = $true
        } else {
            Write-Host "  ✅ 权限符合预期" -ForegroundColor Green
        }
    } else {
        Write-Host "  ⚠️  这是一个未登记的subagent,不在expectedPermissions清单里,建议补充登记" -ForegroundColor Yellow
        $hasViolation = $true
    }

    # 检查2:无论是否在预期内,只要出现危险工具就额外标红提示
    $foundDangerous = $actualTools | Where-Object { $_ -in $dangerousTools }
    if ($foundDangerous.Count -gt 0) {
        Write-Host "  🔴 高危权限警告: $($foundDangerous -join ', ') —— 请确认这是必须的,不是随手加的" -ForegroundColor Red
    }
}

Write-Host "`n===== 自查结束 =====" -ForegroundColor Cyan
if ($hasViolation) {
    Write-Host "存在权限异常,请检查上方标红项" -ForegroundColor Red
    exit 1
} else {
    Write-Host "所有subagent权限均符合预期" -ForegroundColor Green
    exit 0
}
