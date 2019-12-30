data "google_client_config" "current" {}
data "google_compute_zones" "available" {}
data "google_project" "project" {}
# Let's not hardcode this, rather discovery or pass as a variable.
data "google_compute_network" "my-network" {
 name = "vpcnet-shared-prod-01"
}

data "template_file" "data_firstboot" {
    template = "${file("${path.module}/provisioning.tpl")}"
    vars = {
      foo = "bar"
    }
}

locals {
  # No Adtech here, instead lets generalize as a prefix? That's not a bad idea.
  deployment_name = "${var.cluster_name == "" ? "adtech-k8s-${var.env}" : "adtech-k8s-${var.cluster_name}-${var.env}"}"
}

### Load Balancer ####

resource "google_compute_forwarding_rule" "k8s-lb" {
  name = "${local.deployment_name}"

  load_balancing_scheme = "INTERNAL"
  backend_service       = "${google_compute_region_backend_service.backend.self_link}"
  all_ports             = true
  ip_protocol           = "TCP"
  network    = "projects/shared-vpc-admin/global/networks/vpcnet-shared-prod-01"
  subnetwork = "projects/shared-vpc-admin/regions/us-central1/subnetworks/prod-us-central1-01"
}

resource "google_compute_region_backend_service" "backend" {
  name = "${local.deployment_name}"
  region                = "us-central1"
  protocol              = "TCP"
  load_balancing_scheme = "INTERNAL"

  backend {
    group = "${google_compute_instance_group_manager.adtech-k8s-kubelets.instance_group}"
  }

  health_checks         = ["${google_compute_health_check.ssh.self_link}"]
}

resource "google_compute_health_check" "ssh" {
  name               = "${local.deployment_name}"
  check_interval_sec = 60
  timeout_sec        = 30
  tcp_health_check {
    port = "22"
  }
}
###### / Load Balancer #####


# Disable on destroys
data "external" "join_key_fetcher" {
  program = ["bash", "${path.module}/discover-join-token.sh"]

  query = {
    master = "${google_compute_instance.k8s_master.network_interface.0.network_ip}"
  }
}
resource "google_compute_instance" "k8s_master" {
  name         = "${var.cluster_name == "" ? "adtech-k8s-master-${var.env}" : "adtech-k8s-${var.cluster_name}-master-${var.env}"}"
  machine_type = "n1-standard-4"
  zone         = "us-central1-a"

  tags = ["monitor"]

  boot_disk {
    initialize_params {
      #TODO: Propagate as variable, set good default
      image = "centos-7-v20190729"
      #TODO: Propagate as variable
      size = 120
    }
  }

  network_interface {
    #TODO: Propagate a variable for the subnet
    network    = "projects/shared-vpc-admin/global/networks/vpcnet-shared-prod-01"
    subnetwork = "projects/shared-vpc-admin/regions/us-central1/subnetworks/prod-us-central1-01"
  }

  metadata = {
    profile = "kubernetes"
  }

  metadata_startup_script = "${data.template_file.data_firstboot.rendered}"
  lifecycle {
    ignore_changes = [ "metadata_startup_script" ]
  }
  service_account {
    email  = "${var.svc_account}"
    scopes = "${var.svc_scopes}"
  }
}

resource "google_compute_instance_template" "adtech-k8s-workers" {
  name_prefix  = "${var.cluster_name == "" ? "adtech-k8s-${var.env}" : "adtech-k8s-${var.cluster_name}-${var.env}"}"
  # Make this a variable, please
  machine_type = "n1-standard-4"

  disk {
    source_image = "centos-7-v20190729"
    auto_delete  = true
    boot         = true
    disk_size_gb = 120
  }

  network_interface {
    network    = "projects/shared-vpc-admin/global/networks/vpcnet-shared-prod-01"
    subnetwork = "projects/shared-vpc-admin/regions/us-central1/subnetworks/prod-us-central1-01"
  }

  lifecycle {
    create_before_destroy = true
  }

  metadata = {
    worker = "true"
    profile = "kubernetes"
    master = "${google_compute_instance.k8s_master.network_interface.0.network_ip}"
    join_key = "${data.external.join_key_fetcher.result.join_key}"
    ca_cert = "${data.external.join_key_fetcher.result.ca_cert}"
  }

  metadata_startup_script = "${data.template_file.data_firstboot.rendered}"

  service_account {
    email  = "${var.svc_account}"
    scopes = "${var.svc_scopes}"
  }
}
resource "google_compute_instance_group_manager" "adtech-k8s-kubelets" {
  #TODO: Define this name interpolation somewhere and DRY
  # More prefix magic here. Airflow nodes should have this right
  name               = "${var.cluster_name == "" ? "adtech-k8s-kubelets-${var.env}" : "adtech-k8s-kubelets-${var.cluster_name}-${var.env}"}"
  instance_template  = "${google_compute_instance_template.adtech-k8s-workers.self_link}"
  base_instance_name = "${var.cluster_name == "" ? "adtech-k8s-kubelets-${var.env}" : "adtech-k8s-kubelets-${var.cluster_name}-${var.env}"}"
  zone               = "us-central1-f"
  target_size        = "${var.node_count != "" ? "${var.node_count}" : 2}"
}
