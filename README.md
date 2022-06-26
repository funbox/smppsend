# SMPPSend

[![Elixir CI](https://github.com/funbox/smppsend/actions/workflows/elixir.yml/badge.svg)](https://github.com/funbox/smppsend/actions/workflows/elixir.yml)

Simple utility for testing SMSC connections. It allows to bind to SMSCs, send `submit_sm` PDUs and wait for delivery reports.

## Build

```bash
mix do deps.get,escript.build
```

## Usage

See:

```bash
smppsend --help
```

Sample usage:

```bash
smppsend --submit-sm --source-addr test --destination-addr 71234567890 --source-addr-ton 5 --source-addr-npi 0 --dest-addr-ton 1 --dest-addr-npi 1 --data-coding 0 --host smppex.rubybox.ru --port 2775 --system-id testsid --password password --bind-mode trx --short-message "test" --wait
```

Sponsored by [FunBox](https://funbox.ru)
