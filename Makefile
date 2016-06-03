#!/usr/bin/make -f
#
# Build website with environment
#
#

WWW_SITE	 = grillcon.dbwebb.se
WWW_LOCAL	 = local.$(WWW_SITE)
SERVER_ADMIN = mos@dbwebb.se # mos@$(WWW_SITE)

GIT_BASE 	= git/grillcon.dbwebb.se
HTDOCS_BASE = $(HOME)/htdocs
LOCAL_HTDOCS = $(HTDOCS_BASE)/$(WWW_SITE)
ROBOTSTXT	 = robots.txt

# Certificates for https
SSL_APACHE_CONF = /etc/letsencrypt/options-ssl-apache.conf
SSL_PEM_BASE 	= /etc/letsencrypt/live/$(WWW_SITE)

# Theme
LESS 		 = theme/style_anax-flat.less
LESS_OPTIONS = --strict-imports --include-path=theme/mos-theme/style/
FONT_AWESOME = theme/mos-theme/style/font-awesome/fonts/

# Colors
NO_COLOR		= \033[0m
TARGET_COLOR	= \033[32;01m
OK_COLOR		= \033[32;01m
ERROR_COLOR		= \033[31;01m
WARN_COLOR		= \033[33;01m
ACTION			= $(TARGET_COLOR)--> 



# target: help        - Displays help.
.PHONY:  help
help:
	@echo "$(ACTION)Displaying help for this Makefile.$(NO_COLOR)"
	@echo "Usage:"
	@echo " make [target] ..."
	@echo "target:"
	@egrep "^# target:" Makefile | sed 's/# target: / /g'



# target: site-build  - Build the site by creating dirs and copying files.
.PHONY: site-build
site-build:
	@echo "$(ACTION)Copy default structure from Anax Flat$(NO_COLOR)"
	rsync -a vendor/mos/anax-flat/htdocs/ htdocs/
	rsync -a vendor/mos/anax-flat/config/ config/
	rsync -a vendor/mos/anax-flat/content/ content/

	@echo "$(ACTION)Copy from CImage$(NO_COLOR)"
	install -d htdocs/cimage
	rsync -a vendor/mos/cimage/webroot/imgd.php htdocs/cimage/imgd.php
	rsync -a vendor/mos/cimage/icc/ htdocs/cimage/icc/

	@echo "$(ACTION)Create the directory for the cache items$(NO_COLOR)"
	install --directory --mode 777 cache/cimage cache/anax



# target: prepare-build - Clear and recreate the build directory.
.PHONY: prepare-build
prepare-build:
	@echo "$(ACTION)Preparing the build directory$(NO_COLOR)"
	rm -rf build
	install -d build/css build/lint



# target: less - Build less stylesheet and update the site with it.
.PHONY: less
less: prepare-build
	@echo "$(ACTION)Compiling LESS stylesheet$(NO_COLOR)"
	lessc $(LESS_OPTIONS) $(LESS) build/css/style.css
	lessc --clean-css $(LESS_OPTIONS) $(LESS) build/css/style.min.css
	cp build/css/style.min.css htdocs/css/style.min.css

	rsync -a $(FONT_AWESOME) htdocs/fonts/



# target: less-lint - Lint the less stylesheet.
.PHONY: less-lint
less-lint: less
	@echo "$(ACTION)Linting LESS/CSS stylesheet$(NO_COLOR)"
	lessc --lint $(LESS_OPTIONS) $(LESS) > build/lint/style.less
	- csslint build/css/style.css > build/lint/style.css
	ls -l build/lint/



# BELOW TO BE CHECKED OR REMOVED


# target: update - Update codebase and publish by clearing the cache.
.PHONY: update
update: codebase-update site-build local-publish-clear



# target: production-publish - Publish latest to the production server.
.PHONY: production-publish
production-publish:
	ssh mos@$(WWW_SITE) -t "cd $(GIT_BASE) && git pull && make update"



# target: update - Publish website to local host.
.PHONY: local-publish
local-publish:
	rsync -av --exclude old --exclude .git --exclude cache --delete "./" $(LOCAL_HTDOCS)
	@[ ! -f $(ROBOTSTXT) ] ||  cp $(ROBOTSTXT) "$(LOCAL_HTDOCS)/htdocs/robots.txt"



# target: local-cache-clear - Clear the cache.
.PHONY: local-cache-clear
local-cache-clear:
	-sudo rm -f $(LOCAL_HTDOCS)/cache/anax/*



#
#
# target: local-publish-clear - Publish website to local host and clear the cache.
.PHONY: local-publish-clear
local-publish-clear: local-cache-clear local-publish



#
# Update codebase
#
.PHONY: codebase-update
codebase-update:
	git pull
	composer update



#
# Update repo with all submodules
#
.PHONY: submodule-init submodule-update
submodule-init:
	git submodule update --init --recursive

submodule-update:
	git pull --recurse-submodules && git submodule foreach git pull origin master



# target: less-update - Build less and update site.
.PHONY: less-update
less-update: less local-publish



# target: less-update-clear - Build less and update site and clear cache.
.PHONY: less-update-clear
less-update-clear: less local-publish-clear






# target: etc-hosts - Create a entry in the /etc/hosts for local access.
.PHONY: etc-hosts
etc-hosts:
	echo "127.0.0.1 $(WWW_LOCAL)" | sudo bash -c 'cat >> /etc/hosts'
	@tail -1 /etc/hosts



# target: create-local-structure - Create needed local directory structure.
.PHONY: create-local-structure
create-local-structure:
	install --directory $(HOME)/htdocs/$(WWW_SITE)/htdocs



# target: ssl-cert-create - One way to create the certificates.
.PHONY: ssl-cert-create
ssl-cert-create:
	cd $(HOME)/git/letsencrypt
	sudo service apache2 stop
	./letsencrypt-auto certonly --standalone -d $(WWW_SITE) -d www.$(WWW_SITE)
	sudo service apache2 start



# target: ssl-cert-update - Update certificates with new expiray date.
.PHONY: ssl-cert-renew
ssl-cert-update:
	cd $(HOME)/git/letsencrypt
	./letsencrypt-auto renew



# target: install-fresh - Do a fresh installation of a new server.
.PHONY: install-fresh
install-fresh: create-local-structure etc-hosts virtual-host update



# target: virtual-host - Create entries for the virtual host http.
.PHONY: virtual-host

define VIRTUAL_HOST_80
Define site $(WWW_SITE)
ServerAdmin $(SERVER_ADMIN)

<VirtualHost *:80>
	ServerName $${site}
	ServerAlias local.$${site}
	ServerAlias do1.$${site}
	ServerAlias do2.$${site}
	DocumentRoot $(HTDOCS_BASE)/$${site}/htdocs

	<Directory />
		Options Indexes FollowSymLinks
		AllowOverride All
		Require all granted
		Order allow,deny
		Allow from all
	</Directory>

	<FilesMatch "\.(jpe?g|png|gif|js|css|svg)$">
		   ExpiresActive On
		   ExpiresDefault "access plus 1 week"
	</FilesMatch>

	ErrorLog  $(HTDOCS_BASE)/$${site}/error.log
	CustomLog $(HTDOCS_BASE)/$${site}/access.log combined
</VirtualHost>
endef
export VIRTUAL_HOST_80

define VIRTUAL_HOST_80_WWW
Define site $(WWW_SITE)
ServerAdmin $(SERVER_ADMIN)

<VirtualHost *:80>
	ServerName www.$${site}
	Redirect "/" "http://$${site}/"
</VirtualHost>
endef
export VIRTUAL_HOST_80_WWW

virtual-host:
	echo "$$VIRTUAL_HOST_80" | sudo bash -c 'cat > /etc/apache2/sites-available/$(WWW_SITE).conf'
	echo "$$VIRTUAL_HOST_80_WWW" | sudo bash -c 'cat > /etc/apache2/sites-available/www.$(WWW_SITE).conf'
	sudo a2ensite $(WWW_SITE) www.$(WWW_SITE)
	sudo a2enmod rewrite
	sudo apachectl configtest
	sudo service apache2 reload



# target: virtual-host-https - Create entries for the virtual host https.
.PHONY: virtual-host-https

define VIRTUAL_HOST_443
Define site $(WWW_SITE)
ServerAdmin $(SERVER_ADMIN)

<VirtualHost *:80>
	ServerName $${site}
	ServerAlias do1.$${site}
	ServerAlias do2.$${site}
	Redirect "/" "https://$${site}/"
</VirtualHost>

<VirtualHost *:443>
	Include $(SSL_APACHE_CONF)
	SSLCertificateFile 		$(SSL_PEM_BASE)/cert.pem
	SSLCertificateKeyFile 	$(SSL_PEM_BASE)/privkey.pem
	SSLCertificateChainFile $(SSL_PEM_BASE)/chain.pem

	ServerName $${site}
	ServerAlias do1.$${site}
	ServerAlias do2.$${site}
	DocumentRoot $(HTDOCS_BASE)/$${site}/htdocs

	<Directory />
		Options Indexes FollowSymLinks
		AllowOverride All
		Require all granted
		Order allow,deny
		Allow from all
	</Directory>

	<FilesMatch "\.(jpe?g|png|gif|js|css|svg)$">
		   ExpiresActive On
		   ExpiresDefault "access plus 1 week"
	</FilesMatch>

	ErrorLog  $(HTDOCS_BASE)/$${site}/error.log
	CustomLog $(HTDOCS_BASE)/$${site}/access.log combined
</VirtualHost>
endef
export VIRTUAL_HOST_443

define VIRTUAL_HOST_443_WWW
Define site $(WWW_SITE)
ServerAdmin $(SERVER_ADMIN)

<VirtualHost *:80>
	ServerName www.$${site}
	Redirect "/" "https://www.$${site}/"
</VirtualHost>

<VirtualHost *:443>
	Include $(SSL_APACHE_CONF)
	SSLCertificateFile 		$(SSL_PEM_BASE)/cert.pem
	SSLCertificateKeyFile 	$(SSL_PEM_BASE)/privkey.pem
	SSLCertificateChainFile $(SSL_PEM_BASE)/chain.pem

	ServerName www.$${site}
	Redirect "/" "https://$${site}/"
</VirtualHost>
endef
export VIRTUAL_HOST_443_WWW

virtual-host-https:
	echo "$$VIRTUAL_HOST_443" | sudo bash -c 'cat > /etc/apache2/sites-available/$(WWW_SITE).conf'
	echo "$$VIRTUAL_HOST_443_WWW" | sudo bash -c 'cat > /etc/apache2/sites-available/www.$(WWW_SITE).conf'
	sudo a2enmod ssl expires
	sudo apachectl configtest
	sudo service apache2 reload
