#!/bin/bash

#Utils
sudo apt-get install unzip

#Download Consul
CONSUL_VERSION="1.7.2"
curl --silent --remote-name https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip

#Install Consul
unzip consul_${CONSUL_VERSION}_linux_amd64.zip
sudo chown root:root consul
sudo mv consul /usr/local/bin/
consul -autocomplete-install
complete -C /usr/local/bin/consul consul

#Create Consul User
sudo useradd --system --home /etc/consul.d --shell /bin/false consul
sudo mkdir --parents /opt/consul
sudo chown --recursive consul:consul /opt/consul

#Create Systemd Config
sudo cat << EOF > /etc/systemd/system/consul.service
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/consul.hcl

[Service]
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/usr/local/bin/consul reload
KillMode=process
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

#Create config dir
sudo mkdir --parents /etc/consul.d
sudo touch /etc/consul.d/consul.hcl
sudo chown --recursive consul:consul /etc/consul.d
sudo chmod 640 /etc/consul.d/consul.hcl

cat << EOF > /etc/consul.d/consul.hcl
datacenter = "dc1"
data_dir = "/opt/consul"

ui = true
EOF

cat << EOF > /etc/consul.d/server.hcl
server = true
bootstrap_expect = 1

client_addr = "0.0.0.0"
retry_join = ["provider=aws tag_key=Env tag_value=consul"]
EOF

#Enable the service
sudo systemctl enable consul
sudo service consul start
sudo service consul status

################  Consul-Terraform-Sync  ###########################

#Download Consul-Terraform-Sync
CONSUL_TF_SYNC_VERSION="0.1.0-techpreview1"
curl --silent --remote-name https://releases.hashicorp.com/consul-terraform-sync/${CONSUL_TF_SYNC_VERSION}/consul-terraform-sync_${CONSUL_TF_SYNC_VERSION}_linux_amd64.zip

#Install Consul-Terraform-Sync
sudo apt install unzip
unzip consul-terraform-sync_${CONSUL_TF_SYNC_VERSION}_linux_amd64.zip
sudo chown root:root consul-terraform-sync
sudo mv consul-terraform-sync /usr/local/bin/

#Create config dir
sudo mkdir --parents /etc/consul-tf-sync.d
sudo touch /etc/consul-tf-sync.d/consul-tf-sync.hcl
sudo chown --recursive consul:consul /etc/consul-tf-sync.d
sudo chmod 640 /etc/consul-tf-sync.d/consul-tf-sync.hcl

cat << EOF > /tmp/consul-tf-sync.hcl
driver "terraform" {
  log = true
  required_providers {
    bigip = {
      source = "F5Networks/bigip"
    }
  }
}
consul {
  address = "0.0.0.0:8500"
}

provider "bigip" {
  address  = ""
  username = ""
  password = ""
}

task {
  name = "AS3"
  description = "Create AS3 Applications"
  source = "arielazem/app-consul-sync-nia/bigip"
  providers = ["bigip"]
  services = ["nginx"]
}
EOF
sudo cp /tmp/consul-tf-sync.hcl /etc/consul-tf-sync.d/consul-tf-sync.hcl

#Create Systemd Config
cat << EOF > /tmp/consul-tf-sync.service
[Unit]
Description="HashiCorp Consul Terraform Sync"
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul-tf-sync.d/consul-tf-sync.hcl

[Service]
User=consul
Group=consul
ExecStart=/usr/local/bin/consul-terraform-sync -config-dir /etc/consul-tf-sync.d/
KillMode=process
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
sudo cp /tmp/consul-tf-sync.service /etc/systemd/system/consul-tf-sync.service