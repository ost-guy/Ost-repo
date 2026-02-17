#!/usr/bin/env bash
set -euo pipefail

# Limpa snapshots antigas no Bazzite (Btrfs)
# - Suporta Snapper (preferencial)
# - Fallback para diretório /.snapshots
#
# Uso:
#   sudo ./bazzite-clean-old-snapshots.sh
#   sudo ./bazzite-clean-old-snapshots.sh --days 30 --keep 3
#   sudo ./bazzite-clean-old-snapshots.sh --dry-run

DAYS=45
KEEP=2
DRY_RUN=false
SNAPSHOT_DIR="/.snapshots"

usage() {
  cat <<USAGE
Uso: $(basename "$0") [opções]

Opções:
  -d, --days N        Remove snapshots mais antigas que N dias (padrão: ${DAYS})
  -k, --keep N        Mantém pelo menos N snapshots mais recentes (padrão: ${KEEP})
  -p, --path DIR      Diretório de snapshots (padrão: ${SNAPSHOT_DIR})
  -n, --dry-run       Apenas mostra o que seria removido
  -h, --help          Mostra esta ajuda

Exemplo:
  sudo $(basename "$0") --days 30 --keep 3
USAGE
}

log() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }

run() {
  if [[ "$DRY_RUN" == true ]]; then
    printf '[DRY-RUN] %s\n' "$*"
  else
    eval "$@"
  fi
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "Este script precisa de root. Rode com sudo." >&2
    exit 1
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--days)
        DAYS="$2"; shift 2 ;;
      -k|--keep)
        KEEP="$2"; shift 2 ;;
      -p|--path)
        SNAPSHOT_DIR="$2"; shift 2 ;;
      -n|--dry-run)
        DRY_RUN=true; shift ;;
      -h|--help)
        usage; exit 0 ;;
      *)
        echo "Opção inválida: $1" >&2
        usage
        exit 1 ;;
    esac
  done

  [[ "$DAYS" =~ ^[0-9]+$ ]] || { echo "--days deve ser inteiro >= 0" >&2; exit 1; }
  [[ "$KEEP" =~ ^[0-9]+$ ]] || { echo "--keep deve ser inteiro >= 0" >&2; exit 1; }
}

cleanup_with_snapper() {
  log "Snapper detectado. Limpando snapshots antigas (> ${DAYS} dias)..."

  mapfile -t lines < <(snapper --csvout list | tail -n +2)

  if [[ ${#lines[@]} -eq 0 ]]; then
    log "Nenhuma snapshot encontrada no Snapper."
    return 0
  fi

  local now_epoch cutoff_epoch
  now_epoch=$(date +%s)
  cutoff_epoch=$(( now_epoch - DAYS*24*60*60 ))

  declare -a candidates=()

  for line in "${lines[@]}"; do
    IFS=';' read -r id type pre num date user cleanup desc data <<< "$line"

    [[ "$id" =~ ^[0-9]+$ ]] || continue

    if [[ "$date" == "" || "$date" == "-" ]]; then
      continue
    fi

    local ts
    if ! ts=$(date -d "$date" +%s 2>/dev/null); then
      continue
    fi

    if (( ts < cutoff_epoch )); then
      candidates+=("$id")
    fi
  done

  if (( ${#candidates[@]} == 0 )); then
    log "Nenhuma snapshot do Snapper mais antiga que ${DAYS} dias."
    return 0
  fi

  local total=${#candidates[@]}
  if (( total <= KEEP )); then
    warn "Encontradas ${total} snapshots antigas, mas --keep=${KEEP}. Nada será removido."
    return 0
  fi

  local remove_count=$(( total - KEEP ))
  log "Removendo ${remove_count} snapshots antigas pelo Snapper (mantendo ${KEEP} mais recentes do grupo elegível)..."

  mapfile -t sorted < <(printf '%s\n' "${candidates[@]}" | sort -n)
  for id in "${sorted[@]:0:remove_count}"; do
    run "snapper delete '$id'"
  done
}

cleanup_with_btrfs_path() {
  if [[ ! -d "$SNAPSHOT_DIR" ]]; then
    warn "Diretório de snapshots não encontrado: $SNAPSHOT_DIR"
    return 1
  fi

  log "Snapper não encontrado. Usando fallback em $SNAPSHOT_DIR"

  mapfile -d '' -t found < <(find "$SNAPSHOT_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +"$DAYS" -print0 | sort -z)

  if (( ${#found[@]} == 0 )); then
    log "Nenhuma snapshot antiga em $SNAPSHOT_DIR"
    return 0
  fi

  if (( ${#found[@]} <= KEEP )); then
    warn "Encontradas ${#found[@]} snapshots antigas, mas --keep=${KEEP}. Nada será removido."
    return 0
  fi

  local remove_count=$(( ${#found[@]} - KEEP ))
  log "Removendo ${remove_count} snapshots antigas (fallback)"

  for dir in "${found[@]:0:remove_count}"; do
    if command -v btrfs >/dev/null 2>&1; then
      run "btrfs subvolume delete '$dir'"
    else
      warn "Comando btrfs não encontrado; removendo diretório com rm -rf: $dir"
      run "rm -rf -- '$dir'"
    fi
  done
}

main() {
  parse_args "$@"
  require_root

  echo "Bem-vindo ao limpador de snapshots do Bazzite!"
  log "Configuração: days=$DAYS keep=$KEEP dry_run=$DRY_RUN path=$SNAPSHOT_DIR"

  if command -v snapper >/dev/null 2>&1; then
    cleanup_with_snapper
  else
    cleanup_with_btrfs_path
  fi

  log "Finalizado."
}

main "$@"
