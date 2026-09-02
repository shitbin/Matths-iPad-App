#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
api="$root/Matths/StoreCatalogAPI.swift"
screen="$root/Matths/StoreCatalogScreen.swift"
app="$root/Matths/MatthsApp.swift"
root_view="$root/Matths/RootView.swift"
demo="$root/Matths/DemoMode.swift"
fixture="$root/Matths/DemoStoreCatalogFixtures.swift"

for file in "$api" "$screen" "$app" "$root_view" "$demo" "$fixture"; do
  [ -f "$file" ] || { echo "FAIL: missing $file" >&2; exit 1; }
done

for path in \
  '/api/v1/store-products"' \
  '/api/v1/store-products/\(slug)' \
  '/files/\(asset.id)' \
  '/media/\(asset.id)'; do
  grep -Fq "$path" "$api" || { echo "FAIL: missing API path $path" >&2; exit 1; }
done

for rule in \
  'value == "STORE_CATALOG_NATIVE_V1"' \
  'validateAuthorizedResponse' \
  'DataScope.slot' \
  'isExcludedFromBackup = true'; do
  grep -Fq "$rule" "$api" || { echo "FAIL: missing transport rule $rule" >&2; exit 1; }
done

for behavior in \
  'func load(' 'func open(' 'func download(' \
  'product.price == 0' 'freeDownloadFiles' 'StoreCatalogRemoteImage' \
  'viewport.size.height < 500' 'viewport.safeAreaInsets.leading' \
  'dynamicTypeSize.isAccessibilitySize' 'compactHeightSheet'; do
  grep -Fq "$behavior" "$screen" || { echo "FAIL: missing UI rule $behavior" >&2; exit 1; }
done

grep -Fq 'requestedStoreProductSlug' "$app"
grep -Fq 'route = .storeCatalog' "$app"
grep -Fq 'StoreCatalogScreen()' "$root_view"
grep -Fq 'GET /api/v1/store-products' "$demo"
grep -Fq '/api/v1/store-products/{slug}' "$demo"
grep -Fq 'DemoStoreArtwork.png' "$demo"

echo "native store catalog contract passed"
