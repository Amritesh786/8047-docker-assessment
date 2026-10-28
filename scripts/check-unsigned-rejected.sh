#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 IMAGE_REF COSIGN_PUBLIC_KEY" >&2
    exit 2
fi

image_ref=$1
public_key=$2
docker buildx imagetools inspect "$image_ref" >/dev/null
output=$(mktemp)
trap 'rm -f "$output"' EXIT HUP INT TERM

if cosign verify --key "$public_key" "$image_ref" >"$output" 2>&1; then
    cat "$output"
    echo "Unexpectedly verified: $image_ref" >&2
    exit 1
fi

cat "$output"
if ! grep -Eiq 'no matching signatures|no signatures found' "$output"; then
    echo "Verification failed, but not with a missing-signature result." >&2
    exit 2
fi

echo "Unsigned image was rejected as expected: $image_ref"