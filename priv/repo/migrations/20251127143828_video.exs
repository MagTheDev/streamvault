defmodule Streamvault.Repo.Migrations.Video do
  use Ecto.Migration

  def change do
    create table(:videos, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :title, :string, null: false
      add :actors, {:array, :string}
      add :description, :text
      add :original_filename, :string, null: false
      add :duration_seconds, :integer

      timestamps()
    end
  end
end
