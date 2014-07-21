# OpenCongress
A Ruby on Rails application for gathering, displaying and tracking information about the United States Congress


## Getting started with our code

### Vagrant

By far, the fastest and easiest way to get started with OpenCongress is by downloading and installing our vagrant box.

You can get vagrant at <http://vagrantup.com>

Once you've installed vagrant, just run:

    vagrant box add opencongress http://vagrant.sunlightfoundation.com/opencongress/opencongress.box
    vagrant init opencongress
    vagrant up

Then connect to your new VM:

    vagrant ssh

From here, you can skip down to 'gem install bundler'

### Running locally

Start by installing all the packages required by OpenCongress.  The main
dependencies are postgres and ImageMagick; OpenCongress will not run on
mysql or sqlite.  The following commands are suggestions, but ultimately
you'll need to get postgres running to be able to run the app.  We are
currently running postgres 9.1 in production.

For Ubuntu 14.04 (Trusty):

```bash
# install needed libraries
sudo apt-get install postgresql postgresql-server-dev-9.3 libxml2-dev \
                     libxslt-dev libcurl4-openssl-dev libmysqlclient-dev \
                     imagemagick libssl-dev libreadline-dev
```


For Mac OS X, start by installing [Homebrew](http://mxcl.github.io/homebrew/),
then run:

    brew install postgresql postgresql-server ImageMagick md5sha1sum wget wkhtmltopdf ghostscript

Follow the instructions after the packages install for initializing your database

---

Install Ruby and the bundle of dependencies:

```bash
# install rbenv (see: https://github.com/sstephenson/rbenv#basic-github-checkout)
git clone https://github.com/sstephenson/rbenv.git ~/.rbenv
git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile
source ~/.bash_profile

# install ruby
rbenv install 1.9.3-p484

gem install bundler
rbenv rehash            # this puts the "bundle" command in your PATH
bundle install
```

__Note for OS X:__ You may need to specify additional compile options
for your gems. Try: `ARCHFLAGS="-arch x86_64" bundle install`

---

Generate your settings files. First change into the `opencongress` directory and then:

    cp config/api_keys.yml.example config/api_keys.yml
    cp config/application_settings.yml.example config/application_settings.yml
    cp config/database.yml.example config/database.yml

Be sure to fill out these new files with the relevant details before proceeding.


### Database setup

Running the following commands will create an 'opencongress' user and
empty databases for the three environments (test, development,
production).  The migration command will populate the development
database with an empty schema.

```bash
# make a postgres superuser for opencongress
sudo -u postgres createuser opencongress -sP

# Make sure to put your password in config/database.yml!

# create the postgres database
sudo -u postgres createdb opencongress_development -O opencongress

rake db:init
rake db:migrate
```

### Legislative Data (optional)

To import legislative data into your database, run the following command:

    rake update

This will download data files from [The United States project](http://github.com/unitedstates) and
import them into your database.  The default location for storage of
the data files is `/tmp/opencongress_data` but you can change this by
editing `config/application_settings.yml`.  This task will import ALL
of the data for the current session of Congress: it will take a long
time and occupy a LOT of space on your filesystem!  Keep this in mind
before importing the data!

### Starting the server

To start the webserver:

    rails s

## Contributing

We are currently focused on getting the code up to speed--more friendly for developers and better covered by tests. If you would like to help out, please be sure any new code is tested appropriately under RSpec, Capybara and/or Cucumber and send pull requests to this github repo. We'd especially love help in improving test coverage, but all pull requests are welcome. See the [Sunlight Community page](http://sunlightfoundation.com/api/community/) for specific asks related to this project.

## License

OpenCongress is distributed under the [GPLv3](http://opensource.org/licenses/GPL-3.0).
