defmodule AshLua.Capabilities do
  @moduledoc false

  # Ash runs counts, page counts and `operation` aggregates as aggregate
  # queries. Data layers without `run_aggregate_query/3` (Ash.DataLayer.Simple,
  # for records computed per request) fail them with an unknown error.
  @spec aggregate_queries?(module()) :: boolean()
  def aggregate_queries?(resource) do
    data_layer = Ash.DataLayer.data_layer(resource)

    Code.ensure_loaded?(data_layer) and function_exported?(data_layer, :run_aggregate_query, 3)
  end
end
