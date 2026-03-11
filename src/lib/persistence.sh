create_persistence_image() {
    local backing_mount="$1"
    local usage_percent="${2:-95}"
    local image_path="${backing_mount}/persistence.img"
    local available_kib
    local image_kib

    [ -d "$backing_mount" ] || fail "persistence backing store が見つかりません: $backing_mount"

    available_kib="$(df -Pk "$backing_mount" | awk 'NR==2 {print $4}')"
    [ -n "$available_kib" ] || fail "backing store の空き容量取得に失敗しました: $backing_mount"

    image_kib=$(( available_kib * usage_percent / 100 ))
    [ "$image_kib" -gt 0 ] || fail "persistence.img 用の空き容量が不足しています: $backing_mount"

    truncate -s "$(( image_kib * 1024 ))" "$image_path" || fail "persistence.img の作成に失敗しました: $image_path"
    mkfs.ext4 -F -L persistence.img "$image_path" || fail "persistence.img の ext4 初期化に失敗しました: $image_path"
}

setup_persistence() {
    local persist_mount="$1"
    local template="$2"

    cp "$template" "$persist_mount/persistence.conf"
    sync
}
