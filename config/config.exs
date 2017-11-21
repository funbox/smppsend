use Mix.Config

import_config "#{Mix.env}.exs"

config :codepagex, :encodings, [
  :ascii,
  ~r[iso8859]i,
  "ETSI/GSM0338"
]
