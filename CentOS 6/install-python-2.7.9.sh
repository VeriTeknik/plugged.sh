#!/bin/bash

### INSTALL Python 2.7 on CentOS 6.x ###

yum -y update
yum groupinstall -y 'development tools'

# Install requirements
yum install -y zlib-dev openssl-devel sqlite-devel bzip2-devel xz-libs

# Get Python 2.7.9. and compile it
wget https://www.python.org/ftp/python/2.7.9/Python-2.7.9.tar.xz

xz -d Python-2.7.9.tar.xz
tar -xvf Python-2.7.9.tar

cd Python-2.7.9
./configure --prefix=/usr/local
make
make altinstall
cd ..

# INSTALL setuptools For the New Python
wget --no-check-certificate https://pypi.python.org/packages/source/s/setuptools/setuptools-1.4.2.tar.gz
tar -xvf setuptools-1.4.2.tar.gz
cd setuptools-1.4.2
python2.7 setup.py install
cd ..

# Install PIP for the New Python
curl https://raw.githubusercontent.com/pypa/pip/master/contrib/get-pip.py | python2.7 -

# Install virtualenv
pip install virtualenv

# Delete downloaded files
rm -rf Python-2.7.9 Python-2.7.9.tar setuptools-1.4.2 setuptools-1.4.2.tar.gz