defmodule DirupWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  alias AshAuthentication.Phoenix.Components

  override Components.Banner do
    set :image_url, nil
    set :dark_image_url, nil
    set :text_class, "text-8xl text-accent-400"
    set :text, "♫"
  end

  override Components.Password do
    set :toggler_class, "flex-none text-primary-600 px-2 first:pl-0 last:pr-0"
  end

  override Components.Password.Input do
    set :field_class, "mt-4"
    set :label_class, "block text-sm font-medium leading-6 text-zinc-800"
    set :input_class, DirupWeb.CoreComponents.form_input_styles()

    set :input_class_with_error, [
      DirupWeb.CoreComponents.form_input_styles(),
      "!border-error-400 focus:!border-error-600 focus:!ring-error-100"
    ]

    set :submit_class, [
      "phx-submit-loading:opacity-75 my-4 py-3 px-5 text-sm",
      "bg-primary-600 hover:bg-primary-700 text-white",
      "rounded-lg font-medium leading-none cursor-pointer"
    ]

    set :error_ul, "mt-2 flex gap-2 text-sm leading-6 text-error-600"
  end

  override Components.MagicLink do
    set :request_flash_text, "Check your email for a sign-in link!"
  end

  override Components.MagicLink.Input do
    set :submit_class, [
      "phx-submit-loading:opacity-75 my-8 mx-auto py-3 px-5 text-sm",
      "bg-primary-600 hover:bg-primary-700 text-white",
      "rounded-lg font-medium leading-none block cursor-pointer"
    ]
  end

  override Components.Confirm.Input do
    set :submit_class, [
      "phx-submit-loading:opacity-75 my-8 mx-auto py-3 px-5 text-sm",
      "bg-primary-600 hover:bg-primary-700 text-white",
      "rounded-lg font-medium leading-none block cursor-pointer"
    ]
  end

  override Components.OAuth2 do
    set :separator_class, "my-6 flex items-center"
    set :separator_text_class, "px-3 text-sm text-gray-500"
    set :separator_line_class, "flex-1 border-t border-gray-300"
  end

  override Components.OAuth2.Input do
    set :button_class, [
      "w-full flex justify-center items-center px-4 py-2 border border-gray-300",
      "rounded-md shadow-sm bg-white text-sm font-medium text-gray-700",
      "hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2",
      "focus:ring-primary-500 transition-colors duration-200"
    ]

    set :icon_class, "w-5 h-5 mr-2"
  end
end
