defmodule Dirup.Accounts.NotificationTest do
  use Dirup.ConnCase, async: false
  require Ash.Query

  describe "User Notifications" do
    test "User notification can be send" do
      user = create_user()

      attrs = %{
        recipient_user_id: user.id,
        subject: "You have been added to the new team",
        body: "This is a test notification body text."
      }

      {:ok, _notification} = Dirup.Accounts.notify(attrs, actor: user)

      # Confirm we have the notification in the database
      assert Dirup.Accounts.Notification
             |> Ash.Query.filter(recipient_user_id == ^user.id)
             |> Ash.Query.filter(subject == ^attrs.subject)
             |> Ash.Query.filter(body == ^attrs.body)
             |> Ash.Query.filter(processed == false)
             |> Ash.exists?(actor: user)

      # Confirm the job can be queued and triggered in the background
      assert %{success: 2} =
               AshOban.Test.schedule_and_run_triggers(
                 Dirup.Accounts.Notification,
                 actor: user
               )

      # Confirm the notification was processed and marked as such
      assert Dirup.Accounts.Notification
             |> Ash.Query.filter(recipient_user_id == ^user.id)
             |> Ash.Query.filter(subject == ^attrs.subject)
             |> Ash.Query.filter(body == ^attrs.body)
             |> Ash.Query.filter(processed == true)
             |> Ash.exists?(actor: user)
    end
  end
end
