defmodule Streamvault.Videos.Video do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "videos" do
      field :title, :string
      field :actors, {:array, :string}
      field :description, :string
      field :original_filename, :string
      field :duration_seconds, :integer

    timestamps()
  end

  @doc false
  def changeset(video, attrs) do
    video
    |> cast(attrs, [:title, :actors, :description, :original_filename, :duration_seconds])
    |> validate_required([:title, :original_filename])
  end

end
