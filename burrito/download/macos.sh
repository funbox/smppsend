#!/bin/sh

set -ex

name="otp_${OTP_VERSION}_darwin_${ARCH}_ssl_${OPENSSL_VERSION}"
targz_name="${name}.tar.gz"
otp_dir="./burrito/otp/versions"

url="https://burrito-otp.b-cdn.net/OTP-${OTP_VERSION}/darwin/${ARCH}/${targz_name}?please-respect-my-bandwidth-costs=thank-you"

dst_name="otp-${OTP_VERSION}-darwin-${ARCH}"
dst_targz_name="${dst_name}.tar.gz"

mkdir -p "$otp_dir"

wget --no-verbose "$url" -O "$otp_dir/${targz_name}"

tar xf "$otp_dir/${targz_name}" -C "$otp_dir/"
rm -rf "$otp_dir/${targz_name}"

mv "$otp_dir/${name}" "$otp_dir/${dst_name}"
tar czf "$otp_dir/${dst_targz_name}" -C "$otp_dir/" "$dst_name"

rm -rf "$otp_dir/${dst_name}"


