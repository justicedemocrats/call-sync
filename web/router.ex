defmodule CallSync.Router do
  use CallSync.Web, :router

  pipeline :main do
    plug(CallSync.SecretPlug)
  end

  scope "/", CallSync do
    pipe_through :main

    get("/", IndexController, :index)
    get("/configure/:slug", IndexController, :question_lookup)
  end
end
