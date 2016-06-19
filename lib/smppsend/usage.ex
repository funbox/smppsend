defmodule SMPPSend.Usage do
  use Dye

  @help "
Usage: C<smppsend> g<OPTIONS>

Available options are:

  --help                                Show this help

  --bind-mode y<mode>                      Bind mode, one of the following: y<tx>(transmitter), y<rx>(receiver), y<trx>(transceiver)

  --host y<host>                           SMSC host
  --port y<port>                           SMSC port

  --submit-sm                           Send submit_sm PDU after bind

  --split-max-bytes y<len>                 Split short_message and send resulting parts with several submit_sm PDUs, so that each submit_sm's short_message size(including UDHs) does not exceed y<len> bytes. Each short_messages is automatically prepended with UDHs with ref taken from --udh-ref option

  --udh                                 Prepend short_message with UDH. This option is incompatible with --split-max-bytes option

  --ucs2                                Convert short_message field and message_payload TLV from UTF8 to UCS2 before sending submit_sm PDUs

  --wait-dlrs y<timeout>                   Wait for for delivery reports for all sent submit_sm PDUs or exit with failure after y<timeout> ms

  --wait                                Do not exit after sending submit_sm PDUs (and waiting for delivery reports if specified), but receive and display incoming PDUs infinitely

UDH fields (3GPP TS 23.040):

  --udh-ref y<ref>
  --udh-total-parts y<parts>
  --udh-part-num y<part_num>

Bind PDU fields (SMPP 3.4):

  --system-id y<system_id>
  --password y<password>
  --system-type y<system_type>
  --interface-version y<iv>
  --addr-ton y<ton>
  --addr-npi y<npi>
  --address-range y<range>

Submit_sm PDU fields (SMPP 3.4):

  --service-type y<service_type>
  --source-addr-ton y<ton>
  --source-addr-npi y<npi>
  --source-addr y<addr>
  --dest-addr-ton y<ton>
  --dest-addr-npi y<npi>
  --destination-addr y<addr>
  --esm-class y<esm_class>
  --protocol-id y<protocol_id>
  --priority-flag y<priority_flag>
  --schedule-delivery-time y<schedule_delivery_time>
  --validity-period y<validity_period>
  --registered-delivery y<registered_delivery>
  --replace-if-present-flag y<flag>
  --data-coding y<coding>
  --sm-default-msg-id y<msg_id>
  --short-message y<short_message>

  --tlv-TLV_ID-TYPE_SPEC y<value>          Add TLV fields to submit_sm PDUs. g<TLV_ID> can be specified as a hex value(y<x0424>) or as TLV's name(y<message-payload>). g<TYPE_SPEC> specifies value format: UTF8 encoded string(y<s>), hex encoded string(y<h>) or integer(y<i1>, y<i2>, y<i4> or y<i8> for 8, 16, 32 and 64 unsigned integers). Integer values are encoded in big endian format.

TLV specification examples:

  --tlv-x0424-s y<\"Hello world!\">
  --tlv-message-payload-h y<48656C6C6F20776F726C6421>
  --tlv-x0304-i1 y<1>

Example:

  C<smppsend> --host y<localhost> --port y<15000> --system-id y<bm0> --password y<pass> --bind-mode y<trx> --submit-sm --source-addr y<from123> --source-addr-npi y<1> --source-addr-ton y<5> --destination-addr y<79265303949> --dest-addr-npi y<1> --dest-addr-ton y<1> --short-message  y<HelloHelloHelloHelloHelloHelloHelloHelloHello> --data-coding y<8> --split-max-bytes y<30> --udh-ref y<123> --ucs2 --registered-delivery y<1> --wait-dlrs y<30000> --wait
"

  def help do
    @help
      |> replace(~r/--[\w\-]+/, fn(m) -> ~s/#{m}/gd end)
      |> replace(~r/g<(.*?)>/, fn(_, m) -> ~s/#{m}/gd end)
      |> replace(~r/y<(.*?)>/, fn(_, m) -> ~s/#{m}/yd end)
      |> replace(~r/C<(.*?)>/, fn(_, m) -> ~s/#{m}/DCd end)
  end

  defp replace(string, re, replacement) do
    Regex.replace(re, string, replacement)
  end

end
