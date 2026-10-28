#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 IMAGE before|after" >&2
    exit 2
fi

image=$1
stage=$2
case "$stage" in
    before|after) ;;
    *) echo "Stage must be 'before' or 'after'" >&2; exit 2 ;;
esac

version=$(trivy --version | awk '$1 == "Version:" { print $2; exit }')
case "$version" in
    0.69.4|0.69.5|0.69.6)
        echo "Refusing compromised Trivy version $version" >&2
        exit 2
        ;;
esac

mkdir -p reports
trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
    --format table --output "reports/trivy-$stage.txt" "$image"
echo "Wrote reports/trivy-$stage.txt"