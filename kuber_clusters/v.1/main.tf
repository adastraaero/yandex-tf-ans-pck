terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.60.0"
    }
  }
}

provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}

resource "yandex_kubernetes_cluster" "k8s-cluster" {
  name       = "k8s-cluster"
  network_id = var.network_id

  master {
    version = "1.21"
    zonal {
      zone      = var.zone
      subnet_id = var.subnet_id
    }
    public_ip = true
  }

  service_account_id      = var.service_account_id
  node_service_account_id = var.service_account_id

  release_channel         = "RAPID"
  network_policy_provider = "CALICO"
}

resource "yandex_kubernetes_node_group" "k8s-node" {
  cluster_id = yandex_kubernetes_cluster.k8s-cluster.id
  version    = "1.21"
  name       = "k8s-node"

  instance_template {

    resources {
      cores  = var.cores
      memory = var.memory
    }

    network_interface {
      subnet_ids = ["e9bc19cu3vl8fknf5mn6"]
      nat        = true
    }


    boot_disk {
      type = "network-ssd"
      size = var.size
    }

    metadata = {
      ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    }
  }

  scale_policy {
    #Ключ fixed_scale определяет группу ВМ фиксированного размера. Размер группы определяется в ключе size
    fixed_scale {
      size = 2
    }
  }
}
