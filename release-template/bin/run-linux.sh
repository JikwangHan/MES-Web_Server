#!/usr/bin/env bash
# Linux 실행 스크립트 (systemd 없이 단독 실행용)
# 사용 방법:
#   1) export로 환경변수를 미리 설정하거나 . env.prod.sh.example를 복사한 파일을 source
#      예: source ../config/env.prod.sh
#   2) 실행: ./run-linux.sh

set -euo pipefail

echo "[INFO] profile=${SPRING_PROFILES_ACTIVE:-unset}"
echo "[INFO] activeKey=${MES_CRYPTO_ACTIVE_KEY_ID:-unset}"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
exec java -jar ./mes-web.jar
