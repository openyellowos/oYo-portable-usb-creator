# 対象デバイス配下のパーティションをアンマウントする
unmount_device_partitions() {
    local dev="$1"

    lsblk -ln -o PATH "$dev" | tail -n +2 | while read -r part; do
        [ -n "$part" ] || continue
        umount "$part" 2>/dev/null || true
    done
}

# Portable USB 用のパーティションを作成する
# 構成:
#   1 = bios_grub (未フォーマット)
#   2 = EFI (FAT32)
#   3 = LIVE (ext4)
#   4 = persistence (ext4)
create_portable_partitions() {
    local dev="$1"
    local iso="$2"

    local iso_size_mib
    local extra_mib=1024

    local bios_start_mib=1
    local bios_end_mib=3

    local efi_start_mib=3
    local efi_end_mib=515

    local live_start_mib=515
    local live_end_mib

    iso_size_mib="$(du -m "$iso" | cut -f1)"
    live_end_mib=$((live_start_mib + iso_size_mib + extra_mib))

    wipefs -a "$dev" || fail "既存シグネチャの消去に失敗しました: $dev"
    parted -s "$dev" mklabel gpt

    # BIOS boot partition
    parted -s "$dev" mkpart BIOSBOOT "${bios_start_mib}MiB" "${bios_end_mib}MiB"
    parted -s "$dev" set 1 bios_grub on

    # EFI System Partition
    parted -s "$dev" mkpart ESP fat32 "${efi_start_mib}MiB" "${efi_end_mib}MiB"
    parted -s "$dev" set 2 esp on

    # LIVE
    parted -s "$dev" mkpart LIVE ext4 "${live_start_mib}MiB" "${live_end_mib}MiB"

    # persistence
    parted -s "$dev" mkpart persistence ext4 "${live_end_mib}MiB" 100%

    partprobe "$dev"
    udevadm settle || true
    sleep 2
}

# Portable USB 用の各パーティションをフォーマットする
# p1 (bios_grub) はフォーマットしない
format_portable_partitions() {
    local dev="$1"

    local p2
    local p3
    local p4

    p2="$(get_partition "$dev" 2)"
    p3="$(get_partition "$dev" 3)"
    p4="$(get_partition "$dev" 4)"

    mkfs.vfat -F 32 -n OYOPORT_EFI "$p2"
    mkfs.ext4 -F -L OYOPORT_LIVE "$p3"
    mkfs.ext4 -F -L persistence "$p4"
}
