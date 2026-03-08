# oYo Portable USB Creator

**oYo Portable USB Creator** は\
Linuxディストリビューションを
**USBメモリにポータブル環境としてインストール**するツールです。

以下をサポートしています。

-   UEFI / BIOS 両対応
-   persistence（データ保存）
-   USBデバイス自動検出
-   安全確認（誤爆防止）
-   dry-run（実行シミュレーション）
-   doctor（事前診断）
-   JSON出力（GUI連携）

open.Yellow.os を想定していますが、\
**Debian系 live ISO にも応用可能です。**

------------------------------------------------------------------------

# 特徴

## UEFI / BIOS 両対応

作成されるUSBは以下に対応します。

-   UEFI
-   Legacy BIOS
-   persistence

Partition Layout

sdb1 BIOS boot\
sdb2 EFI (FAT32)\
sdb3 LIVE system\
sdb4 persistence

------------------------------------------------------------------------

# 必要コマンド

以下のツールが必要です。

lsblk\
wipefs\
parted\
mkfs.fat\
mkfs.ext4\
mount\
umount\
grub-install\
rsync

Debian / Ubuntu では：

sudo apt install parted dosfstools e2fsprogs grub-pc-bin
grub-efi-amd64-bin rsync

------------------------------------------------------------------------

# 使い方

## 1. USBデバイス一覧

./bin/oyo-portable-usb-cli list-devices

例

DEVICE SIZE MODEL\
/dev/sdb 119G TS128GESD310C

JSON

./bin/oyo-portable-usb-cli list-devices --json

------------------------------------------------------------------------

# 2. doctor（事前診断）

USB作成前のチェックを行います。

sudo ./bin/oyo-portable-usb-cli doctor --iso test.iso --device /dev/sdb

結果

RESULT:DOCTOR_OK\
DEVICE:/dev/sdb\
ISO:test.iso\
MODE:UEFI_AND_BIOS

JSON

sudo ./bin/oyo-portable-usb-cli doctor --iso test.iso --device /dev/sdb
--json

------------------------------------------------------------------------

# 3. dry-run（実行シミュレーション）

USBを書き込まずに処理内容を確認します。

sudo ./bin/oyo-portable-usb-cli create --iso test.iso --device /dev/sdb
--dry-run

------------------------------------------------------------------------

# 4. USB作成

sudo ./bin/oyo-portable-usb-cli create --iso test.iso --device /dev/sdb

確認メッセージ

WARNING: 指定したデバイスの内容はすべて消去されます

DEVICE: /dev/sdb\
MODEL : TS128GESD310C\
SIZE : 119G

続行するには以下を入力してください:

ERASE /dev/sdb

------------------------------------------------------------------------

# 5. USB自動検出

sudo ./bin/oyo-portable-usb-cli create --iso test.iso --device auto

例

\[INFO\] auto選択デバイス: /dev/sdb

------------------------------------------------------------------------

# USB構成

作成されるUSB

sdb\
├─sdb1 BIOS boot\
├─sdb2 EFI\
├─sdb3 LIVE\
└─sdb4 persistence

LIVE

/live/vmlinuz\
/live/initrd.img\
/live/filesystem.squashfs

persistence

/persistence.conf

/ union

------------------------------------------------------------------------

# 安全機能

このツールは **USB誤爆を防止する安全機能**を持っています。

チェック項目

-   システムディスク保護
-   マウント中デバイス保護
-   USB接続確認
-   容量チェック
-   ISO構造チェック

------------------------------------------------------------------------

# JSON API

GUIから利用可能です。

list-devices --json\
doctor --json

------------------------------------------------------------------------

# 実機テスト

以下の環境で確認済み

-   open.Yellow.os

BIOS / UEFI 両対応

------------------------------------------------------------------------

# License

MIT
