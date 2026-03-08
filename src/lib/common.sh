log_info() {
    echo "[INFO] $*" >&2
}

log_warn() {
    echo "[WARN] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

progress() {
    local pct="$1"
    shift
    echo "PROGRESS:${pct}:$*"
}

fail() {
    log_error "$*"
    exit 1
}

require_root() {
    [ "$(id -u)" -eq 0 ] || fail "root権限で実行してください"
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || fail "必要なコマンドが見つかりません: $1"
}

# デバイス名からパーティションパスを返す
# 例:
#   /dev/sdb      -> /dev/sdb1
#   /dev/nvme0n1  -> /dev/nvme0n1p1
#   /dev/mmcblk0  -> /dev/mmcblk0p1
get_partition() {
    local dev="$1"
    local num="$2"

    case "$dev" in
        *nvme*|*mmcblk*)
            echo "${dev}p${num}"
            ;;
        *)
            echo "${dev}${num}"
            ;;
    esac
}

prepare_workdirs() {
    WORK_DIR="$(mktemp -d /tmp/oyo-portable-usb.XXXXXX)"
    ISO_MOUNT_DIR="$WORK_DIR/iso"
    EFI_MOUNT_DIR="$WORK_DIR/efi"
    LIVE_MOUNT_DIR="$WORK_DIR/live"
    PERSIST_MOUNT_DIR="$WORK_DIR/persist"

    mkdir -p "$ISO_MOUNT_DIR" "$EFI_MOUNT_DIR" "$LIVE_MOUNT_DIR" "$PERSIST_MOUNT_DIR"
}
