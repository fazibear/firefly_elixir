defmodule Firefly.ErlangErl do
  def add(erls, path) do
    path = Path.join(path, "erlang.erl")
    File.write!(path, source(), [:utf8])
    [path | erls]
  end

  defp source() do
    ~S"""
      -module(erlang).

      -export([
               get_module_info/1,
               get_module_info/2
              ]).

      get_module_info(_) -> [].
      get_module_info(_, _) -> [].
    """
  end
end
