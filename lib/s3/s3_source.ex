defmodule Membrane.AWS.S3.Source do
  @moduledoc """
  Element that reads file from a S3 bucket and sends it through the output pad.
  """
  use Membrane.Source

  alias Membrane.{Buffer, RemoteStream}

  def_options aws_config: [
                spec: Keyword.t(),
                description: "Credentials to AWS",
                default: []
              ],
              bucket: [
                spec: binary(),
                description: "Name of bucket"
              ],
              path: [
                spec: binary(),
                description: "Path to file in bucket"
              ],
              opts: [
                spec: [
                  max_concurrency: pos_integer(),
                  chunk_size: pos_integer(),
                  timeout: pos_integer()
                ],
                description: "File download opts",
                default: []
              ]

  def_output_pad :output, accepted_format: %RemoteStream{type: :bytestream}, flow_control: :manual

  @impl true
  def handle_init(_context, opts) do
    {[], Map.from_struct(opts)}
  end

  @impl true
  def handle_playing(_ctx, state) do
    file_stream =
      state.bucket
      |> ExAws.S3.download_file(state.path, :memory, state.opts)
      |> ExAws.stream!(state.aws_config)

    {[stream_format: {:output, %RemoteStream{type: :bytestream}}], file_stream}
  end

  @impl true
  def handle_demand(_pad, _size, _unit, _ctx, file_stream) do
    case Enum.take(file_stream, 1) do
      [] ->
        {[end_of_stream: :output], file_stream}

      [payload] ->
        file_stream = Stream.drop(file_stream, 1)
        {[buffer: {:output, %Buffer{payload: payload}}] ++ [redemand: :output], file_stream}
    end
  end
end
