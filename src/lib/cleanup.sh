cleanup_create() {
    sync || true
    unmount_all_workdirs || true

    if [ -n "${WORK_DIR:-}" ] && [ -d "${WORK_DIR:-}" ]; then
        rm -rf "$WORK_DIR"
    fi
}
