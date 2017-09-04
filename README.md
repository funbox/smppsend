[![Build Status](https://travis-ci.org/savonarola/smppsend.svg?branch=master)](https://travis-ci.org/savonarola/smppsend)

<a href="https://funbox.ru">
  <img src="http://funbox.ru/badges/sponsored_by_funbox.svg" alt="Sponsored by FunBox" width=250 />
</a>

# SMPPSend

Simple utility for testing SMSC connections. It allows to bind to SMSCs, send submit_sm PDUs and wait for delivery reports.

## Build

If you want just to build `smppsend` executable for you current platform, just run

    $ mix do deps.get,escript.build

If you want to make a Linux-compatible binary for specific versions of OTP platform
(for example, OTP 19), run

    $ make VERSIONS=19

You need [Docker](https://www.docker.com/) installed to build.

You can also download precompiled Linux-compatible binaries from [Releases](https://github.com/savonarola/smppsend/releases) page.

## Usage

See

    $ smppsend --help
