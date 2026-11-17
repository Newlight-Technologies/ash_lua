# SPDX-License-Identifier: MIT

defmodule AshLua.Docs.Projection do
  @moduledoc false
  alias Ash.Error.Action.InvalidArgument

  def render(manifest, name, fields) do
    with :ok <- validate_target(%{name: name}),
         :ok <- validate_list(fields),
         {:ok, resource} <- find_record(manifest, name),
         :ok <- validate_fields(resource, fields) do
      # Only the documentation copy is narrowed. Evaluation and the cached
      # manifest retain the full governed surface, including field policies.
      selected = MapSet.new(fields)

      projected = %{
        resource
        | fields: select_names(resource.fields, resource.module, selected),
          relationships: select_names(resource.relationships, resource.module, selected)
      }

      projected_manifest = %{
        manifest
        | resources:
            Enum.map(manifest.resources, fn
              %{module: module} when module == resource.module -> projected
              other -> other
            end)
      }

      with {:ok, page} <- AshLua.Docs.type_doc(projected_manifest, resource.module) do
        if fields == [] do
          {:ok, page <> catalog(resource)}
        else
          {:ok,
           page <>
             "\n\nOnly the requested fields/relationships are documented here; " <>
             "other fields have not been declared absent. Omit `fields` for the complete page."}
        end
      end
    end
  end

  defp validate_target(%{name: name} = arguments) when is_binary(name) and name != "" do
    if arguments[:search] in [nil, ""],
      do: :ok,
      else: invalid(:fields, "requires a record-type `name`, without `search`")
  end

  defp validate_target(_),
    do: invalid(:fields, "requires a record-type `name`, without `search`")

  defp find_record(manifest, name) do
    case Enum.find(manifest.resources, fn %{module: module} ->
           AshLua.Resource.Info.expose?(module) and
             AshLua.Domain.Info.name(Ash.Resource.Info.domain(module)) <>
               "." <> AshLua.Resource.Info.name(module) == name
         end) do
      nil -> invalid(:name, "must name an exposed record type when `fields` is supplied")
      resource -> {:ok, resource}
    end
  end

  defp validate_list(fields) when is_list(fields) do
    if Enum.all?(fields, &is_binary/1),
      do: :ok,
      else: invalid(:fields, "must be a list of field names")
  end

  defp validate_list(_), do: invalid(:fields, "must be a list of field names")

  defp validate_fields(resource, fields) do
    known =
      MapSet.new(
        names(resource.fields, resource.module) ++ names(resource.relationships, resource.module)
      )

    unknown = Enum.reject(fields, &MapSet.member?(known, &1)) |> Enum.uniq()

    case unknown do
      [] -> :ok
      _ -> invalid(:fields, "unknown field or relationship names: #{Enum.join(unknown, ", ")}")
    end
  end

  defp select_names(entries, module, selected) do
    Map.filter(entries, fn {name, _entry} ->
      MapSet.member?(selected, AshLua.FieldNames.to_lua_field_name(module, name))
    end)
  end

  defp names(entries, module) do
    entries
    |> Map.keys()
    |> Enum.map(&AshLua.FieldNames.to_lua_field_name(module, &1))
    |> Enum.sort()
  end

  defp catalog(resource) do
    """


    ## Field-name catalog

    Names only, not query contracts or proof of access to values. Request the
    fields you need with `fields` to read their descriptions, exact types, enum
    values, filter operators, sort support and authorization notes before querying.

    Fields: #{Enum.map_join(names(resource.fields, resource.module), ", ", &"`#{&1}`")}

    Relationships: #{Enum.map_join(names(resource.relationships, resource.module), ", ", &"`#{&1}`")}
    """
  end

  defp invalid(field, message) do
    {:error, InvalidArgument.exception(field: field, message: message)}
  end
end
