# ISO内のEFI起動ファイルをUSBへコピーする
# UEFI成功版を維持するため、ここは従来通りコピー方式
install_efi_boot_files() {
    local iso_mount="$1"
    local efi_mount="$2"

    mkdir -p "$efi_mount/EFI/BOOT"
    mkdir -p "$efi_mount/boot/grub"

    if [ -d "$iso_mount/EFI" ]; then
        rsync -a "$iso_mount/EFI/" "$efi_mount/EFI/" || fail "ISO内EFIディレクトリのコピーに失敗しました"
    else
        fail "ISO内に EFI ディレクトリが見つかりません: $iso_mount/EFI"
    fi

    if [ ! -f "$efi_mount/EFI/BOOT/BOOTX64.EFI" ] && [ ! -f "$efi_mount/EFI/BOOT/bootx64.efi" ]; then
        fail "UEFI起動用の BOOTX64.EFI が見つかりません"
    fi
}

build_portable_kernel_args() {
    local encryption_mode="${1:-none}"
    local args="boot=live persistence persistence-storage=file persistence-label=persistence.img oyo.mode=portable quiet splash"

    case "$encryption_mode" in
        none)
            ;;
        luks)
            args+=" persistence-encryption=luks"
            ;;
        *)
            fail "未対応の persistence 暗号化モードです: $encryption_mode"
            ;;
    esac

    printf '%s' "$args"
}

# Portable専用の grub.cfg をテンプレートから生成する
write_portable_grub_cfg() {
    local template="$1"
    local output="$2"
    local grub_timeout="${3:-0}"
    local kernel_path="${4:-/live/vmlinuz}"
    local initrd_path="${5:-/live/initrd.img}"
    local kernel_args="${6:-boot=live persistence persistence-storage=file persistence-label=persistence.img oyo.mode=portable quiet splash}"

    [ -f "$template" ] || fail "GRUBテンプレートが見つかりません: $template"

    sed \
        -e "s|{{GRUB_TIMEOUT}}|$grub_timeout|g" \
        -e "s|{{KERNEL_PATH}}|$kernel_path|g" \
        -e "s|{{INITRD_PATH}}|$initrd_path|g" \
        -e "s|{{KERNEL_ARGS}}|$kernel_args|g" \
        "$template" > "$output" || fail "grub.cfg の生成に失敗しました: $output"
}

# EFI/BOOT/grub.cfg を boot/grub/grub.cfg へ誘導する形で上書きする
write_efi_chain_grub_cfg() {
    local template="$1"
    local output="$2"

    [ -f "$template" ] || fail "EFI用GRUBテンプレートが見つかりません: $template"

    cp "$template" "$output" || fail "EFI/BOOT/grub.cfg の生成に失敗しました: $output"
}

# BIOS用GRUBをUSBディスク本体へインストールする
# boot/grub は EFIパーティション上を利用
install_bios_grub() {
    local target_device="$1"
    local boot_dir="$2"

    [ -d "$boot_dir" ] || fail "BIOS用GRUBの boot ディレクトリが見つかりません: $boot_dir"

    grub-install \
        --target=i386-pc \
        --boot-directory="$boot_dir" \
        --modules="part_gpt fat ext2" \
        --recheck \
        "$target_device" || fail "BIOS用GRUBのインストールに失敗しました: $target_device"
}

# LIVEパーティションに起動に必要なファイルがあるか確認
validate_live_boot_files() {
    local live_mount="$1"

    [ -f "$live_mount/live/vmlinuz" ] || fail "LIVEパーティションに /live/vmlinuz が見つかりません"
    [ -f "$live_mount/live/initrd.img" ] || fail "LIVEパーティションに /live/initrd.img が見つかりません"
    [ -f "$live_mount/live/filesystem.squashfs" ] || fail "LIVEパーティションに /live/filesystem.squashfs が見つかりません"
}

# 配置されたEFI/GRUBの最低限チェック
validate_grub_layout() {
    local efi_mount="$1"

    if [ -f "$efi_mount/EFI/BOOT/BOOTX64.EFI" ]; then
        :
    elif [ -f "$efi_mount/EFI/BOOT/bootx64.efi" ]; then
        :
    else
        fail "EFI/BOOT/BOOTX64.EFI が見つかりません"
    fi

    [ -f "$efi_mount/boot/grub/grub.cfg" ] || fail "boot/grub/grub.cfg が見つかりません"
    [ -f "$efi_mount/EFI/BOOT/grub.cfg" ] || fail "EFI/BOOT/grub.cfg が見つかりません"
}

# BIOS用GRUBの最低限チェック
validate_bios_grub_layout() {
    local boot_dir="$1"

    [ -d "$boot_dir/grub/i386-pc" ] || fail "BIOS用GRUBモジュールが見つかりません: $boot_dir/grub/i386-pc"
}
