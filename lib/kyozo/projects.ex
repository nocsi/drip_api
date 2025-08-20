defmodule Kyozo.Projects do
  use Ash.Domain,
    otp_app: :kyozo,
    extensions: [AshJsonApi.Domain]

  # GraphQL configuration removed during GraphQL cleanup

  json_api do
    authorize? false
  end

  resources do
    resource Kyozo.Projects.Project do
      define :load_project, args: [:path]
      define :load_directory, args: [:path]
      define :load_file, args: [:path]
      define :get_project, action: :read, get_by: :id
      define :list_projects
      define :delete_project, action: :destroy
    end

    resource Kyozo.Projects.Document do
      define :list_documents
      define :get_document, action: :read, get_by: :id
      define :list_project_documents, args: [:project_id]
    end

    resource Kyozo.Projects.Task do
      define :list_tasks
      define :get_task, action: :read, get_by: :id
      define :list_document_tasks, args: [:document_id]
      define :list_project_tasks, args: [:project_id]
    end

    resource Kyozo.Projects.LoadEvent do
      define :list_events
      define :list_project_events, args: [:project_id]
    end
  end
end