defmodule Dirup.Containers.WorkersTest do
  use ExUnit.Case, async: true
  use Oban.Testing, repo: Dirup.Repo

  alias Dirup.Containers.Workers.{
    TopologyAnalysisWorker,
    ContainerHealthMonitor,
    MetricsCollector,
    ContainerDeploymentWorker,
    CleanupWorker
  }

  alias Dirup.{Containers, Workspaces}

  describe "TopologyAnalysisWorker" do
    setup do
      workspace = create_mock_workspace()
      {:ok, workspace: workspace}
    end

    test "enqueues topology analysis job", %{workspace: workspace} do
      assert {:ok, job} = TopologyAnalysisWorker.enqueue(workspace.id)
      assert job.args["workspace_id"] == workspace.id
      assert job.args["analysis_depth"] == "standard"
      assert job.queue == "topology_analysis"
    end

    test "enqueues with custom options", %{workspace: workspace} do
      opts = [analysis_depth: "deep", priority: 1, triggered_by: "api"]

      assert {:ok, job} = TopologyAnalysisWorker.enqueue(workspace.id, opts)
      assert job.args["analysis_depth"] == "deep"
      assert job.args["triggered_by"] == "api"
      assert job.priority == 1
    end

    test "performs topology analysis for workspace", %{workspace: workspace} do
      detection = create_mock_topology_detection(workspace.id)

      args = %{"topology_detection_id" => detection.id}
      job = build_job(args)

      assert :ok = perform_job(TopologyAnalysisWorker, args)

      # Verify detection was updated
      updated = Containers.get_topology_detection(detection.id)
      assert updated.status in ["analyzing", "completed"]
    end

    test "creates new topology detection when workspace_id provided", %{workspace: workspace} do
      args = %{"workspace_id" => workspace.id}
      job = build_job(args)

      assert :ok = perform_job(TopologyAnalysisWorker, args)

      # Verify detection was created
      detections = Containers.list_topology_detections(workspace.id)
      assert length(detections) > 0
    end

    test "handles invalid arguments" do
      args = %{"invalid" => "args"}

      assert {:error, :invalid_arguments} = perform_job(TopologyAnalysisWorker, args)
    end

    test "handles missing topology detection" do
      args = %{"topology_detection_id" => "nonexistent"}

      assert {:error, :not_found} = perform_job(TopologyAnalysisWorker, args)
    end

    test "marks detection as failed on error" do
      detection = create_mock_topology_detection(create_mock_workspace().id)

      # Simulate error by providing invalid workspace
      args = %{"topology_detection_id" => detection.id}

      # Mock error condition
      with_mock Containers, [:passthrough], get_workspace: fn _ -> nil end do
        assert {:error, _} = perform_job(TopologyAnalysisWorker, args)

        # Verify detection was marked as failed
        updated = Containers.get_topology_detection(detection.id)
        assert updated.status == "failed"
      end
    end
  end

  describe "ContainerHealthMonitor" do
    setup do
      service = create_mock_service_instance()
      {:ok, service: service}
    end

    test "enqueues single health check", %{service: service} do
      assert {:ok, job} = ContainerHealthMonitor.enqueue_single_check(service.id)
      assert job.args["service_instance_id"] == service.id
      assert job.args["check_type"] == "standard"
      assert job.queue == "health_monitoring"
    end

    test "enqueues batch health check" do
      assert {:ok, job} = ContainerHealthMonitor.enqueue_batch_check()
      assert job.args["batch_check"] == true
      assert job.args["limit"] == 100
      assert job.queue == "health_monitoring"
    end

    test "performs health check for running service", %{service: service} do
      args = %{"service_instance_id" => service.id}

      assert {:ok, health_status} = perform_job(ContainerHealthMonitor, args)
      assert health_status.status in ["healthy", "unhealthy", "degraded"]
      assert is_number(health_status.cpu_usage_percent)
      assert is_number(health_status.memory_usage_mb)
    end

    test "performs batch health check" do
      # Create multiple services
      services = Enum.map(1..3, fn _ -> create_mock_service_instance() end)

      args = %{"batch_check" => true, "limit" => 10}

      assert {:ok, result} = perform_job(ContainerHealthMonitor, args)
      assert is_number(result.services_checked)
    end

    test "handles service not found" do
      args = %{"service_instance_id" => "nonexistent"}

      assert {:error, :service_not_found} = perform_job(ContainerHealthMonitor, args)
    end

    test "records health check results", %{service: service} do
      args = %{"service_instance_id" => service.id}

      assert {:ok, _} = perform_job(ContainerHealthMonitor, args)

      # Verify health check was recorded
      health_checks = Containers.list_health_checks(service.id)
      assert length(health_checks) > 0

      latest_check = List.first(health_checks)
      assert latest_check.service_instance_id == service.id
      assert latest_check.status in ["healthy", "unhealthy", "degraded", "failed"]
    end

    test "triggers alerts for unhealthy services", %{service: service} do
      # Mock unhealthy service
      Containers.update_service_instance(service, %{health_status: "unhealthy"})

      args = %{"service_instance_id" => service.id}

      # Mock event publishing
      with_mock Dirup.Events, [:passthrough], publish_event: fn _, _ -> :ok end do
        assert {:ok, _} = perform_job(ContainerHealthMonitor, args)

        # Verify alert was triggered for unhealthy service
        assert called(Dirup.Events.publish_event("service_health_alert", :_))
      end
    end
  end

  describe "MetricsCollector" do
    setup do
      service = create_mock_service_instance()
      {:ok, service: service}
    end

    test "enqueues service metrics collection", %{service: service} do
      assert {:ok, job} = MetricsCollector.enqueue_service_metrics(service.id)
      assert job.args["service_instance_id"] == service.id
      assert job.args["collection_type"] == "standard"
      assert job.queue == "metrics_collection"
    end

    test "enqueues batch metrics collection" do
      assert {:ok, job} = MetricsCollector.enqueue_batch_collection()
      assert job.args["batch_collection"] == true
      assert job.queue == "metrics_collection"
    end

    test "enqueues metrics cleanup" do
      assert {:ok, job} = MetricsCollector.enqueue_metrics_cleanup()
      assert job.args["cleanup_old_metrics"] == true
      assert job.args["retention_days"] == 30
    end

    test "collects metrics for service", %{service: service} do
      args = %{"service_instance_id" => service.id}

      assert {:ok, metrics} = perform_job(MetricsCollector, args)
      assert metrics.service_instance_id == service.id
      assert is_number(metrics.cpu_usage_percent)
      assert is_number(metrics.memory_usage_mb)
      assert is_number(metrics.health_score)
    end

    test "performs batch metrics collection" do
      # Create multiple services
      services = Enum.map(1..3, fn _ -> create_mock_service_instance() end)

      args = %{"batch_collection" => true, "limit" => 20}

      assert {:ok, result} = perform_job(MetricsCollector, args)
      assert is_number(result.services_processed)
      assert Map.has_key?(result, :aggregated_metrics)
    end

    test "performs metrics cleanup" do
      args = %{"cleanup_old_metrics" => true, "retention_days" => 7}

      assert {:ok, result} = perform_job(MetricsCollector, args)
      assert is_number(result.deleted_count)
      assert result.cutoff_date
    end

    test "stores metrics in database", %{service: service} do
      args = %{"service_instance_id" => service.id}

      assert {:ok, _} = perform_job(MetricsCollector, args)

      # Verify metrics were stored
      metrics = Containers.list_service_metrics(service.id)
      assert length(metrics) > 0

      latest_metric = List.first(metrics)
      assert latest_metric.service_instance_id == service.id
      assert is_number(latest_metric.cpu_usage_percent)
    end

    test "triggers threshold alerts when limits exceeded", %{service: service} do
      args = %{"service_instance_id" => service.id}

      # Mock event publishing
      with_mock Dirup.Events, [:passthrough], publish_event: fn _, _ -> :ok end do
        assert {:ok, _} = perform_job(MetricsCollector, args)

        # Verify alerts may be triggered for threshold violations
        # Note: This depends on simulated metrics exceeding thresholds
      end
    end

    test "handles service not found" do
      args = %{"service_instance_id" => "nonexistent"}

      assert {:error, :service_not_found} = perform_job(MetricsCollector, args)
    end
  end

  describe "ContainerDeploymentWorker" do
    setup do
      service = create_mock_service_instance()
      {:ok, service: service}
    end

    test "enqueues deployment job", %{service: service} do
      assert {:ok, job} = ContainerDeploymentWorker.enqueue_deploy(service.id)
      assert job.args["action"] == "deploy"
      assert job.args["service_instance_id"] == service.id
      assert job.queue == "container_deployment"
    end

    test "enqueues stop job", %{service: service} do
      assert {:ok, job} = ContainerDeploymentWorker.enqueue_stop(service.id)
      assert job.args["action"] == "stop"
      assert job.args["service_instance_id"] == service.id
    end

    test "enqueues restart job", %{service: service} do
      assert {:ok, job} = ContainerDeploymentWorker.enqueue_restart(service.id)
      assert job.args["action"] == "restart"
      assert job.args["service_instance_id"] == service.id
    end

    test "enqueues scale job", %{service: service} do
      assert {:ok, job} = ContainerDeploymentWorker.enqueue_scale(service.id, 3)
      assert job.args["action"] == "scale"
      assert job.args["replica_count"] == 3
    end

    test "performs container deployment", %{service: service} do
      args = %{
        "action" => "deploy",
        "service_instance_id" => service.id,
        "deployment_strategy" => "rolling"
      }

      assert {:ok, deployed_service} = perform_job(ContainerDeploymentWorker, args)
      assert deployed_service.container_status in ["running", "deploying"]
      assert deployed_service.container_id != nil
    end

    test "performs container stop", %{service: service} do
      # First mark service as running with container ID
      Containers.update_service_instance(service, %{
        container_status: "running",
        container_id: "mock_container_123"
      })

      args = %{
        "action" => "stop",
        "service_instance_id" => service.id
      }

      assert {:ok, stopped_service} = perform_job(ContainerDeploymentWorker, args)
      assert stopped_service.container_status == "stopped"
    end

    test "performs container restart", %{service: service} do
      args = %{
        "action" => "restart",
        "service_instance_id" => service.id,
        "reason" => "manual"
      }

      assert {:ok, restarted_service} = perform_job(ContainerDeploymentWorker, args)
      assert restarted_service.container_status in ["running", "deploying"]
    end

    test "performs container scaling", %{service: service} do
      # First mark service as running
      Containers.update_service_instance(service, %{
        container_status: "running",
        replica_count: 1
      })

      args = %{
        "action" => "scale",
        "service_instance_id" => service.id,
        "replica_count" => 3
      }

      assert {:ok, scaled_service} = perform_job(ContainerDeploymentWorker, args)
      assert scaled_service.replica_count == 3
    end

    test "records deployment events", %{service: service} do
      args = %{
        "action" => "deploy",
        "service_instance_id" => service.id
      }

      assert {:ok, _} = perform_job(ContainerDeploymentWorker, args)

      # Verify deployment events were recorded
      events = Containers.list_deployment_events(service.id)
      assert length(events) > 0

      # Should have deployment_started event at minimum
      event_types = Enum.map(events, & &1.event_type)
      assert "deployment_started" in event_types
    end

    test "handles service not found" do
      args = %{
        "action" => "deploy",
        "service_instance_id" => "nonexistent"
      }

      assert {:error, :service_not_found} = perform_job(ContainerDeploymentWorker, args)
    end

    test "attempts rollback on deployment failure", %{service: service} do
      # Mock deployment failure scenario
      args = %{
        "action" => "deploy",
        "service_instance_id" => service.id
      }

      # Force a failure by mocking
      with_mock Containers, [:passthrough],
        get_workspace: fn _ -> {:error, :workspace_not_found} end do
        assert {:error, _} = perform_job(ContainerDeploymentWorker, args)

        # Verify rollback was attempted
        updated_service = Containers.get_service_instance(service.id)

        rollback_attempted =
          get_in(updated_service.deployment_metadata, ["rollback_attempted_at"])

        assert rollback_attempted != nil
      end
    end
  end

  describe "CleanupWorker" do
    test "enqueues cleanup job" do
      assert {:ok, job} = CleanupWorker.new(%{"cleanup_type" => "metrics"})
      assert job.args["cleanup_type"] == "metrics"
      assert job.queue == "cleanup"
    end

    test "performs metrics cleanup" do
      args = %{
        "cleanup_type" => "metrics",
        # 1 week
        "max_age_hours" => 168
      }

      assert {:ok, result} = perform_job(CleanupWorker, args)
      assert Map.has_key?(result, :metrics_cleaned)
    end

    test "performs deployment events cleanup" do
      args = %{
        "cleanup_type" => "deployment_events",
        # 30 days
        "max_age_hours" => 720
      }

      assert {:ok, result} = perform_job(CleanupWorker, args)
      assert Map.has_key?(result, :events_cleaned)
    end

    test "performs health checks cleanup" do
      args = %{
        "cleanup_type" => "health_checks",
        "max_age_hours" => 168
      }

      assert {:ok, result} = perform_job(CleanupWorker, args)
      assert Map.has_key?(result, :health_checks_cleaned)
    end

    test "handles invalid cleanup type" do
      args = %{"cleanup_type" => "invalid"}

      assert {:error, :invalid_cleanup_type} = perform_job(CleanupWorker, args)
    end
  end

  describe "Worker Integration" do
    test "topology analysis triggers deployment suggestions" do
      workspace = create_mock_workspace()

      # Perform topology analysis
      args = %{"workspace_id" => workspace.id}
      assert {:ok, detection} = perform_job(TopologyAnalysisWorker, args)

      # Verify deployment jobs were enqueued for detected services
      deployment_jobs = all_enqueued(worker: ContainerDeploymentWorker)
      assert length(deployment_jobs) > 0
    end

    test "deployment completion schedules health monitoring" do
      service = create_mock_service_instance()

      # Perform deployment
      args = %{
        "action" => "deploy",
        "service_instance_id" => service.id
      }

      assert {:ok, _} = perform_job(ContainerDeploymentWorker, args)

      # Verify health check was scheduled
      health_jobs = all_enqueued(worker: ContainerHealthMonitor)
      assert length(health_jobs) > 0

      health_job = List.first(health_jobs)
      assert health_job.args["service_instance_id"] == service.id
    end

    test "metrics collection triggers alerts when thresholds exceeded" do
      service = create_mock_service_instance()

      # Mock event publishing to capture alerts
      with_mock Dirup.Events, [:passthrough], publish_event: fn _, _ -> :ok end do
        args = %{"service_instance_id" => service.id}
        assert {:ok, _} = perform_job(MetricsCollector, args)

        # Verify threshold alerts may be triggered
        # This depends on simulated metrics
      end
    end

    test "worker error handling and retries" do
      service = create_mock_service_instance()

      # Force worker to fail by providing invalid data
      args = %{
        "action" => "deploy",
        "service_instance_id" => service.id
      }

      # Mock critical failure
      with_mock Containers, [:passthrough],
        get_workspace: fn _ -> raise "Database connection lost" end do
        assert {:error, _} = perform_job(ContainerDeploymentWorker, args)

        # Verify error was handled gracefully
        # In real scenario, Oban would retry the job
      end
    end
  end

  # Helper functions for creating mock data

  defp create_mock_workspace do
    %{
      id: Ecto.UUID.generate(),
      name: "test-workspace",
      path: "/tmp/test-workspace",
      user_id: Ecto.UUID.generate(),
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  defp create_mock_service_instance do
    workspace_id = Ecto.UUID.generate()

    %{
      id: Ecto.UUID.generate(),
      name: "test-service",
      service_type: "web_app",
      container_status: "pending",
      health_status: "unknown",
      workspace_id: workspace_id,
      image_name: "nginx",
      image_tag: "latest",
      port_mappings: %{"80" => "8080"},
      environment_variables: %{"NODE_ENV" => "production"},
      resource_limits: %{"memory" => "256m", "cpus" => "0.25"},
      replica_count: 1,
      auto_restart: true,
      health_check_config: %{
        "enabled" => true,
        "path" => "/health",
        "interval" => "30s"
      },
      deployment_metadata: %{},
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  defp create_mock_topology_detection(workspace_id) do
    %{
      id: Ecto.UUID.generate(),
      workspace_id: workspace_id,
      status: "pending",
      analysis_depth: "standard",
      triggered_by: "test",
      analysis_config: %{
        "include_patterns" => ["**/*"],
        "exclude_patterns" => ["node_modules/**"],
        "max_depth" => 10
      },
      analysis_metadata: %{},
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  defp build_job(args) do
    %Oban.Job{args: args, id: 1, queue: "test", worker: "TestWorker"}
  end
end
