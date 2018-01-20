defmodule CallSync.Router do
  use CallSync.Web, :router

  scope "/", CallSync do
    get("/", IndexController, :index)
    get("/question-lookup/:slug", IndexController, :question_lookup)
  end
end
