defmodule Membrane.AWS.S3.SourceTest do
  use ExUnit.Case

  import Membrane.Testing.Assertions
  import Membrane.ChildrenSpec
  import Mox

  alias Membrane.AWS.S3.Source
  alias Membrane.Testing.{Pipeline, Sink}

  @bucket_name "bucket"

  describe "file pass through pipeline" do
    setup :verify_on_exit!
    setup :set_mox_from_context

    test "whole file in one chunk" do
      data = for i <- 0..10_000, do: <<i::8>>, into: <<>>
      file_name = "test.txt"

      setup_multipart_download_backend(2, @bucket_name, file_name, data)

      assert pipeline =
               Pipeline.start_link_supervised!(
                 spec:
                   child(:s3_source, %Source{
                     bucket: @bucket_name,
                     path: file_name,
                     aws_config: [
                       access_key_id: "dummy",
                       secret_access_key: "dummy",
                       http_client: ExAws.Request.HttpMock
                     ]
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

    test "file splitted to 16-bytes chunks" do
      chunk_size = 16
      file_name = "test2.txt"

      data = for i <- 0..(16 ** 2), do: <<i::8>>, into: <<>>

      splitted_binary =
        for <<chunk::binary-size(chunk_size) <- data>>, do: <<chunk::binary-size(chunk_size)>>

      setup_multipart_download_backend(18, @bucket_name, file_name, data)

      assert pipeline =
               Pipeline.start_link_supervised!(
                 spec:
                   child(:s3_source, %Source{
                     bucket: @bucket_name,
                     path: file_name,
                     opts: [chunk_size: chunk_size],
                     aws_config: [
                       access_key_id: "dummy",
                       secret_access_key: "dummy",
                       http_client: ExAws.Request.HttpMock
                     ]
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
         amount_of_request,
         bucket_name,
         path,
         file_body
       ) do
    request_path = "https://s3.amazonaws.com/#{bucket_name}/#{path}"

    expect(ExAws.Request.HttpMock, :request, amount_of_request, fn
      :head, ^request_path, _req_body, _headers, _http_opts ->
        content_length = file_body |> byte_size |> to_string

        {:ok, %{status_code: 200, headers: %{"Content-Length" => content_length}}}

      :get, ^request_path, _req_body, headers, _http_opts ->
        headers = Map.new(headers)
        "bytes=" <> range = Map.fetch!(headers, "range")

        [first, second | _] = String.split(range, "-")

        first = String.to_integer(first)
        second = String.to_integer(second)

        <<_head::binary-size(first), payload::binary-size(second - first + 1), _rest::binary>> =
          file_body

        {:ok, %{status_code: 200, body: payload}}
    end)
  end
end
