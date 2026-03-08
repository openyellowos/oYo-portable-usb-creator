setup_persistence() {
    local persist_mount="$1"
    local template="$2"

    cp "$template" "$persist_mount/persistence.conf"
    sync
}
