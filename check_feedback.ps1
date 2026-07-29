# check_feedback.ps1
# 用法: .\check_feedback.ps1 -JsonFile reviewer_output.json
#
# 设计目的:
# Day45/48/57三次验证,Reviewer在narrative_feedback里给"内容不够丰富"类建议时
# 会举出具体功能名称的例子(比如"App控制、语音交互"),这些例子容易被下游Drafter
# 误当作产品真实具备的功能而编造进文案。
# Day58两次尝试用system prompt规则约束均未生效(见笔记),
# 改用程序化校验兜底:检测到举例引导词就判定不合格,要求重新生成。

param(
    [Parameter(Mandatory=$true)][string]$JsonFile
)

# 举例引导词清单——刻意排除"如"这个单字,避免"如果""如此""如下"误报
$exampleMarkers = @("比如", "例如", "举例", "诸如")

if (-not (Test-Path $JsonFile)) {
    Write-Host "❌ 找不到文件: $JsonFile" -ForegroundColor Red
    exit 1
}

$jsonContent = Get-Content $JsonFile -Raw | ConvertFrom-Json
$feedback = $jsonContent.narrative_feedback

if ([string]::IsNullOrWhiteSpace($feedback)) {
    Write-Host "✅ narrative_feedback为空,无需检查" -ForegroundColor Green
    exit 0
}

Write-Host "===== 检查 narrative_feedback 是否包含举例引导词 =====" -ForegroundColor Cyan
Write-Host "原文: $feedback`n"

$foundMarkers = @()
foreach ($marker in $exampleMarkers) {
    if ($feedback -match [regex]::Escape($marker)) {
        $foundMarkers += $marker
    }
}

if ($foundMarkers.Count -gt 0) {
    Write-Host "❌ 检测到举例引导词: $($foundMarkers -join ', ')" -ForegroundColor Red
    Write-Host "这条反馈不合格,需要重新生成(要求Reviewer只描述问题类型,不举具体功能例子)" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "✅ 未检测到举例引导词,反馈合格" -ForegroundColor Green
    exit 0
}
