defmodule Mix.Tasks.Elven.GenPacketDocs do
  @moduledoc """
  Generate a Markdown documentation for each PacketHandler.
  """

  use Mix.Task

  @doc """
  Run the task

  TODO: Have to work for "classic" app
  """
  @spec run(any()) :: any()
  def run(_) do
    # Get umbrella apps
    apps = for {app, _} <- Mix.Project.apps_paths(), do: app

    # Load them
    Enum.each(apps, &Application.load/1)

    # Get all modules
    modules = Enum.reduce(apps, [], fn (app, acc) ->
      {:ok, modules} = :application.get_key(app, :modules)
      acc ++ modules
    end)

    # Gen doc for modules with `elven_get_packet_documentation` function
    docs =
      Enum.reduce(modules, [], fn (module, acc) ->
        functions = module.__info__(:functions)
        if Keyword.get(functions, :elven_get_packet_documentation) do
          acc ++ [gen_doc_for_module(module)]
        else
          acc
        end
      end)

    document = "# All packets\n\n" <> Enum.join(docs, "\n")
    File.write("packet_doc.md", document)
  end

  #
  # Private functions
  #

  defp gen_doc_for_module(module) do
    title = "## #{module}\n\n"

    packet_docs =
      module.elven_get_packet_documentation()
      |> Enum.reverse()
      |> Enum.map(&gen_doc_for_packet/1)

    title <> Enum.join(packet_docs, "\n\n") <> "\n"
  end

  defp gen_doc_for_packet(packet_doc) do
    desc = normalize_description(packet_doc.description, :packet)

    "-------------\n\n"
    <> "### Packet: #{packet_doc.name}\n\n"
    <> "Tags: `#{inspect(packet_doc.tags)}`\n\n"
    <> "Description:\n\n#{desc}"
  end

  defp normalize_description(desc, type) do
    final_desc =
      (desc || "No description for this #{type}")
      |> String.replace(~r"\n", "\n    ")
      |> String.replace(~r"    \n", "\n")

    "    #{final_desc}"
  end
end
