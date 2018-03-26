defmodule CallSync.Router do
  use CallSync.Web, :router

  pipeline :main do
    plug(CallSync.SecretPlug)
  end

  scope "/", CallSync do
    pipe_through(:main)

    get("/", IndexController, :index)
    get("/status", IndexController, :status)
    get("/configure/:slug", IndexController, :configure_lookup)
    get("/validate/:slug", IndexController, :validate)
    get("/run/:slug", IndexController, :run)
    get("/drop-rate", IndexController, :drop_rate)
    post("/drop-rate", IndexController, :drop_rate)
  end
end
