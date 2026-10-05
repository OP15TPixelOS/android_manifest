#!/usr/bin/env bash
set -euo pipefail
echo release-start
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="fairlady"; PRODUCT="custom_fairlady"
KEY_DIR="$ROOT/release-keys/fairlady"; RELEASE_ROOT="$ROOT/release-builds"
JOBS="${JOBS:-$(nproc)}"; VERSION="${1:-$(date +%Y%m%d)}"
RELEASE_DIR="$RELEASE_ROOT/$VERSION"; RELEASE_NAME="pixelos-17.0-$VERSION-fairlady"; OUT_DIR="$ROOT/out/target/product/$DEVICE"
RELEASETOOLS="$ROOT/build/make/tools/releasetools"
export ANDROID_HOST_OUT="$ROOT/out/host/linux-x86"
export PATH="$ANDROID_HOST_OUT/bin:/usr/bin:/bin:$PATH"
export PYTHONPATH="$RELEASETOOLS:$ROOT/system/apex/apexer:$ROOT/system/update_engine/scripts:$ROOT/external/avb:${PYTHONPATH:-}"
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
export CCACHE_DIR="$ROOT/.ccache"
ccache -M 50G >/dev/null 2>&1 || true
die(){ echo "ERROR: $*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "missing: $1"; }
need openssl; need zip; need unzip; need sha256sum
mkdir -p "$KEY_DIR"; rm -rf "$RELEASE_DIR"; mkdir -p "$RELEASE_DIR"; chmod 700 "$KEY_DIR" "$RELEASE_DIR"
make_key(){ local n="$1"; if [[ ! -f "$KEY_DIR/$n.pk8" || ! -f "$KEY_DIR/$n.x509.pem" ]]; then "$ROOT/development/tools/make_key" "$KEY_DIR/$n" "/C=RU/ST=Moscow/O=Fairlady PixelOS/CN=Fairlady $n" || true; fi; }
for key in releasekey platform shared media; do make_key "$key"; done
if [[ ! -f "$KEY_DIR/avb.pem" ]]; then openssl genrsa -out "$KEY_DIR/avb.pem" 4096 2>/dev/null; fi
if [[ ! -f "$KEY_DIR/avb_pkmd.bin" ]]; then python3 "$ROOT/external/avb/avbtool.py" extract_public_key --key "$KEY_DIR/avb.pem" --output "$KEY_DIR/avb_pkmd.bin"; fi
chmod 600 "$KEY_DIR"/*.pk8 "$KEY_DIR"/avb.pem; chmod 644 "$KEY_DIR"/*.x509.pem "$KEY_DIR"/avb_pkmd.bin
cd "$ROOT"; source build/envsetup.sh; lunch "$PRODUCT-cp2a-user"; m target-files-package -j"$JOBS"
TARGET_FILES="$(find "$OUT_DIR/obj/PACKAGING/target_files_intermediates" -maxdepth 1 -type f -name '*.zip' -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)"
[[ -n "$TARGET_FILES" && -f "$TARGET_FILES" ]] || die "target-files.zip not found"
SIGNED_TARGET="$RELEASE_DIR/$RELEASE_NAME-signed-target-files.zip"; OTA="$RELEASE_DIR/$RELEASE_NAME.zip"; IMAGES="$RELEASE_DIR/$RELEASE_NAME-fastboot-images.zip"; IMAGE_STAGE="$RELEASE_DIR/.images"
sign_target_files_apks --threads "$JOBS" -o -d "$KEY_DIR" --avb_boot_algorithm SHA256_RSA4096 --avb_init_boot_algorithm SHA256_RSA4096 --avb_dtbo_algorithm SHA256_RSA4096 --avb_recovery_algorithm SHA256_RSA4096 --avb_system_algorithm SHA256_RSA4096 --avb_vendor_algorithm SHA256_RSA4096 --avb_vbmeta_algorithm SHA256_RSA4096 --avb_vbmeta_system_algorithm SHA256_RSA4096 --avb_vbmeta_vendor_algorithm SHA256_RSA4096 --avb_vbmeta_key "$KEY_DIR/avb.pem" --avb_boot_key "$KEY_DIR/avb.pem" --avb_init_boot_key "$KEY_DIR/avb.pem" --avb_dtbo_key "$KEY_DIR/avb.pem" --avb_recovery_key "$KEY_DIR/avb.pem" --avb_system_key "$KEY_DIR/avb.pem" --avb_vendor_key "$KEY_DIR/avb.pem" --avb_vbmeta_system_key "$KEY_DIR/avb.pem" --avb_vbmeta_vendor_key "$KEY_DIR/avb.pem" "$TARGET_FILES" "$SIGNED_TARGET"
ota_from_target_files -t "$JOBS" --max_threads "$JOBS" -k "$KEY_DIR/releasekey" "$SIGNED_TARGET" "$OTA"
img_from_target_files "$SIGNED_TARGET" "$IMAGES"

# Публикуем отдельные образы, а промежуточный fastboot-архив и target-files
# оставляем только внутри процесса сборки.
rm -rf "$IMAGE_STAGE"
mkdir -p "$IMAGE_STAGE"
unzip -q "$IMAGES" -d "$IMAGE_STAGE"
for image in boot.img dtbo.img init_boot.img recovery.img super_empty.img vbmeta.img vendor_boot.img; do
    [[ -f "$IMAGE_STAGE/$image" ]] || die "image missing from fastboot package: $image"
    mv "$IMAGE_STAGE/$image" "$RELEASE_DIR/$image"
done
rm -rf "$IMAGE_STAGE" "$IMAGES" "$SIGNED_TARGET"

# В каталоге релиза оставляем единственную контрольную сумму — только хэш OTA.
sha256sum "$OTA" | awk '{print $1}' > "$RELEASE_DIR/$RELEASE_NAME-checksum.txt"
echo "Release ready: $RELEASE_DIR"
