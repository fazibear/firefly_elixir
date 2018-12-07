defmodule Mix.Tasks.Compile.Firefly do
  use Mix.Task.Compiler

  @recursive true
  @manifest "compile.firefly"
  @switches [force: :boolean, verbose: :boolean]

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    Mix.Task.run("compile.protocols", args)

    beams =
      Mix.Project.build_path()
      |> Path.join("lib")
      |> Path.join(Path.basename(File.cwd!))
      |> Path.join("**")
      |> Path.join("*.beam")
      |> Path.wildcard()

    with {:ok, erls} <- beam_to_erl(beams, opts),
         {:ok, _output} <- compile_with_firefly(erls, opts)
    do
      :ok
    else
      err -> err
    end
  end

  def clean() do
    Mix.Project.build_path()
    |> Path.join("firefly")
    |> File.rm_rf()
  end

  defp compile_with_firefly(erls, opts) do
    args = ["compile" | erls]
    if opts[:verbose], do: args = ["-v" | args]

    System.cmd("firefly", args)
    {:ok, "TODO"}
  end

  defp beam_to_erl(beams, opts) do
    stale = for {:stale, src, dest} <- extract_targets(beams, opts), do: {src, dest}

    timestamp = :calendar.universal_time()

    if stale == []  do
      {:noop, []}
    else
      Mix.Utils.compiling_n(length(stale), "beam")

      {status, entries, errors} =
        do_beam_to_erl(stale, timestamp, opts, {:ok, [], []})

      case status do
        :ok ->
          {:ok, entries}

        :error ->
          {:error, errors}
      end
    end
  end

  defp do_beam_to_erl([{input, output} | rest], timestamp, opts, {status, entries, errors}) do
    with {:ok, forms} <- extract_abstract_code(input)
    do
      File.write!(output, to_erlang_source(forms), [:utf8])

      opts[:verbose] && Mix.shell().info("Compile #{Path.relative_to(input, File.cwd!)}")
      opts[:verbose] && Mix.shell().info("Generated #{Path.relative_to(output, File.cwd!)}")

      do_beam_to_erl(rest, timestamp, opts, {status, [output | entries], errors})
    else
      {:error, reason} ->
        error =
          %Mix.Task.Compiler.Diagnostic{
            file: input,
            severity: :error,
            message: "#{reason}",
            position: nil,
            compiler_name: "firefly",
            details: nil,
          }
        do_beam_to_erl(rest, timestamp, opts, {:error, entries, [error | errors]})
    end
  end
  defp do_beam_to_erl([], _timestamp, _opts, result), do: result

  defp extract_abstract_code(path) do
    path
    |> String.to_charlist()
    |> :beam_lib.chunks([:abstract_code])
    |> case do
      {:ok, {_mod, [abstract_code: {:raw_abstract_v1, forms}]}} ->
        {:ok, forms}
      {:error, mod, reason} ->
        {:error, mod.format_error(reason)}
    end
  end

  defp to_erlang_source(forms) when is_list(forms) do
    :erl_prettypr.format(:erl_syntax.form_list(forms))
  end

  defp extract_targets(beams, opts) do
    for beam <- beams do
      app = app_name_from_path(beam)
      module = module_name_from_path(beam)
      dest_dir = Path.join([Mix.Project.build_path(), "firefly", app, "src"])
      target = Path.join(dest_dir, module <> ".erl")

      # Ensure target dir exists
      :ok = File.mkdir_p!(dest_dir)

      if opts[:force] || Mix.Utils.stale?([beam], [target]) do
        {:stale, beam, target}
      else
        {:ok, beam, target}
      end
    end
  end

  # expecting ../<app>/ebin/<module>.beam
  defp module_name_from_path(path) do
    path
    |> Path.basename()
    |> Path.rootname()
  end

  # expecting ../<app>/ebin/<module>.beam
  defp app_name_from_path(path) do
    path
    |> Path.dirname()
    |> Path.dirname()
    |> Path.basename()
  end

  def manifests, do: [manifest()]
  defp manifest, do: Path.join(Mix.Project.manifest_path(), @manifest)
end
