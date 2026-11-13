# SPDX-FileCopyrightText: 2026 ash_lua contributors <https://github.com/ash-project/ash_lua/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshLua.Test.Posts.Reading do
  @moduledoc false
  # Records computed for each request, like a summary read from an external
  # system: the data layer can filter, sort and page them but cannot run the
  # aggregate queries behind counts and `operation`.
  use Ash.Resource,
    domain: AshLua.Test.Posts,
    data_layer: Ash.DataLayer.Simple

  actions do
    read :read do
      primary? true
    end

    read :latest do
      argument :sensor, :string, allow_nil?: false
      pagination offset?: true, required?: false, max_page_size: 100

      prepare fn query, _context ->
        sensor = query.arguments.sensor

        Ash.DataLayer.Simple.set_data(
          query,
          for {id, value} <- [{1, 3.5}, {2, 9.0}, {3, 6.25}] do
            struct!(__MODULE__, %{id: id, sensor: sensor, value: value})
          end
        )
      end
    end
  end

  attributes do
    integer_primary_key :id, public?: true
    attribute :sensor, :string, public?: true
    attribute :value, :float, public?: true
  end
end
