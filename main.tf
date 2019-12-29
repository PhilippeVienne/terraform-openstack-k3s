provider "openstack" {}

variable flavor {
  type = string
  default = "s1-2"
}

variable "ssh_key" {
  type = string
  description = "Your public ssh key (used to connect to server)"
}

variable "base_image" {
  default = "Ubuntu 18.04"
  description = "Image to use on the server"
}

data "openstack_compute_flavor_v2" "small" {
  name = var.flavor
}

data "openstack_images_image_v2" "ubuntu" {
  name = "Ubuntu 18.04"
  most_recent = true
}

resource "openstack_compute_keypair_v2" "ssh_key" {
  name = "k3s-${filemd5(var.ssh_key)}"
  public_key = file(var.ssh_key)
}

resource "openstack_compute_instance_v2" "k3s-instance" {
  name = "k3s-instance"
  image_id = data.openstack_images_image_v2.ubuntu.id
  flavor_id = data.openstack_compute_flavor_v2.small.flavor_id
  key_pair = openstack_compute_keypair_v2.ssh_key.name
  security_groups = [
    "default"]
  network {
    access_network = true
    name = "Ext-Net"
  }
  connection {
    host = self.access_ip_v4
    user = "ubuntu"
  }
  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC=\"server -i ${openstack_compute_instance_v2.k3s-instance.access_ip_v4}\" sh -"
    ]
  }
}

data "external" "token" {
  depends_on = [
    openstack_compute_instance_v2.k3s-instance
  ]
  program = ["/bin/bash", "${path.module}/kubeconfig.sh"]
  query = {
    controller = openstack_compute_instance_v2.k3s-instance.access_ip_v4
  }
}

output "cluster_ca" {
  value = base64decode(yamldecode(data.external.token.result.kubeconfig)["clusters"][0]["cluster"]["certificate-authority-data"])
}

output "cluster_username" {
  value = yamldecode(data.external.token.result.kubeconfig)["users"][0]["user"]["username"]
}
output "cluster_password" {
  value = yamldecode(data.external.token.result.kubeconfig)["users"][0]["user"]["password"]
  sensitive = true
}
output "cluster_host" {
  value = "https://${openstack_compute_instance_v2.k3s-instance.access_ip_v4}:6443"
}
output "cluster_kubeconfig" {
  value = replace(data.external.token.result.kubeconfig, "https://127.0.0.1:6443", "https://${openstack_compute_instance_v2.k3s-instance.access_ip_v4}:6443")
  sensitive = true
}
