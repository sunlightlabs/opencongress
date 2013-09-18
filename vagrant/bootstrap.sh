#!/usr/bin/env bash
echo "
=========================================================================
             Bootstrapping the OpenCongress environment.

                            ☕ ☕ ☕ ☕ ☕ ☕

    This script will:
     - Install system dependencies
     - Install RVM with ruby 1.9.3
     - Install custom builds of QT and wkhtmltopdf for headless systems
     - Set up the system path

                            ☕ ☕ ☕ ☕ ☕ ☕

Put your feet up and grab a cup of coffee or six, This will take a while.
=========================================================================
"

apt-get update
apt-get remove apparmor -y
apt-get install build-essential openssl xorg-dev libssl-dev libxrender-dev git-core postgresql-9.1 curl libxml2-dev libxslt-dev libmagick-dev libmagickwand-dev imagemagick libmysqlclient-dev libpq-dev ruby-dev -y

# Install RVM
\curl -L https://get.rvm.io | bash -s stable --ruby=1.9.3

# Custom source build of qt/wkhtmltopdf for faxing
if ! [[ -s /opt/wkhtmltopdf/bin/wkhtmltopdf ]] ; then
    export WORKING_DIR=$HOME/workingdir
    export SCRIPT_DIR=/vagrant/vagrant

    mkdir -p $WORKING_DIR
    cd $WORKING_DIR

    # get repos
    git clone git://github.com/antialize/wkhtmltopdf.git wkhtmltopdf
    git clone git://gitorious.org/~antialize/qt/antializes-qt.git wkhtmltopdf-qt

    # make/install qt
    cd wkhtmltopdf-qt
    git checkout 4.8.4
    QTDIR=. ./bin/syncqt
    ./configure -nomake tools,examples,demos,docs,translations -opensource -confirm-license -prefix '/opt/qt'
    export PATH=/opt/qt/bin:$PATH
    make -j2 && make install

    # make/install wkhtmltopdf
    cd $WORKING_DIR/wkhtmltopdf
    /opt/qt/bin/qmake
    INSTALL_ROOT=/opt/wkhtmltopdf make && INSTALL_ROOT=/opt/wkhtmltopdf make install
fi

# source rvm & add opt/wkhtmltopdf/bin to $PATH in .bashrc
echo 'if [[ -s /usr/local/rvm/scripts/rvm ]] ; then source /usr/local/rvm/scripts/rvm; fi; export PATH=/opt/wkhtmltopdf/bin:$PATH' > /etc/profile.d/vagrantup.sh

