cleanup_create() {
    sync || true
    unmount_all_workdirs || true

    if [ -n "${LUKS_PASSPHRASE_TEMP_FILE:-}" ] && [ -f "${LUKS_PASSPHRASE_TEMP_FILE:-}" ]; then
        rm -f "$LUKS_PASSPHRASE_TEMP_FILE"
        unset LUKS_PASSPHRASE_TEMP_FILE
    fi

    if [ -n "${WORK_DIR:-}" ] && [ -d "${WORK_DIR:-}" ]; then
        rm -rf "$WORK_DIR"
    fi
}
