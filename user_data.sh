#!/bin/bash

# Atualiza o sistema e pacotes
sudo apt-get update -y
sudo apt-get upgrade -y

# Instala dependências
sudo apt-get install -y docker.io
sudo apt-get install -y mysql-client
sudo apt install -y nfs-common
sudo apt-get -y install git binutils rustc cargo pkg-config libssl-dev
sudo git clone https://github.com/aws/efs-utils
sudo cd efs-utils
sudo ./build-deb.sh
sudo apt-get -y install ./build/amazon-efs-utils*deb

# Cria o diretório efs 
sudo mkdir -p /mnt/efs

#  Monta um sistema de arquivos da Amazon Elastic File System (EFS) no Linux
sudo mount -t efs -o tls <ID_EFS>:/ /mnt/efs

# Instalar docker-compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER
newgrp docker

# Configura o diretório para o projeto WordPress
PROJECT_DIR=/home/ubuntu/wordpress
sudo mkdir -p $PROJECT_DIR
sudo chown -R $USER:$USER $PROJECT_DIR
cd $PROJECT_DIR

# Cria o arquivo docker-compose.yml
sudo tee docker-compose.yml > /dev/null <<EOL

services:
  wordpress:
    image: wordpress:latest
    container_name: wordpress
    ports:
      - "80:80"
    environment:
      WORDPRESS_DB_HOST: <ENDPOINT_RDS>:3306
      WORDPRESS_DB_USER: <USER_DB>
      WORDPRESS_DB_PASSWORD: <SENHA_DB>
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - /mnt/efs:/var/www/html

EOL

# Inicia o Docker Compose
docker-compose up -d

# Aguarda o container WordPress estar ativo
echo "Aguardando o container WordPress iniciar..."
until sudo docker ps | grep -q "Up.*wordpress"; do
  echo "Verificando containers em execução..."
  sudo docker ps
  sleep 5
done
echo "Container WordPress iniciado!"


# Adiciona o arquivo healthcheck.php no container WordPress
echo "Criando o arquivo healthcheck.php no container WordPress..."
sudo docker exec -i wordpress bash -c "cat <<EOF > /var/www/html/healthcheck.php
<?php
http_response_code(200);
header('Content-Type: application/json');
echo json_encode([\"status\" => \"OK\", \"message\" => \"Health check passed\"]);
exit;
?>
EOF"

# Confirma a criação do arquivo
if docker exec -i wordpress ls /var/www/html/healthcheck.php > /dev/null 2>&1; then
  echo "Arquivo healthcheck.php criado com sucesso!"
else
  echo "Falha ao criar o arquivo healthcheck.php."
fi
