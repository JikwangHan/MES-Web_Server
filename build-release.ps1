# 운영 패키지 빌드 (Windows PowerShell)
# 주요 단계:
#   1) mvnw로 jar 빌드(-DskipTests)
#   2) release-template 폴더 복사
#   3) jar를 bin/mes-web.jar로 복사
#   4) dist/mes-web_release_YYYYMMDD_HHMM.zip 생성

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

# 1) 빌드
Write-Host "[1/4] mvnw -DskipTests clean package"
./mvnw.cmd -DskipTests clean package

# 2) 릴리스 폴더 준비
$dist = "C:\MES\dist"
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$ts = Get-Date -Format "yyyyMMdd_HHmm"
$releaseName = "mes-web_release_$ts"
$workDir = Join-Path $dist $releaseName

if (Test-Path $workDir) { Remove-Item -Recurse -Force $workDir }
Copy-Item -Recurse -Force "$root\release-template" $workDir

# perf/DR/운영 점검 스크립트 동기화
Copy-Item "$root\scripts\perf-baseline.ps1" "$workDir\scripts\perf-baseline.ps1" -Force
Copy-Item "$root\scripts\perf-gate.ps1" "$workDir\scripts\perf-gate.ps1" -Force
Copy-Item "$root\scripts\ops-daily-check.ps1" "$workDir\scripts\ops-daily-check.ps1" -Force
Copy-Item "$root\scripts\diagnose-boot.ps1" "$workDir\scripts\diagnose-boot.ps1" -Force
Copy-Item "$root\scripts\collect-evidence.ps1" "$workDir\scripts\collect-evidence.ps1" -Force
Copy-Item "$root\scripts\reboot-finalize.ps1" "$workDir\scripts\reboot-finalize.ps1" -Force
Copy-Item "$root\scripts\post-reboot-verify.ps1" "$workDir\scripts\post-reboot-verify.ps1" -Force
Copy-Item "$root\scripts\register-daily-ops-task.ps1" "$workDir\scripts\register-daily-ops-task.ps1" -Force
Copy-Item "$root\scripts\check-backup-health.ps1" "$workDir\scripts\check-backup-health.ps1" -Force
Copy-Item "$root\scripts\ops-weekly-report.ps1" "$workDir\scripts\ops-weekly-report.ps1" -Force
Copy-Item "$root\scripts\check-disk-log-health.ps1" "$workDir\scripts\check-disk-log-health.ps1" -Force
Copy-Item "$root\scripts\ops-dashboard-summary.ps1" "$workDir\scripts\ops-dashboard-summary.ps1" -Force

# Windows 서비스 스크립트 동기화
Copy-Item "$root\release-template\scripts\windows-service-install.ps1" "$workDir\scripts\windows-service-install.ps1" -Force
Copy-Item "$root\release-template\scripts\windows-service-uninstall.ps1" "$workDir\scripts\windows-service-uninstall.ps1" -Force

# perf threshold 문서
New-Item -ItemType Directory -Force -Path (Join-Path $workDir "docs") | Out-Null
Copy-Item "$root\docs\perf-thresholds.v0.1.json" (Join-Path $workDir "docs\perf-thresholds.v0.1.json") -Force

# 3) jar 복사
$jar = Get-ChildItem "$root\target" -Filter "*.jar" | Where-Object { $_.Name -notmatch "original" } | Select-Object -First 1
if (-not $jar) { throw "target/*.jar 파일을 찾지 못했습니다." }
Copy-Item $jar.FullName (Join-Path $workDir "bin\mes-web.jar") -Force

# 4) ZIP 생성
$zipPath = Join-Path $dist ($releaseName + ".zip")
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
[System.IO.Compression.ZipFile]::CreateFromDirectory($workDir, $zipPath)

Write-Host "[완료] 운영 패키지 생성:" $zipPath
