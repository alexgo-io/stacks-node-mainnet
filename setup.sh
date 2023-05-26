#!/bin/bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd $DIR

export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get dist-upgrade -y && apt-get autoremove -y && apt-get autoclean

apt-get install -y dstat vim iftop direnv zip unzip ca-certificates curl git gnupg lsb-release dirmngr gpg gawk jq tmux screen traceroute dnsutils iftop ufw

echo "Port 20022" >> /etc/ssh/sshd_config
echo "UseDNS no" >> /etc/ssh/sshd_config
systemctl restart ssh
ufw allow 3999/tcp
ufw allow 20443/tcp
ufw allow 20444/tcp
ufw limit 20022
echo y | ufw enable

# docker
if [ ! -e /usr/local/bin/docker-compose ]; then
  mkdir -m 0755 -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update && apt-get install -y docker-ce
  echo '{
  "log-driver": "json-file",
  "log-opts": {
      "max-size": "1024m"
  },
  "live-restore": true
  }' > /etc/docker/daemon.json
  systemctl enable --now docker
  systemctl restart docker
  curl -SL https://github.com/docker/compose/releases/download/v2.18.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
fi

if [ ! -e "./wait" ]; then
  wget -qO ./wait https://github.com/ufoscout/docker-compose-wait/releases/download/2.12.0/wait
  chmod +x ./wait
fi
