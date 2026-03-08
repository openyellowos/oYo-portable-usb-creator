# shellcheck disable=SC2034

iso_path=""
target_device=""
assume_yes="0"
force_mode="0"
dry_run="0"

parse_create_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --iso)
                iso_path="$2"
                shift 2
                ;;
            --device)
                target_device="$2"
                shift 2
                ;;
            --yes)
                assume_yes="1"
                shift
                ;;
            --force)
                force_mode="1"
                shift
                ;;
            --dry-run)
                dry_run="1"
                shift
                ;;
            *)
                fail "不明なオプション: $1"
                ;;
        esac
    done

    [ -n "${iso_path:-}" ] || fail "--iso は必須です"
    [ -n "${target_device:-}" ] || fail "--device は必須です"
}

parse_doctor_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --iso)
                iso_path="$2"
                shift 2
                ;;
            --device)
                target_device="$2"
                shift 2
                ;;
            --force)
                force_mode="1"
                shift
                ;;
            *)
                fail "不明なオプション: $1"
                ;;
        esac
    done

    [ -n "${iso_path:-}" ] || fail "--iso は必須です"
    [ -n "${target_device:-}" ] || fail "--device は必須です"
}

validate_iso_file() {
    local iso="$1"
    [ -f "$iso" ] || fail "ISOファイルが見つかりません: $iso"
}

validate_block_device() {
    local dev="$1"
    [ -b "$dev" ] || fail "ブロックデバイスではありません: $dev"
}

ensure_not_system_disk() {
    local dev="$1"
    local root_src
    root_src="$(findmnt -n -o SOURCE / | sed 's/p\?[0-9]\+$//')"

    [ "$dev" != "$root_src" ] || fail "システムディスクは指定できません: $dev"
}

ensure_device_not_in_use() {
    local dev="$1"

    if lsblk -ln -o PATH,MOUNTPOINT "$dev" | tail -n +2 | awk 'NF >= 2 && $2 != "" { found=1 } END { exit(found ? 0 : 1) }'
    then
        fail "マウント中のパーティションを含むデバイスは指定できません: $dev"
    fi
}

ensure_device_looks_removable_or_usb() {
    local dev="$1"

    local rm
    local tran

    rm="$(get_device_rm "$dev")"
    tran="$(get_device_tran "$dev")"

    if [ "$rm" = "1" ] || [ "$tran" = "usb" ]; then
        return 0
    fi

    if [ "${force_mode:-0}" = "1" ]; then
        log_warn "USB/removable と判定できないデバイスですが --force により続行します: $dev"
        return 0
    fi

    fail "USB/removable と判定できないデバイスです: $dev （必要なら --force を指定）"
}

validate_device_capacity_for_portable() {
    local dev="$1"
    local iso="$2"

    local dev_size_bytes
    local iso_size_mib
    local required_mib
    local required_bytes

    dev_size_bytes="$(blockdev --getsize64 "$dev")"
    iso_size_mib="$(du -m "$iso" | cut -f1)"

    required_mib=$((2 + 512 + iso_size_mib + 1024 + 512))
    required_bytes=$((required_mib * 1024 * 1024))

    [ "$dev_size_bytes" -ge "$required_bytes" ] || \
        fail "USB容量が不足しています。必要容量の目安: ${required_mib}MiB"
}

confirm_erase_device() {
    local dev="$1"

    local model
    local size
    local rm
    local tran
    local expected
    local answer

    model="$(get_device_model "$dev")"
    size="$(get_device_size "$dev")"
    rm="$(get_device_rm "$dev")"
    tran="$(get_device_tran "$dev")"

    if [ "${dry_run:-0}" = "1" ]; then
        log_info "dry-run のため確認入力を省略します"
        return 0
    fi

    if [ "${assume_yes:-0}" = "1" ] && [ "${force_mode:-0}" = "1" ]; then
        log_warn "--yes --force が指定されているため確認を省略します"
        return 0
    fi

    cat >&2 <<EOF
WARNING: 指定したデバイスの内容はすべて消去されます

DEVICE: $dev
MODEL : ${model:-"-"}
SIZE  : ${size:-"-"}
RM    : ${rm:-"-"}
TRAN  : ${tran:-"-"}

続行するには以下を正確に入力してください:
EOF

    expected="ERASE $dev"
    printf "%s\n> " "$expected" >&2
    read -r answer

    [ "$answer" = "$expected" ] || fail "確認文字列が一致しなかったため中止しました"
}
