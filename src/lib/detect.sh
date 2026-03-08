json_escape() {
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    s=${s//$'\r'/\\r}
    s=${s//$'\t'/\\t}
    printf '%s' "$s"
}

list_candidate_devices() {
    printf "%-12s %-8s %-3s %-6s %s\n" "DEVICE" "SIZE" "RM" "TRAN" "MODEL"

    lsblk -d -o PATH,SIZE,RM,TRAN,MODEL | tail -n +2 | while read -r path size rm tran model; do
        [ -n "$path" ] || continue

        case "$path" in
            /dev/loop*|/dev/sr*)
                continue
                ;;
        esac

        if [ "$rm" = "1" ] || [ "${tran:-}" = "usb" ]; then
            printf "%-12s %-8s %-3s %-6s %s\n" "$path" "$size" "$rm" "${tran:--}" "${model:-"-"}"
        fi
    done
}

list_candidate_devices_json() {
    local first=1

    printf '[\n'

    lsblk -d -o PATH,SIZE,RM,TRAN,MODEL | tail -n +2 | while read -r path size rm tran model; do
        [ -n "$path" ] || continue

        case "$path" in
            /dev/loop*|/dev/sr*)
                continue
                ;;
        esac

        if [ "$rm" = "1" ] || [ "${tran:-}" = "usb" ]; then
            if [ "$first" -eq 0 ]; then
                printf ',\n'
            fi
            first=0

            printf '  {\n'
            printf '    "device": "%s",\n' "$(json_escape "$path")"
            printf '    "size": "%s",\n' "$(json_escape "${size:-}")"
            printf '    "rm": "%s",\n' "$(json_escape "${rm:-}")"
            printf '    "tran": "%s",\n' "$(json_escape "${tran:--}")"
            printf '    "model": "%s"\n' "$(json_escape "${model:-"-"}")"
            printf '  }'
        fi
    done

    printf '\n]\n'
}

get_device_size() {
    local dev="$1"
    lsblk -dn -o SIZE "$dev"
}

get_device_model() {
    local dev="$1"
    lsblk -dn -o MODEL "$dev" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

get_device_rm() {
    local dev="$1"
    lsblk -dn -o RM "$dev"
}

get_device_tran() {
    local dev="$1"
    lsblk -dn -o TRAN "$dev" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

detect_auto_device() {
    local candidates
    local count

    candidates=$(lsblk -dn -o NAME,TRAN,RM | awk '
        ($2=="usb" || $3=="1") { print "/dev/" $1 }
    ')

    count=$(echo "$candidates" | sed '/^$/d' | wc -l)

    if [ "$count" -eq 0 ]; then
        fail "auto: USBデバイスが見つかりません"
    fi

    if [ "$count" -gt 1 ]; then
        echo "auto: 複数のUSBデバイスがあります:" >&2
        echo "$candidates" >&2
        fail "auto: --device を明示してください"
    fi

    echo "$candidates"
}
