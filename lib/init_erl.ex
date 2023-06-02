defmodule Firefly.InitErl do
  def add(erls, path) do
    if boot = Mix.Project.config()[:boot] do
      path = Path.join(path, "init.erl")
      File.write!(path, source(boot), [:utf8])
      [path | erls]
    else
      erls
    end
  end

  defp source({module, fun}) do
    ~s"""
    -module(init).
    -exports([boot/1]).

    boot(Args) ->
    '#{to_string(module)}':#{Atom.to_string(fun)}(Args).
    """
  end
end
