# 재부팅 자동 기동 체크리스트 v0.1

이 문서는 Windows 재부팅 후 MES 웹서버가 자동으로 기동되는지 빠르게 확인하기 위한 절차입니다.
초보자도 그대로 따라 할 수 있도록 단계별로 설명합니다.

## 1) 재부팅 전 준비

1. 현재 서비스 상태를 기록합니다.

```powershell
Get-Service -Name "MES-Web" | Format-List Status,StartType,Name
```

2. 서비스 설정 정보를 확인합니다.

```powershell
sc.exe qc "MES-Web"
```

3. 헬스 체크가 정상인지 확인합니다.

```powershell
Invoke-RestMethod http://localhost:8080/actuator/health
```

## 2) Windows 재부팅

1. 시작 메뉴에서 전원 버튼을 누른 뒤 "다시 시작"을 선택합니다.
2. 재부팅 후 Windows에 로그인합니다.

## 3) 재부팅 후 확인(로그인 직후 2~5분 내)

1. 서비스가 자동으로 기동되었는지 확인합니다.

```powershell
Get-Service -Name "MES-Web" | Format-List Status,StartType,Name
```

2. 8080 포트가 열렸는지 확인합니다.

```powershell
netstat -ano | findstr ":8080"
```

3. 헬스 체크가 정상인지 확인합니다.

```powershell
Invoke-RestMethod http://localhost:8080/actuator/health
```

## 4) 실패 시 점검 순서

1. Docker Desktop이 실행 중인지 확인합니다.
2. MariaDB 컨테이너 상태를 확인합니다.

```powershell
docker ps --filter "name=mes-mariadb"
```

3. 서비스 로그를 확인합니다.

```powershell
Get-Content C:\MES\logs\mes-web-service.err.log -Tail 80
Get-Content C:\MES\logs\mes-web-service.out.log -Tail 80
```

4. 포트 충돌 여부를 확인합니다.

```powershell
netstat -ano | findstr ":8080"
```

## 5) 빠른 검증 스크립트(권장)

아래 스크립트로 재부팅 후 상태를 한 번에 확인할 수 있습니다.

```powershell
powershell -File .\scripts\post-reboot-verify.ps1
```
