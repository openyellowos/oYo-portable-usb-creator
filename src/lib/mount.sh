# ISO を read-only で loop mount する
mount_iso_readonly() {
    local iso="$1"
    local mount_point="$2"

    mkdir -p "$mount_point"

    if mountpoint -q "$mount_point"; then
        umount "$mount_point" || fail "ISOマウントポイントのアンマウントに失敗しました: $mount_point"
    fi

    mount -o loop,ro "$iso" "$mount_point" || fail "ISOのマウントに失敗しました: $iso -> $mount_point"
}

# Portable USB の各パーティションをマウントする
# 構成:
#   p2 = EFI
#   p3 = LIVE
#   p4 = persistence パーティション または LUKS コンテナ
mount_portable_partitions() {
    local dev="$1"
    local encryption_mode="${2:-none}"
    local passphrase_file="${3:-}"

    local p2
    local p3
    local p4
    local persist_source

    p2="$(get_partition "$dev" 2)"
    p3="$(get_partition "$dev" 3)"
    p4="$(get_partition "$dev" 4)"

    mkdir -p "$EFI_MOUNT_DIR" "$LIVE_MOUNT_DIR" "$PERSIST_MOUNT_DIR"

    mount "$p2" "$EFI_MOUNT_DIR" || fail "EFIパーティションのマウントに失敗しました: $p2"
    mount "$p3" "$LIVE_MOUNT_DIR" || fail "LIVEパーティションのマウントに失敗しました: $p3"

    case "$encryption_mode" in
        none)
            persist_source="$p4"
            ;;
        luks)
            open_luks_persistence "$p4" "$passphrase_file"
            persist_source="/dev/mapper/$(get_persist_mapper_name)"
            ;;
        *)
            fail "未対応の persistence 暗号化モードです: $encryption_mode"
            ;;
    esac

    mount "$persist_source" "$PERSIST_MOUNT_DIR" || fail "persistence パーティションのマウントに失敗しました: $persist_source"
}

# 指定マウントポイントがマウント済みならアンマウントする
unmount_if_mounted() {
    local mount_point="${1:-}"
    [ -n "$mount_point" ] || return 0

    if mountpoint -q "$mount_point"; then
        umount "$mount_point" || fail "アンマウントに失敗しました: $mount_point"
    fi
}

# create処理で使う全マウントポイントをアンマウントする
unmount_all_workdirs() {
    unmount_if_mounted "${PERSIST_MOUNT_DIR:-}"
    close_luks_persistence || true
    unmount_if_mounted "${LIVE_MOUNT_DIR:-}"
    unmount_if_mounted "${EFI_MOUNT_DIR:-}"
    unmount_if_mounted "${ISO_MOUNT_DIR:-}"
}
