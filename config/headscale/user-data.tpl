#cloud-config
users:
  - default
  - name: __PACKER_SSH_USERNAME__
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - __PACKER_SSH_PUBLIC_KEY__
ssh_pwauth: false
