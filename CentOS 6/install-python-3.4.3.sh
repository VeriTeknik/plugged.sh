#!/bin/bash

### INSTALL Python 3.4.3 on CentOS 6.x ###

yum -y update
yum groupinstall -y 'development tools'

# Install requirements
yum install -y zlib-dev openssl-devel sqlite-devel bzip2-devel xz-libs

# Get Python 2.7.9. and compile it
wget https://www.python.org/ftp/python/3.4.3/Python-3.4.3.tar.xz

xz -d Python-3.4.3.tar.xz
tar -xvf Python-3.4.3.tar

cd Python-3.4.3
./configure --prefix=/usr/local
make && make altinstall
cd ..

# INSTALL setuptools For the New Python
wget --no-check-certificate https://pypi.python.org/packages/source/s/setuptools/setuptools-1.4.2.tar.gz
tar -xvf setuptools-1.4.2.tar.gz
cd setuptools-1.4.2
python3.4 setup.py install
cd ..

# Install PIP for the New Python
curl https://raw.githubusercontent.com/pypa/pip/master/contrib/get-pip.py | python3.4 -

# Install virtualenv
pip install virtualenv

# Delete downloaded files
rm -rf Python-3.4.3 Python-3.4.3.tar setuptools-1.4.2 setup-tools-1.4.2.tar.gz