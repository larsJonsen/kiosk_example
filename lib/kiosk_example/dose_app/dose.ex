defmodule DoseApp.Dose do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field(:dose, :decimal)
  end

  def changeset(dose, params \\ %{}) do
    dose
    |> cast(params, [:dose])
    |> validate_required([:dose])
  end
end
