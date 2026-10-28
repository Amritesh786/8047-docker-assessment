#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 IMAGE" >&2
    exit 2
fi

version=$(trivy --version | awk '$1 == "Version:" { print $2; exit }')
case "$version" in
    0.69.4|0.69.5|0.69.6)
        echo "Refusing compromised Trivy version $version" >&2
        exit 2
        ;;
esac

mkdir -p reports
trivy image --severity CRITICAL --ignore-unfixed --exit-code 1 \
    --format table --output reports/trivy-critical.txt "$1"
echo "No fixable CRITICAL vulnerabilities found in $1"