#!/usr/bin/env bash
# 통합 백업 스크립트 (Linux bash)
# 목적: tenant_a, tenant_b를 순서대로 덤프하여 /opt/mes/backup에 저장하고
#       로그를 남긴다. 실패하면 exit 1로 종료한다.
#
# 사용 예시:
#   bash ./scripts/backup-all-tenants.sh
#
# 환경변수(선택):
#   MES_DB_CONTAINER        : Docker 컨테이너명 (기본 mes-mariadb)
#   MES_DB_USER             : 덤프 실행 계정 (기본 mes)
#   MES_DB_USER_PASSWORD    : 덤프 실행 비밀번호 (기본 mes1234!)
#
# 주의:
# - 비밀번호는 화면/로그에 출력하지 않는다.
# - 덤프 파일이 비어 있으면 실패로 처리한다.

set -euo pipefail

CONTAINER="${MES_DB_CONTAINER:-mes-mariadb}"
DB_USER="${MES_DB_USER:-mes}"
DB_PASS="${MES_DB_USER_PASSWORD:-mes1234!}"
TENANTS=("tenant_a" "tenant_b")
declare -A DB_NAME_MAP=(
  ["tenant_a"]="mes_tenant_a"
  ["tenant_b"]="mes_tenant_b"
)

BACKUP_ROOT="/opt/mes/backup"
mkdir -p "$BACKUP_ROOT"
LOG_DATE="$(date +%Y%m%d)"
LOG_PATH="$BACKUP_ROOT/backup_run_${LOG_DATE}.log"

log() {
  local level="$1"; shift
  local msg="$*"
  local line
  line="$(date '+%Y-%m-%d %H:%M:%S') [$level] $msg"
  echo "$line" | tee -a "$LOG_PATH"
}

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}\$"; then
  log "ERROR" "Docker 컨테이너가 없습니다: ${CONTAINER}"
  exit 1
fi

for t in "${TENANTS[@]}"; do
  ts="$(date +%Y%m%d_%H%M%S)"
  tenant_dir="${BACKUP_ROOT}/${t}"
  mkdir -p "$tenant_dir"
  dump_path="${tenant_dir}/mes_${t}_${ts}.sql"
  db_name="${DB_NAME_MAP[$t]}"
  if [ -z "$db_name" ]; then
    log "ERROR" "DB 매핑을 찾을 수 없습니다: ${t}"
    exit 1
  fi

  log "INFO" "백업 시작: ${t} -> ${dump_path}"
  if docker exec -i \
      -e "MARIADB_PWD=${DB_PASS}" \
      -e "MYSQL_PWD=${DB_PASS}" \
      "$CONTAINER" \
      mariadb-dump -u "$DB_USER" "$db_name" > "$dump_path"; then
    if [ ! -s "$dump_path" ]; then
      log "ERROR" "덤프 파일이 비어 있습니다: ${dump_path}"
      exit 1
    fi
    log "INFO" "백업 완료: ${t}"
  else
    log "ERROR" "백업 실패: ${t}"
    exit 1
  fi
done

log "INFO" "모든 테넌트 백업 완료"
exit 0
