defmodule CallSync.IndexView do
  use CallSync.Web, :view
  use Phoenix.HTML

  def csrf_token do
    Plug.CSRFProtection.get_csrf_token()
  end
end
