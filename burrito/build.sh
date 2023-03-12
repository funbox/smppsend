#!/bin/sh

set -xe

mix deps.get
mix compile

otp_version=$(mix burrito.otp.version)
ssl_version=$(mix burrito.ssl.version)

OTP_VERSION="${otp_version}" ARCH=x86_64  OPENSSL_VERSION="${ssl_version}" ./burrito/download/macos.sh
OTP_VERSION="${otp_version}" ARCH=aarch64 OPENSSL_VERSION="${ssl_version}" ./burrito/download/macos.sh

OTP_VERSION="${otp_version}" ARCH=x86_64  LIBC=gnu OPENSSL_VERSION="${ssl_version}" ./burrito/download/linux.sh
OTP_VERSION="${otp_version}" ARCH=aarch64 LIBC=gnu OPENSSL_VERSION="${ssl_version}" ./burrito/download/linux.sh

MIX_ENV=prod mix release smppsend --overwrite
