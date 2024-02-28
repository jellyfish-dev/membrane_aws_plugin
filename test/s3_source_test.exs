defmodule Membrane.AWS.S3.SourceTest do
  use ExUnit.Case, async: true

  import Membrane.Testing.Assertions
  import Membrane.ChildrenSpec
  import Support.BypassHelpers

  alias Membrane.AWS.S3.Source
  alias Membrane.Testing.{Pipeline, Sink}

  describe "file pass through pipeline" do
    setup [:start_bypass]

    test "whole file in one chunk", %{bypass: bypass} do
      data = for i <- 0..10_000, do: <<i::8>>, into: <<>>

      setup_multipart_download_backend(
        bypass,
        "bucket",
        "test.txt",
        data
      )

      assert pipeline =
               Pipeline.start_link_supervised!(
                 spec:
                   child(:s3_source, %Source{
                     bucket: "bucket",
                     path: "test.txt",
                     aws_credentials: exaws_config_for_bypass(bypass)
                   })
                   |> child(:sink, Sink),
                 test_process: self()
               )

      assert_sink_buffer(
        pipeline,
        :sink,
        %Membrane.Buffer{
          payload: ^data
        }
      )

      assert_end_of_stream(pipeline, :sink)
    end

    test "file splitted to 16-bytes chunks", %{bypass: bypass} do
      chunk_size = 16

      data = for i <- 0..(16 ** 2), do: <<i::8>>, into: <<>>

      splitted_binary =
        for <<chunk::binary-size(chunk_size) <- data>>, do: <<chunk::binary-size(chunk_size)>>

      setup_multipart_download_backend(
        bypass,
        "bucket",
        "test2.txt",
        data
      )

      assert pipeline =
               Pipeline.start_link_supervised!(
                 spec:
                   child(:s3_source, %Source{
                     bucket: "bucket",
                     path: "test2.txt",
                     aws_credentials: exaws_config_for_bypass(bypass),
                     opts: [chunk_size: chunk_size]
                   })
                   |> child(:sink, Sink),
                 test_process: self()
               )

      Enum.each(splitted_binary, fn expected_payload ->
        assert_sink_buffer(
          pipeline,
          :sink,
          %Membrane.Buffer{
            payload: ^expected_payload
          }
        )
      end)

      assert_end_of_stream(pipeline, :sink)
    end
  end

  defp setup_multipart_download_backend(
         bypass,
         bucket_name,
         path,
         file_body
       ) do
    request_path = "/#{bucket_name}/#{path}"

    Bypass.expect(bypass, fn conn ->
      case conn do
        %{method: "HEAD", request_path: ^request_path} ->
          conn
          |> Plug.Conn.put_resp_header("Content-Length", file_body |> byte_size |> to_string)
          |> Plug.Conn.send_resp(200, "")

        %{method: "GET", request_path: ^request_path, req_headers: headers} ->
          headers = Map.new(headers)

          "bytes=" <> range = Map.fetch!(headers, "range")

          [first, second | _] = String.split(range, "-")

          first = String.to_integer(first)
          second = String.to_integer(second)

          # IO.inspect({first, second, second - first + 1}, label: :difference)

          <<_head::binary-size(first), payload::binary-size(second - first + 1), _rest::binary>> =
            file_body

          # IO.inspect(byte_size(payload), label: :WTF_PAYLOAD)

          conn
          |> Plug.Conn.send_resp(200, payload)
      end
    end)
  end
end
