locals {
  project_details = {
    id = "my-project-id"
    region = "us-central1"
  }
}

resource "google_cloud_run_v2_service" "gemma_app" {
  provider = google-beta
  project  = locals.project_details.id
  name     = "gemma-app"
  location = locals.project_details.region
  ingress             = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  deletion_protection = false

  template {
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    service_account = "sa-account@${locals.project_details.id}.iam.gserviceaccount.com"
    timeout = "600s"
    max_instance_request_concurrency = 4
    gpu_zonal_redundancy_disabled = true
    scaling {
      min_instance_count = 1
      max_instance_count = 1
    }
    node_selector {
      accelerator = "nvidia-rtx-pro-6000"
    }
    containers {
      image = "us-docker.pkg.dev/vertex-ai/vertex-vision-model-garden-dockers/pytorch-vllm-serve:gemma4"
      command = ["vllm"]
      args = [
        "serve",
        "google/gemma-4-E2B-it",
        "--enable-chunked-prefill",
        "--enable-prefix-caching",
        "--generation-config=auto",
        "--enable-auto-tool-choice",
        "--tool-call-parser=gemma4",
        "--reasoning-parser=gemma4",
        "--dtype=bfloat16",
        "--max-num-seqs=4",
        "--gpu-memory-utilization=0.95",
        "--tensor-parallel-size=1",
        "--port=8080",
        "--host=0.0.0.0"
      ]
      ports {
        container_port = 8080
      }
      resources {
        cpu_idle           = false
        startup_cpu_boost  = true
        limits = {
          cpu              = "20"
          memory           = "80Gi"
          "nvidia.com/gpu" = "1"
        }
      }

      # vLLM does not provide /health endpoint.
      # Use a TCP probe, which only checks whether port 8080 is accepting connections.
      startup_probe {
        initial_delay_seconds = 240
        timeout_seconds       = 5
        period_seconds        = 10
        failure_threshold     = 12
        tcp_socket {
          port = 8080
        }
      }
    }
  }
}


resource "google_cloud_run_v2_service_iam_member" "other_app_invokes_gemma" {
  project  = google_cloud_run_v2_service.gemma_app.project
  location = google_cloud_run_v2_service.gemma_app.location
  name     = google_cloud_run_v2_service.gemma_app.name
  role = "roles/run.invoker"
  member = "serviceAccount:sa-account@${locals.project_details.id}.iam.gserviceaccount.com"
}

resource "google_cloud_run_v2_service_iam_member" "google_group_invokers" {
  project  = google_cloud_run_v2_service.gemma_app.project
  location = google_cloud_run_v2_service.gemma_app.location
  name     = google_cloud_run_v2_service.gemma_app.name
  role = "roles/run.invoker"
  member = "group:my-google-group@domain.com"
}
