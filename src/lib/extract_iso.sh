ensure_live_files_exist_in_iso() {
    local iso_mount="$1"

    [ -f "$iso_mount/live/vmlinuz" ] || fail "ISO内に /live/vmlinuz が見つかりません"
    [ -f "$iso_mount/live/initrd.img" ] || fail "ISO内に /live/initrd.img が見つかりません"
    [ -f "$iso_mount/live/filesystem.squashfs" ] || fail "ISO内に /live/filesystem.squashfs が見つかりません"
}

copy_live_files_to_usb() {
    local iso_mount="$1"
    local live_mount="$2"

    mkdir -p "$live_mount/live"
    rsync -a "$iso_mount/live/" "$live_mount/live/" || fail "liveファイルのコピーに失敗しました"
    sync
}
