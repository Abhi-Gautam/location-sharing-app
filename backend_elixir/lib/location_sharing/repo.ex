defmodule LocationSharing.Repo do
  use Ecto.Repo,
    otp_app: :location_sharing,
    adapter: Ecto.Adapters.Postgres
end
