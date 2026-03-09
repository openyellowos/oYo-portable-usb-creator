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

open.Yellow.os を想定しています。

------------------------------------------------------------------------

# 特徴

## UEFI / BIOS 両対応

作成されるUSBは以下に対応します。

-   UEFI
-   Legacy BIOS
-   persistence

Partition Layout

sdb1 BIOS Boot Partition
sdb2 EFI System Partition (FAT32)
sdb3 Live System
sdb4 Persistence

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

sudo apt install \
  parted \
  dosfstools \
  e2fsprogs \
  grub-pc-bin \
  grub-efi-amd64-bin \
  rsync

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

GUIは内部で CLI を JSON モードで呼び出しています。

list-devices --json\
doctor --json

------------------------------------------------------------------------

# 実機テスト

以下の環境で確認済み

-   open.Yellow.os

BIOS / UEFI 両対応

------------------------------------------------------------------------

## CI/CD の仕組み（開発者向け）

`oyo-portable-usb-creator` の開発では GitHub Actions を利用した CI/CD を導入しています。  
修正内容を push → tag を付与 → GitHub Actions で自動ビルド → `apt-repo-infra` でリポジトリ公開、という流れです。 

```mermaid
flowchart LR
    dev["開発者 (tag vX.Y.Z)"] --> actions["GitHub Actions (oyo-portable-usb-creator)"]
    actions --> release["GitHub Release（成果物添付）"]
    release -->|Run workflow 手動| infra["apt-repo-infra（Run workflow 実行）"]
    infra --> repo["deb.openyellowos.org（APT リポジトリに公開）"]
``` 

### フロー概要

1. **ソースコード修正**
   ```bash
   git clone https://github.com/openyellowos/oYo-portable-usb-creator.git
   cd oYo-portable-usb-creator
   ```

2. **プログラム修正**
   - `src` を編集する。  
   - 必要があれば README.md も修正する。  

3. **changelog 更新**
   ```bash
   debchange -i
   ```
   - changelog に修正内容を記入する。

   例:
   ```text
   oYo-portable-usb-creator (1.1-1) kerria; urgency=medium

     * persistence パーティション作成ロジック改善
     * USBデバイス検出の安全チェック追加

    -- Developer <you@example.com>  Sat, 31 Aug 2025 20:00:00 +0900
   ```

4. **コミット & push**
   ```bash
   git add .
   git commit -m "修正内容を記述"
   git push origin main
   ```

5. **タグ付与**
   ```bash
   git tag v1.1-1
   git push origin v1.1-1
   ```

6. **GitHub Actions による自動ビルド**
   - タグ push を検知してワークフローが起動。  
   - `.deb` がビルドされ、GitHub Release に添付される。  

7. **APT リポジトリ公開**
   - `apt-repo-infra` の GitHub Actions を **手動で Run workflow** する。  
   - 実際の入力例：  
     - Target environment: `production`  

   - 実行すると apt リポジトリに反映される。  
   - 利用者は以下で最新を取得可能：  
     ```bash
     sudo apt update
     sudo apt install oyo-portable-usb-creator
     ```

---

## 開発環境に必要なパッケージ & ローカルでビルドする手順

### 必要なツールのインストール
```bash
sudo apt update
sudo apt install -y devscripts build-essential debhelper lintian
```

### deb-src を有効にする
1. `/etc/apt/sources.list` を編集します。
   ```bash
   sudo nano /etc/apt/sources.list
   ```
2. 以下のような行を探し、コメントアウトを解除してください。
   ```text
   deb http://deb.debian.org/debian trixie main contrib non-free-firmware
   # deb-src http://deb.debian.org/debian trixie main contrib non-free-firmware
   ```
   ↓ 変更後
   ```text
   deb-src http://deb.debian.org/debian trixie main contrib non-free-firmware
   ```
3. 保存して終了後、更新します。
   ```bash
   sudo apt update
   ```

### ビルド依存の導入
```bash
sudo apt-get build-dep -y ./
```

### ローカルビルド
```bash
# 署名なしでバイナリのみビルド
dpkg-buildpackage -us -uc -b
# または（同等）
debuild -us -uc -b
```
- 生成物: `../oyo-portable-usb-creator_*_amd64.deb`（親ディレクトリに出力）  

### テストインストール / アンインストール
```bash
sudo apt install ./../oyo-portable-usb-creator_*_amd64.deb
# 動作確認後に削除する場合
sudo apt remove oyo-portable-usb-creator
```

### クリーン
```bash
# パッケージの生成物を削除
fakeroot debian/rules clean
# もしくは
dpkg-buildpackage -T clean
```

---

### 注意事項

- **必ず changelog を更新すること**  
- **バージョン番号は changelog, git tag, GitHub Release を揃えること**  
- **依存関係変更時は debian/control を更新すること**  