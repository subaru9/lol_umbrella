defmodule LolWeb.ErrorJSONTest do
  use LolWeb.ConnCase, async: true

  test "renders 404" do
    assert LolWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert LolWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
