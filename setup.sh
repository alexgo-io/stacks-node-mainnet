#!/bin/bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd $DIR

export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get dist-upgrade -y && apt-get autoremove -y && apt-get autoclean

apt-get install -y dstat vim zip unzip ca-certificates curl git gawk jq tmux screen traceroute dnsutils iftop ufw net-tools

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
  if [ $(grep ubuntu /etc/os-release | wc -l) -gt 0 ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  else
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  fi
  chmod a+r /etc/apt/keyrings/docker.gpg
  apt-get update && apt-get install -y docker-ce
  ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
  echo '{
    "log-driver": "json-file",
    "log-opts": {
      "max-size": "1024m"
    },
    "live-restore": true
  }' > /etc/docker/daemon.json
  systemctl enable --now docker
  systemctl restart docker
fi

if [ ! -e "./wait" ]; then
  wget -qO ./wait https://github.com/ufoscout/docker-compose-wait/releases/download/2.12.1/wait
  chmod +x ./wait
fi
