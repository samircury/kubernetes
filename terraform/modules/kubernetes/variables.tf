variable "cluster_name" {
  default = ""
}
#TODO: Dedupe this
variable "env" {
  default = "int"
}

variable "environment" {
  default = "int"
}
variable "ansible_branch" {
  default = "master"
}

variable "node_count" {
  default = 2
}
variable "join_key" {
  default = ""
}
variable "ca_cert" {
  default = ""
}

# TODO: reduce these overly broad permissions
variable "svc_account" {
  default = "svc-deploy-mgmt@wmt-customer-tech-adtech.iam.gserviceaccount.com"
}

variable "svc_scopes" {
  default = ["cloud-platform"]
}
