defmodule MessagingApi.ErrorJSON do
  @moduledoc """
  This module is invoked by the endpoint in case of errors on JSON requests.
  """

  def render("404.json", _assigns) do
    %{error: "Not found"}
  end

  def render("500.json", _assigns) do
    %{error: "Internal server error"}
  end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def template_not_found(_template, _assigns) do
    %{error: "Internal server error"}
  end
end
