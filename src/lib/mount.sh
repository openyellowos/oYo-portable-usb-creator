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
#   p4 = persistence
mount_portable_partitions() {
    local dev="$1"

    local p2
    local p3
    local p4

    p2="$(get_partition "$dev" 2)"
    p3="$(get_partition "$dev" 3)"
    p4="$(get_partition "$dev" 4)"

    mkdir -p "$EFI_MOUNT_DIR" "$LIVE_MOUNT_DIR" "$PERSIST_MOUNT_DIR"

    mount "$p2" "$EFI_MOUNT_DIR" || fail "EFIパーティションのマウントに失敗しました: $p2"
    mount "$p3" "$LIVE_MOUNT_DIR" || fail "LIVEパーティションのマウントに失敗しました: $p3"
    mount "$p4" "$PERSIST_MOUNT_DIR" || fail "persistenceパーティションのマウントに失敗しました: $p4"
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
    unmount_if_mounted "${LIVE_MOUNT_DIR:-}"
    unmount_if_mounted "${EFI_MOUNT_DIR:-}"
    unmount_if_mounted "${ISO_MOUNT_DIR:-}"
}
