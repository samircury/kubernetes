module "k8s-int" {
  source = "../modules/kubernetes"
  env = "int"
  node_count = 4
}

