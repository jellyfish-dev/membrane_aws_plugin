Mix.install([
  {:membrane_aws_plugin, path: __DIR__ |> Path.join("..") |> Path.expand()},
  :membrane_core,
  :membrane_file_plugin,
  :hackney
])

# In this example, the pipeline will download file from S3 and save it to a local file

defmodule Example do
  use Membrane.Pipeline

  @impl true
  def handle_init(_ctx, options) do
    structure = [
      child(:s3_source, %Membrane.AWS.S3.Source{
        bucket: System.fetch_env!("BUCKET"),
        path: System.fetch_env!("FILE_PATH"),
        aws_config: [
          access_key_id: System.fetch_env!("ACCESS_KEY_ID"),
          secret_access_key: System.fetch_env!("SECRET_ACCESS_KEY"),
          region: System.fetch_env!("REGION")
        ]
      })
      |> child(:file_sink, %Membrane.File.Sink{location: System.fetch_env!("OUTPUT_FILE")})
    ]

    {[spec: structure], %{}}
  end

  # Next two functions are only a logic for terminating a pipeline when it's done, you don't need to worry
  @impl true
  def handle_element_end_of_stream(:file_sink, _pad, _ctx, state) do
    {[terminate: :normal], state}
  end

  def handle_element_end_of_stream(_element, _pad, _ctx, state) do
    {[], state}
  end
end

{:ok, _supervisor, pipeline} = Membrane.Pipeline.start_link(Example)
monitor_ref = Process.monitor(pipeline)

receive do
  {:DOWN, ^monitor_ref, :process, _pid, _reason} ->
    :ok
end
