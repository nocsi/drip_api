defmodule DirupWeb.JsonApi.ArtistTest do
  use DirupWeb.ConnCase, async: true

  import AshJsonApi.Test

  test "can search artists" do
    generate(artist(name: "one", album_count: 1))
    generate(artist(name: "two"))
    generate(artist(name: "three"))

    get(
      Dirup.Music,
      "/artists?sort=-name&query=o&fields=name,album_count",
      router: DirupWeb.AshJsonApiRouter,
      status: 200
    )
    |> assert_data_matches([
      %{"attributes" => %{"name" => "two", "album_count" => 0}},
      %{"attributes" => %{"name" => "one", "album_count" => 1}}
    ])
  end

  test "can read an artist by ID" do
    artist = generate(artist(name: "Hello world!"))

    get(
      Dirup.Music,
      "/artists/#{artist.id}",
      router: DirupWeb.AshJsonApiRouter,
      status: 200
    )
    |> assert_data_matches(%{
      "attributes" => %{"name" => "Hello world!"}
    })
  end

  test "can create an artist" do
    user = generate(user(role: :admin))

    post(
      Dirup.Music,
      "/artists",
      %{
        data: %{
          attributes: %{name: "New JSON:API artist"}
        }
      },
      router: DirupWeb.AshJsonApiRouter,
      status: 201,
      actor: user
    )
    |> assert_data_matches(%{
      "attributes" => %{"name" => "New JSON:API artist"}
    })
  end

  test "can update an artist" do
    user = generate(user(role: :admin))
    artist = generate(artist())

    patch(
      Dirup.Music,
      "/artists/#{artist.id}",
      %{
        data: %{
          attributes: %{name: "Updated name"}
        }
      },
      router: DirupWeb.AshJsonApiRouter,
      status: 200,
      actor: user
    )
    |> assert_data_matches(%{
      "attributes" => %{"name" => "Updated name"}
    })
  end

  test "can delete an artist" do
    user = generate(user(role: :admin))
    artist = generate(artist(name: "Test"))

    delete(
      Dirup.Music,
      "/artists/#{artist.id}",
      router: DirupWeb.AshJsonApiRouter,
      status: 200,
      actor: user
    )
    |> assert_data_matches(%{
      "attributes" => %{"name" => "Test"}
    })
  end
end
