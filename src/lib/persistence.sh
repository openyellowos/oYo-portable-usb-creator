setup_persistence() {
    local persist_mount="$1"
    local template="$2"

    [ -d "$persist_mount" ] || fail "persistence マウントポイントが見つかりません: $persist_mount"
    cp "$template" "$persist_mount/persistence.conf" || fail "persistence.conf の配置に失敗しました"
    sync
}
