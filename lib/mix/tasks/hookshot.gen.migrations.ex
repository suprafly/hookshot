defmodule Mix.Tasks.Hookshot.Gen.Migrations do
  @moduledoc """
  This task creates migrations to add the required tables to the db.

  ## Usage

      mix hookshot.gen.migrations

  """
  @shortdoc "Creates migrations to add the required tables to the db."

  use Mix.Task

  def run(_args) do
    project_directory = Mix.Project.build_path() |> String.split("_build") |> List.first()
    module_name = Mix.Project.get() |> to_string() |> String.split(".") |> Enum.at(1)

    deps_directory = project_directory
    template_path = Path.join(deps_directory, "priv/templates/hookshot_table_migration.exs.eex")
    migrations_path = Path.join([project_directory, "priv/repo/migrations/", "#{get_migration_timestamp()}_hookshot_migration.exs"])

    Mix.Generator.copy_template(template_path, migrations_path, module_name: module_name)
  end

  defp get_migration_timestamp() do
    DateTime.utc_now()
    |> to_string()
    |> String.split(".")
    |> List.first()
    |> String.replace("-", "")
    |> String.replace(":", "")
    |> String.replace(" ", "")
  end
end
