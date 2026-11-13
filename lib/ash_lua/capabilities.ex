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

  # A manual read answers page counts itself, so only the data layer's own
  # reads lose them.
  @spec page_counts?(module(), atom()) :: boolean()
  def page_counts?(resource, action_name) do
    aggregate_queries?(resource) or
      match?(
        %{manual: manual} when not is_nil(manual),
        Ash.Resource.Info.action(resource, action_name)
      )
  end
end
