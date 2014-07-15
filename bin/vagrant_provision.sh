#!/bin/bash

set -e

INSTALL_DIR=/home/vagrant

# Check for git submodules
if [ "$(ls -A $INSTALL_DIR/kitsune/vendor/src/*/*)" ]; then
    echo "Your submodules are up to date!"
else
    echo "You haven't updated your submodules!"
    echo "Run: 'git submodule update --init --recursive' to fix the problem."
    echo "Exiting..."
    false
fi

cd $INSTALL_DIR/kitsune

# Install package for add-apt-repository
apt-get install -y software-properties-common

# ElasticSearch key add/setup
curl http://packages.elasticsearch.org/GPG-KEY-elasticsearch | apt-key add -
echo "deb http://packages.elasticsearch.org/elasticsearch/0.90/debian stable main" \
        > /etc/apt/sources.list.d/elasticsearch.list

# Add the needed repositories for Node/Redis
add-apt-repository ppa:chris-lea/node.js
add-apt-repository ppa:chris-lea/redis-server
apt-get update

# Set default password for MariaDB
export DEBIAN_FRONTEND=noninteractive
debconf-set-selections <<< 'mariadb-server-5.5 mysql-server/root_password password rootpass'
debconf-set-selections <<< 'mariadb-server-5.5 mysql-server/root_password_again password rootpass'

# Install services and their dependencies
# Services: Sphinx, MariaDB, ElasticSearch, Redis, and Memcached
apt-get install -y sphinx-common libapache2-mod-wsgi python-pip libmysqlclient-dev \
                   libxml2-dev libxslt1-dev zlib1g-dev libjpeg-dev python-dev libssl-dev \
                   openjdk-7-jre-headless mariadb-server-5.5 nodejs elasticsearch redis-server \
                   memcached git


# Setup the virtualenv and start using it
pip install virtualenv
virtualenv $INSTALL_DIR/virtualenv
chown -R vagrant $INSTALL_DIR/virtualenv
source $INSTALL_DIR/virtualenv/bin/activate

pip install -r $INSTALL_DIR/kitsune/requirements/compiled.txt 
pip install nose-progressive==1.5.0
pip install peep==1.2
pip install requests

# Copy configurations for kitsune and mysql
# MySQL Default User: root
# MySQL Default Pass: rootpass
cp $INSTALL_DIR/kitsune/configs/vagrant/settings_local.py \
   $INSTALL_DIR/kitsune/kitsune/settings_local.py

cp $INSTALL_DIR/kitsune/configs/vagrant/my.cnf /etc/mysql/my.cnf

# Fix default port to match kitsune
sed -ie 's/^port 6379$/port 6383/' /etc/redis/redis.conf
service redis-server restart

# Create the kitsune database
mysql -e 'CREATE DATABASE kitsune CHARACTER SET utf8 COLLATE utf8_unicode_ci'
mysql -e "GRANT ALL ON kitsune.* TO kitsune@localhost IDENTIFIED BY 'password'"

# Install npm and included packages (lessc is the one we need of these)
npm install 

# Fixes for Rachel specifically.
export DJANGO_SETTINGS_MODULE="kitsune.settings"
python $INSTALL_DIR/kitsune/bin/peepify/peepify.py --target-dir \
        $INSTALL_DIR/kitsune/vendor/src/ --tarballs-dir tarballs
peep install -r requirements.txt
bash $INSTALL_DIR/kitsune/bin/virtualize_vendor.sh
cp $INSTALL_DIR/kitsune/bin/kitsune.pth $INSTALL_DIR/kitsune/vendor/
cp $INSTALL_DIR/kitsune/bin/manage.py $INSTALL_DIR/kitsune/
cp -r $INSTALL_DIR/kitsune/bin/json \
      $INSTALL_DIR/virtualenv/local/lib/python2.7/site-packages/product_details/

