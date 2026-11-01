#!/usr/bin/env bash
set -euo pipefail

src=${1:?src}
prefix=${2%/}
cache_control=${3:?cache-control}
exclude=${SYNC_EXCLUDE:-}
base=${prefix:+$prefix/}

declare -A remote seen
while IFS=$'\t' read -r key etag; do
  [ "$key" = None ] && continue
  remote[$key]=${etag//\"/}
done < <(aws s3api list-objects-v2 --bucket "$BUCKET" --prefix "$base" --query 'Contents[].[Key,ETag]' --output text)

changed=$(mktemp -d)
trap 'rm -rf "$changed"' EXIT
uploads=0
unchanged=0
while IFS= read -r -d '' path; do
  rel=${path#"$src"/}
  if [ -n "$exclude" ] && [[ $rel == "$exclude"/* ]]; then continue; fi
  key=$base$rel
  seen[$key]=1
  if [ "${remote[$key]:-}" = "$(md5sum "$path" | cut -d' ' -f1)" ]; then
    unchanged=$((unchanged + 1))
  else
    install -D "$path" "$changed/$rel"
    uploads=$((uploads + 1))
  fi
done < <(find "$src" -type f -print0)

if [ "$uploads" -gt 0 ]; then
  aws s3 sync "$changed" "s3://$BUCKET/$base" --cache-control "$cache_control" --only-show-errors
fi

deletes=0
for key in "${!remote[@]}"; do
  if [ -n "$exclude" ] && [[ $key == "$base$exclude"/* ]]; then continue; fi
  if [ -z "${seen[$key]:-}" ]; then
    aws s3 rm "s3://$BUCKET/$key" --only-show-errors
    deletes=$((deletes + 1))
  fi
done

echo "s3://$BUCKET/$base: 更新 ${uploads} / 変更なし ${unchanged} / 削除 ${deletes}"
