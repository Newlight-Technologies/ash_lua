# SPDX-FileCopyrightText: 2026 ash_lua contributors <https://github.com/ash-project/ash_lua/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshLua.Test.Posts.Comment do
  @moduledoc false
  use Ash.Resource,
    domain: AshLua.Test.Posts,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshLua.Resource]

  ets do
    private? true
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id

    attribute :body, :string do
      allow_nil? false
      public? true
    end

    attribute :rating, :integer do
      public? true
    end

    attribute :tip, AshLua.Test.Posts.OpaqueAmount do
      public? true
    end

    attribute :mood, :atom do
      public? true
      constraints one_of: [:pleased, :annoyed]
    end
  end

  relationships do
    belongs_to :post, AshLua.Test.Posts.Post do
      allow_nil? false
      public? true
    end

    belongs_to :author, AshLua.Test.Posts.User do
      public? true
    end
  end
end
