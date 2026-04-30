packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.1.0"
    }
  }
}

variable "base_image_path" {
  type = string
}

variable "headscale_deb_path" {
  type = string
}

variable "headscale_config_path" {
  type = string
}

variable "user_data_path" {
  type = string
}

variable "meta_data_path" {
  type = string
}

variable "output_directory" {
  type = string
}

variable "output_image_name" {
  type = string
}

variable "ssh_username" {
  type = string
}

variable "ssh_private_key_file" {
  type = string
}

variable "qemu_binary" {
  type = string
}

source "qemu" "headscale" {
  accelerator           = "kvm"
  boot_wait             = "5s"
  cd_files              = [var.user_data_path, var.meta_data_path]
  cd_label              = "CIDATA"
  communicator          = "ssh"
  disk_image            = true
  disk_interface        = "virtio"
  format                = "qcow2"
  headless              = true
  host_port_max         = 2299
  host_port_min         = 2222
  iso_checksum          = "none"
  iso_url               = var.base_image_path
  memory                = 2048
  net_device            = "virtio-net"
  output_directory      = var.output_directory
  qemu_binary           = var.qemu_binary
  shutdown_command      = "sudo shutdown -P now"
  ssh_private_key_file  = var.ssh_private_key_file
  ssh_timeout           = "30m"
  ssh_username          = var.ssh_username
  use_backing_file      = false
  vm_name               = var.output_image_name
}

build {
  sources = ["source.qemu.headscale"]

  provisioner "file" {
    destination = "/tmp/headscale.deb"
    source      = var.headscale_deb_path
  }

  provisioner "file" {
    destination = "/tmp/config.yaml"
    source      = var.headscale_config_path
  }

  provisioner "shell" {
    inline = [
      "sudo cloud-init status --wait",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y /tmp/headscale.deb",
      "sudo install -d /etc/headscale",
      "sudo cp /tmp/config.yaml /etc/headscale/config.yaml",
      "sudo chown headscale:headscale /etc/headscale/config.yaml",
      "sudo install -d -o headscale -g headscale /var/run/headscale",
      "sudo headscale configtest",
      "sudo systemctl enable headscale",
      "sudo apt-get clean",
      "sudo cloud-init clean --logs --seed || true",
      "sudo rm -f /tmp/headscale.deb /tmp/config.yaml",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id"
    ]
  }
}
