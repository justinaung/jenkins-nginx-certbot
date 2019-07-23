variable "digitalocean_token" {}
variable "digitalocean_ssh_fingerprint" {}
variable "jenkins_ssh_a_name" {}
variable "jenkins_ssh_name" {}
variable "domain_name" {}

variable "cloudflare_email" {}
variable "cloudflare_token" {}


provider "digitalocean" {
  token = "${var.digitalocean_token}"
}

provider "cloudflare" {
  email = "${var.cloudflare_email}" 
  token = "${var.cloudflare_token}"
}

resource "digitalocean_droplet" "jenkins" {
  image = "ubuntu-18-04-x64"
  name = "jenkins"
  region = "sgp1"
  size = "s-1vcpu-2gb"
  ssh_keys =["${var.digitalocean_ssh_fingerprint}"]

  provisioner "local-exec" {
    command = "sed -i -e 's/DEPLOYING_HOST=.*/DEPLOYING_HOST=${self.ipv4_address}/g' .env"
  }

  provisioner "local-exec" {
    command = "ssh-keygen -R ${self.ipv4_address}"
    when    = "destroy"
  }

  provisioner "local-exec" {
    command = "ssh-keygen -R ${var.jenkins_ssh_name}"
    when    = "destroy"
  }
}

resource "cloudflare_record" "jenkins_ssh" {
  domain = "${var.domain_name}"  
  name = "${var.jenkins_ssh_a_name}"
  value = "${digitalocean_droplet.jenkins.ipv4_address}"
  type = "A"
}

resource "cloudflare_record" "jenkins" {
  domain = "${var.domain_name}"
  name = "jenkins"
  value = "${digitalocean_droplet.jenkins.ipv4_address}"
  type = "A"
  proxied = true
}

