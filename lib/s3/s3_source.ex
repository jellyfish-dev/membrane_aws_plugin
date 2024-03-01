defmodule Membrane.AWS.S3.Source do
  @moduledoc """
  Element that reads file from a S3 bucket and sends it through the output pad.
  """
  use Membrane.Source

  alias Membrane.{Buffer, RemoteStream}

  def_options aws_config: [
                spec: Keyword.t(),
                description: """
                Config to ExAWS. For more information refer to [`ExAws.Config`](https://github.com/ex-aws/ex_aws/blob/main/lib/ex_aws/config.ex).
                """,
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
              ],
              cached_chunks_number: [
                spec: non_neg_integer(),
                description: "Number of chunks cached before demand",
                default: 10
              ]

  def_output_pad :output, accepted_format: %RemoteStream{type: :bytestream}, flow_control: :manual

  @impl true
  def handle_init(_context, opts) do
    state = %{
      aws_config: ExAws.Config.new(:s3, opts.aws_config),
      bucket: opts.bucket,
      path: opts.path,
      opts: opts.opts,
      chunks_stream: nil,
      cached_chunks_number: opts.cached_chunks_number,
      chunks: :queue.new()
    }

    chunks_stream = ExAws.S3.Download.build_chunk_stream(state, state.aws_config)

    {[], %{state | chunks_stream: chunks_stream}}
  end

  @impl true
  def handle_playing(_ctx, state) do
    {take_chunks, chunks_stream} = state.chunks_stream |> Enum.split(state.cached_chunks_number)

    downloaded_chunks =
      take_chunks
      |> Task.async_stream(
        &download_chunk(state, &1),
        max_concurrency: Keyword.get(state.opts, :max_concurrency, 8),
        timeout: Keyword.get(state.opts, :timeout, 60_000)
      )
      |> Enum.map(fn {:ok, chunk} -> chunk end)
      |> Enum.reduce(state.chunks, fn chunk, acc -> :queue.in(chunk, acc) end)

    {[stream_format: {:output, %RemoteStream{type: :bytestream}}],
     %{state | chunks_stream: chunks_stream, chunks: downloaded_chunks}}
  end

  @impl true
  def handle_demand(_pad, _size, _unit, _ctx, state) do
    {chunks, chunks_stream} = update_chunks(state)

    case :queue.out(chunks) do
      {:empty, _chunks} ->
        {[end_of_stream: :output], state}

      {{:value, payload}, chunks} ->
        {[buffer: {:output, %Buffer{payload: payload}}] ++ [redemand: :output],
         %{state | chunks_stream: chunks_stream, chunks: chunks}}
    end
  end

  defp update_chunks(state) do
    {boundaries, chunks_stream} = Enum.split(state.chunks_stream, 1)

    chunks =
      if boundaries != [] do
        [boundaries] = boundaries
        chunk = download_chunk(state, boundaries)
        :queue.in(chunk, state.chunks)
      else
        state.chunks
      end

    {chunks, chunks_stream}
  end

  defp download_chunk(state, boundaries) do
    {_start_byte, chunk} = ExAws.S3.Download.get_chunk(state, boundaries, state.aws_config)
    chunk
  end
end
