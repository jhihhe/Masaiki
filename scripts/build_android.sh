#!/usr/bin/env bash
# 构建 Android 发布版 AAB（Google Play 上架格式）。
#
# 依赖：
#   - Android Studio Hedgehog+ 或独立 Gradle 8.7+
#   - Android SDK 34、Build-Tools 34.0.0
#   - JDK 17
#
# 环境变量：
#   ANDROID_HOME               Android SDK 路径
#   KEYSTORE_PATH              上传密钥 keystore 文件绝对路径
#   KEYSTORE_PASSWORD          keystore 密码
#   KEY_ALIAS                  key alias
#   KEY_PASSWORD               key 密码
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_DIR="$ROOT/android"

: "${ANDROID_HOME:?set ANDROID_HOME}"
: "${KEYSTORE_PATH:?set KEYSTORE_PATH}"
: "${KEYSTORE_PASSWORD:?set KEYSTORE_PASSWORD}"
: "${KEY_ALIAS:?set KEY_ALIAS}"
: "${KEY_PASSWORD:?set KEY_PASSWORD}"

cd "$ANDROID_DIR"

if [ ! -f gradlew ]; then
    echo "==> 未检测到 gradlew，先用本机 gradle 生成 wrapper"
    gradle wrapper --gradle-version 8.7 --distribution-type all
fi

echo "==> 构建 Release AAB"
./gradlew :app:bundleRelease \
    -Pandroid.injected.signing.store.file="$KEYSTORE_PATH" \
    -Pandroid.injected.signing.store.password="$KEYSTORE_PASSWORD" \
    -Pandroid.injected.signing.key.alias="$KEY_ALIAS" \
    -Pandroid.injected.signing.key.password="$KEY_PASSWORD"

AAB="$ANDROID_DIR/app/build/outputs/bundle/release/app-release.aab"
echo "==> 完成：$AAB"

echo ""
echo "下一步：登录 Google Play Console → 创建应用 → 内部测试轨道 → 上传 $AAB"
