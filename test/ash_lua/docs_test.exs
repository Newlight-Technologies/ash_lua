# SPDX-FileCopyrightText: 2026 ash_lua contributors <https://github.com/ash-project/ash_lua/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshLua.DocsTest do
  use ExUnit.Case, async: false

  defp opts, do: [otp_app: :ash_lua]

  describe "list_callables/1" do
    test "enumerates every operation path, sorted" do
      callables = AshLua.Docs.list_callables(opts())

      assert "posts.post.create" in callables
      assert "posts.post.read" in callables
      assert "posts.post.publish" in callables
      assert "posts.post.word_count" in callables
      assert "posts.user.read" in callables
      assert "posts.comment.create" in callables

      assert callables == Enum.sort(callables)
    end
  end

  describe "topics/1 and topic_doc/2" do
    test "lists the available topics, sorted" do
      assert AshLua.Docs.topics(opts()) == [
               "error-handling",
               "filters",
               "pagination",
               "print-output",
               "transactions"
             ]
    end

    test "renders the filters topic" do
      {:ok, md} = AshLua.Docs.topic_doc(opts(), "filters")
      assert md =~ "# Filters"
      assert md =~ "`filter`"
      assert md =~ "Boolean combinators"
      assert md =~ ~s/["and"]/
      assert md =~ ~s/["or"]/
      assert md =~ ~s/["not"]/
    end

    test "renders the transactions topic" do
      {:ok, md} = AshLua.Docs.topic_doc(opts(), "transactions")
      assert md =~ "# Transactions"
      assert md =~ "utils.transaction"
      assert md =~ "rolled back"
    end

    test "renders the pagination topic" do
      {:ok, md} = AshLua.Docs.topic_doc(opts(), "pagination")
      assert md =~ "# Pagination"
      assert md =~ "`page`"
      assert md =~ "`limit`"
      assert md =~ "`more?`"
    end

    test "renders the error-handling topic" do
      {:ok, md} = AshLua.Docs.topic_doc(opts(), "error-handling")
      assert md =~ "# Error handling"
      assert md =~ "a result and an error"
      assert md =~ "assert"
      assert md =~ "short_message"
      assert md =~ "unknown_field"
      assert md =~ ~s/class  = "<invalid | forbidden | framework | unknown>"/
    end

    test "unknown topic returns {:error, :not_found}" do
      assert {:error, :not_found} = AshLua.Docs.topic_doc(opts(), "nope")
    end
  end

  describe "search/2" do
    test "ranks exact id matches highest" do
      md = AshLua.Docs.search(opts(), "filters")

      assert md =~ "# Search results for `filters`"
      assert md =~ "- `filters` (topic)"
    end

    # Catches: a natural-language search ("post comments") returning nothing
    # because no identifier contains the whole phrase.
    test "a phrase with no whole match falls back to its words, all-word matches first" do
      md = AshLua.Docs.search(opts(), "post comments")

      refute md =~ "_No matches._"
      assert md =~ "`posts.comment`"

      [first | _] = Regex.scan(~r/^- `([^`]+)`/m, md, capture: :all_but_first)
      assert hd(first) =~ "comment"
    end

    # Catches: "on"/"of" in a natural-language phrase matching nearly every page and
    # drowning the record whose summary matches every meaningful word.
    test "short words in a phrase do not affect ranking" do
      results = fn term -> Regex.scan(~r/^- `([^`]+)`/m, AshLua.Docs.search(opts(), term)) end
      assert results.("post comments") == results.("post on comments")
    end

    # Catches: an inflected word ("commenting") missing the record it names.
    test "a long word in a phrase also matches on its stem" do
      md = AshLua.Docs.search(opts(), "post commenting")
      assert md =~ "`posts.comment`"
    end

    test "matches substrings in identifiers" do
      md = AshLua.Docs.search(opts(), "post")

      assert md =~ "`posts.post`"
      assert md =~ "`posts.post.read`"
      assert md =~ "`posts.post.create`"
    end

    test "matches description text for callables when id doesn't match" do
      # `:word_count` action is on Post but the term "word" only appears in
      # the action's name itself, which is part of its id. Confirm the
      # callable shows up regardless.
      md = AshLua.Docs.search(opts(), "word")
      assert md =~ "posts.post.word_count"
    end

    test "blank term returns a please-provide-a-term placeholder" do
      assert AshLua.Docs.search(opts(), "") =~ "Please provide a search term"
      assert AshLua.Docs.search(opts(), "   ") =~ "Please provide a search term"
    end

    test "no matches returns a no-matches blurb" do
      md = AshLua.Docs.search(opts(), "thiswillneverexistanywhere")
      assert md =~ "_No matches._"
      assert md =~ "Use `name` instead"
    end
  end

  describe "list_types/1" do
    test "lists record types by their Lua path" do
      types = AshLua.Docs.list_types(opts())

      assert "posts.post" in types
      assert "posts.user" in types
      assert "posts.comment" in types
    end
  end

  describe "callable_doc/2" do
    test "unknown path returns {:error, :not_found}" do
      assert {:error, :not_found} = AshLua.Docs.callable_doc(opts(), "posts.post.nope")
    end

    test "create renders fields + a fields-selection row, with no internal vocabulary" do
      {:ok, md} = AshLua.Docs.callable_doc(opts(), "posts.post.create")

      assert md =~ "# `posts.post.create`"
      assert md =~ "**Operation:** `create`"
      assert md =~ "| `input` | table | yes |"
      assert md =~ "| `input.title` |"
      assert md =~ "| `fields` |"
      assert md =~ "default = primary key only"

      refute md =~ "Ash"
      refute md =~ "attribute"
      refute md =~ "argument"
      refute md =~ "resource"
    end

    test "list (read) renders filter/sort/limit/offset/page rows" do
      {:ok, md} = AshLua.Docs.callable_doc(opts(), "posts.post.read")

      assert md =~ "**Operation:** `list`"
      # Catches: the page naming the fields shape ("selection tree") without showing it.
      assert md =~ ~s|{ author = { "name" } }|
      assert md =~ "| `filter` |"
      assert md =~ "| `sort` |"
      assert md =~ "| `limit` |"
      assert md =~ "| `offset` |"
      assert md =~ "| `page` |"
      assert md =~ "A list of"

      refute md =~ "Ash.Query"
    end

    test "update + delete require the primary key" do
      {:ok, update_md} = AshLua.Docs.callable_doc(opts(), "posts.post.update")
      {:ok, delete_md} = AshLua.Docs.callable_doc(opts(), "posts.post.destroy")

      assert update_md =~ "**Operation:** `update`"
      assert update_md =~ "| `input.id` |"
      assert update_md =~ "identifies the record"
      assert delete_md =~ "**Operation:** `delete`"
      assert delete_md =~ "| `input.id` |"
    end

    test "generic (call) renders its inputs and return type" do
      {:ok, md} = AshLua.Docs.callable_doc(opts(), "posts.post.word_count")

      assert md =~ "**Operation:** `call`"
      assert md =~ "| `input.text` | `string` | yes"
      assert md =~ "`integer`"
      refute md =~ "selection tree"
    end
  end

  describe "type_doc/2" do
    test "renders a record type by Lua path with fields and related records" do
      {:ok, md} = AshLua.Docs.type_doc(opts(), "posts.post")

      assert md =~ "# Record type `posts.post`"
      assert md =~ "**Primary key:** `id`"
      assert md =~ "## Fields"
      assert md =~ "| `title` | `string`"
      assert md =~ "| `comment_count` | `integer` | summary (count of related records) |"
      assert md =~ "| `title_downcase` | `string` | computed |"
      assert md =~ "| `title_prefixed` | `string` | computed; input: `prefix: string` |"
      assert md =~ "## Related records"
      assert md =~ "| `author` | one |"
      assert md =~ "| `comments` | many |"

      refute md =~ "Ash"
      refute md =~ "attribute"
      refute md =~ "calculation"
      refute md =~ "aggregate"
      refute md =~ "belongs_to"
      refute md =~ "has_many"
    end

    # Catches: a script asserting an aggregate over no rows and dying on
    # "assertion failed: nil" because the docs never said it returns nil.
    test "the reserved keys say empty aggregates return nil" do
      md = AshLua.Docs.index_doc(opts())
      assert md =~ "return `nil` with no error when nothing"
    end

    # Catches: a record page with no route to the operations that read it, so a
    # model that opens the record type cannot find its (differently named) read.
    test "a record page names the operations that act on it" do
      {:ok, md} = AshLua.Docs.type_doc(opts(), "posts.post")
      [ops] = Regex.run(~r/\*\*Operations:\*\* (.+)/, md, capture: :all_but_first)

      assert ops =~ "`posts.post.read`"
      assert ops =~ "`posts.post.create`"
    end

    test "unknown identifier returns {:error, :not_found}" do
      assert {:error, :not_found} = AshLua.Docs.type_doc(opts(), "posts.bogus")
      assert {:error, :not_found} = AshLua.Docs.type_doc(opts(), Some.Bogus.Module)
    end

    test "named enum type renders its allowed values" do
      {:ok, md} = AshLua.Docs.type_doc(opts(), "Status")

      assert md =~ "# Type `Status`"
      assert md =~ "**Kind:** enum"
      assert md =~ "**Allowed values:**"
      assert md =~ "- `draft`"
      assert md =~ "- `published`"
      assert md =~ "- `archived`"
    end

    test "NewType renders with its subtype kind" do
      {:ok, md} = AshLua.Docs.type_doc(opts(), "Slug")

      assert md =~ "# Type `Slug`"
      assert md =~ "**Kind:**"
      assert md =~ "string"
    end

    test "an input's literal default is named" do
      {:ok, md} = AshLua.Docs.callable_doc(opts(), "posts.post.ranked")

      assert md =~ "| `input.order` |"
      assert md =~ "default: `newest`"
    end

    test "an atom field with one_of constraints lists its values" do
      {:ok, md} = AshLua.Docs.type_doc(opts(), "posts.comment")

      assert md =~ "| `mood` | `one of: pleased, annoyed`"
      refute md =~ "enum:Enum"
    end

    test "a type the manifest cannot classify is named, not shown as unknown" do
      {:ok, md} = AshLua.Docs.type_doc(opts(), "posts.comment")

      assert md =~ "| `tip` | `opaque_amount`"
      refute md =~ "`unknown`"
    end

    test "record-type page cross-links to named-type pages for enum + NewType fields" do
      {:ok, md} = AshLua.Docs.type_doc(opts(), "posts.post")

      assert md =~ "| `status` | [`Status`](#status)"
      assert md =~ "| `slug` | [`Slug`](#slug)"
    end

    test "embedded resource renders as a named type, addressable by short name" do
      types = AshLua.Docs.list_types(opts())
      assert "ScheduleConfig" in types

      {:ok, md} = AshLua.Docs.type_doc(opts(), "ScheduleConfig")
      assert md =~ "# Embedded type `ScheduleConfig`"
      assert md =~ "| `cadence` |"
      assert md =~ "| `hour` |"

      # Embedded resources have no domain, so they must not show up as
      # path-addressable record types.
      refute md =~ "**Primary key:**"
      refute md =~ "## Filterable fields"
      refute md =~ "## Related records"
    end

    test "fields whose type is an embedded resource cross-link to the embedded type page" do
      {:ok, md} = AshLua.Docs.type_doc(opts(), "posts.post")
      assert md =~ "| `schedule_config` | [`ScheduleConfig`](#scheduleconfig) |"
    end

    test "full_doc/1 does not crash on embedded resources" do
      md = AshLua.Docs.full_doc(opts())
      assert is_binary(md)
      assert md =~ "# Embedded type `ScheduleConfig`"
    end

    test "record-type page renders Filterable + Sortable sections per field" do
      {:ok, md} = AshLua.Docs.type_doc(opts(), "posts.post")

      assert md =~ "## Filterable fields"
      # Fields with the same type and operators share one entry rather than
      # repeating the list per field.
      assert md =~ "### `body`, `title`, `title_downcase`, `title_prefixed` (`string`)\n"
      # Operators render with the shortest valid-identifier name from the
      # manifest's per-operator alias list — `:==` → `eq`, `:>` → `greater_than`.
      for op <-
            ~w(eq not_eq less_than greater_than less_than_or_equal greater_than_or_equal contains) do
        assert md =~ ~r/^  - value `string`: [^\n]*`#{op}`(,|$)/m, "missing #{op}"
      end

      assert md =~ ~r/^  - value list of `string`: [^\n]*`in`/m
      assert md =~ ~r/^  - value `boolean`: [^\n]*`is_nil`/m

      # Bare canonical symbols never leak into the rendered docs.
      refute md =~ "- `==`"
      refute md =~ "- `!=`"
      refute md =~ "- `<`"
      refute md =~ "- `>`"

      assert md =~ "## Sortable fields"
      assert md =~ "- `title`"
    end

    test "filter RHS cross-links to a named type when the field uses a custom type" do
      {:ok, md} = AshLua.Docs.type_doc(opts(), "posts.post")

      # `status` is a custom enum type — `eq` RHS is :same, so it should
      # cross-link to the Status type page rather than show a builtin atom.
      assert md =~ ~r/^### [^\n]*`status`[^\n]* \(\[`Status`\]\(#status\)\)$/m
      assert md =~ ~r/^  - value \[`Status`\]\(#status\): [^\n]*`eq`/m
    end
  end

  describe "index_doc/1" do
    test "lists every callable, record type, and topic as bullets without bodies" do
      md = AshLua.Docs.index_doc(opts())

      for path <- AshLua.Docs.list_callables(opts()) do
        assert md =~ "- `#{path}`", "missing operation bullet: #{path}"
      end

      assert md =~ "## Operations"
      assert md =~ "## Record types"
      assert md =~ "## Topics"
      assert md =~ "- `posts.post`"
      assert md =~ "- `filters`"

      # No per-page bodies leak into the index.
      refute md =~ "## Returns"
      refute md =~ "## Filterable fields"
    end

    test "hints how to fetch the full page and roughly how big it is" do
      md = AshLua.Docs.index_doc(opts())

      assert md =~ ~s(`name = "full"`)
      assert md =~ "characters"
      assert md =~ "tokens"
    end

    test "is dramatically smaller than the full page" do
      assert byte_size(AshLua.Docs.index_doc(opts())) <
               byte_size(AshLua.Docs.full_doc(opts()))
    end
  end

  describe "abridged_doc/1" do
    test "lists every callable on one line each" do
      md = AshLua.Docs.abridged_doc(opts())

      for path <- AshLua.Docs.list_callables(opts()) do
        assert md =~ "- `#{path}`", "missing callable: #{path}"
      end

      refute md =~ "## Record types"
      refute md =~ ~r/^- `posts\.post` — /m

      assert md =~
               ~r/^- `posts\.post\.create` \(title!: string, .*schedule_config: ScheduleConfig/m

      assert md =~ "→ list of `posts.post`"
      assert md =~ "## Topics"
    end

    test "marks required inputs and primary keys" do
      md = AshLua.Docs.abridged_doc(opts())

      assert md =~ ~r/^- `posts\.post\.word_count` \(text!: string\) → `integer`$/m
      assert md =~ ~r/^- `posts\.post\.publish` \(id!\) → `posts\.post`$/m
    end

    test "spells out union members and map fields" do
      md = AshLua.Docs.abridged_doc(opts())

      assert md =~
               "content: one-of(text: {body!: string, word_count: integer} | link: {url!: string"

      assert md =~ "metadata: {priority: integer, category: string, notify: boolean}"
    end

    test "lists only named types that operations reference" do
      md = AshLua.Docs.abridged_doc(opts())

      assert md =~ ~r/^- `ScheduleConfig` — embedded: /m
      assert md =~ ~r/^- `Slug` — string$/m
    end

    test "renders enum values inline" do
      md = AshLua.Docs.abridged_doc(opts())

      assert md =~ ~r/^- `Status` — enum: /m
    end

    test "omits descriptions and filter tables" do
      md = AshLua.Docs.abridged_doc(opts())

      refute md =~ "## Filterable fields"
      refute md =~ "## Returns"
      assert byte_size(md) < byte_size(AshLua.Docs.full_doc(opts()))
    end

    test "the index points to it" do
      assert AshLua.Docs.index_doc(opts()) =~ ~s(`name = "abridged"`)
    end
  end

  describe "full_doc/1" do
    test "covers every callable and every record type" do
      md = AshLua.Docs.full_doc(opts())

      for path <- AshLua.Docs.list_callables(opts()) do
        assert md =~ "# `#{path}`", "missing callable: #{path}"
      end

      assert md =~ "# Record type `posts.post`"
      assert md =~ "# Record type `posts.user`"
      assert md =~ "## Reserved input keys"
    end

    test "renders the named-types section when there are named types" do
      md = AshLua.Docs.full_doc(opts())

      assert md =~ "## Named types"
      assert md =~ "# Type `Status`"
      assert md =~ "# Type `Slug`"
    end
  end
end
