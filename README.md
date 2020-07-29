# SMPPSend

[![Build Status](https://travis-ci.org/funbox/smppsend.svg?branch=master)](https://travis-ci.org/funbox/smppsend)

Simple utility for testing SMSC connections. It allows to bind to SMSCs, send `submit_sm` PDUs and wait for delivery reports.

## Build

If you want just to build `smppsend` executable for you current platform, just run:

```bash
mix do deps.get, escript.build
```

If you want to make a Linux-compatible binary for specific versions of OTP platform
(for example, OTP 19), run

```bash
make VERSIONS=19
```

You need [Docker](https://www.docker.com/) installed to build.

You can also download precompiled Linux-compatible binaries from “[Releases](https://github.com/funbox/smppsend/releases)” page.

## Usage

See:

```bash
smppsend --help
```

Sample usage:

```bash
smppsend --submit-sm --source-addr test --destination-addr 71234567890 --source-addr-ton 5 --source-addr-npi 0 --dest-addr-ton 1 --dest-addr-npi 1 --data-coding 0 --host smppex.rubybox.ru --port 2775 --system-id testsid --password password --bind-mode trx --short-message "test" --wait
```

[![Sponsored by FunBox](https://funbox.ru/badges/sponsored_by_funbox_centered.svg)](https://funbox.ru)
