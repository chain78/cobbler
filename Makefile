#MESSAGESPOT=po/messages.pot

TOP_DIR:=$(shell pwd)

prefix=devinstall
statepath=/tmp/cobbler_settings/$(prefix)

all: clean build

clean:
	-rm -f cobbler*.gz cobbler*.rpm MANIFEST
	-rm -rf cobbler-* dist build rpm-build
	-rm -f *~
	-rm -f cobbler/*.pyc
	-rm -f cobbler/webui/master.py config/modules.conf config/settings config/version
	-rm -f docs/*.1.gz docs/cobbler*.html docs/koan*.html pod2htm*.tmp

manpage:
	pod2man --center="cobbler" --release="" ./docs/cobbler.pod | gzip -c > ./docs/cobbler.1.gz
	pod2html ./docs/cobbler.pod > ./docs/cobbler.html
	pod2man --center="koan" --release="" ./docs/koan.pod | gzip -c > ./docs/koan.1.gz
	pod2html ./docs/koan.pod > ./docs/koan.html
	pod2man --center="cobbler-register" --release="" ./docs/cobbler-register.pod | gzip -c > ./docs/cobbler-register.1.gz
	pod2html ./docs/cobbler-register.pod > ./docs/cobbler-register.html

test:
	make savestate prefix=test
	make rpms
	make install
	make eraseconfig
	/sbin/service cobblerd restart
	-(make nosetests)
	make restorestate prefix=test

nosetests:
	nosetests cobbler/*.py -v | tee test.log

build: manpage updatewui
	python setup_cobbler.py build -f

install: build manpage updatewui
	python setup_cobbler.py install -f

debinstall: manpage updatewui
	python setup.py install -f --root $(DESTDIR)

devinstall:
	make savestate
	make install
	make restorestate

savestate:
	mkdir -p $(statepath)
	cp -a /var/lib/cobbler/config $(statepath)
	cp /etc/cobbler/settings $(statepath)/settings
	cp /etc/cobbler/modules.conf $(statepath)/modules.conf
	cp /etc/httpd/conf.d/cobbler.conf $(statepath)/http.conf
	cp /etc/cobbler/acls.conf $(statepath)/acls.conf
	cp /etc/cobbler/users.conf $(statepath)/users.conf
	cp /etc/cobbler/users.digest $(statepath)/users.digest
	cp /etc/cobbler/dhcp.template $(statepath)/dhcp.template


restorestate:
	cp -a $(statepath)/config /var/lib/cobbler
	cp $(statepath)/settings /etc/cobbler/settings
	cp $(statepath)/modules.conf /etc/cobbler/modules.conf
	cp $(statepath)/users.conf /etc/cobbler/users.conf
	cp $(statepath)/acls.conf /etc/cobbler/acls.conf
	cp $(statepath)/users.digest /etc/cobbler/users.digest
	cp $(statepath)/http.conf /etc/httpd/conf.d/cobbler.conf
	cp $(statepath)/dhcp.template /etc/cobbler/dhcp.template
	find /var/lib/cobbler/triggers | xargs chmod +x
	chown -R apache /var/www/cobbler
	chmod -R +x /var/www/cobbler/web
	chmod -R +x /var/www/cobbler/svc
	rm -rf $(statepath)

completion:
	python mkbash.py

webtest: updatewui devinstall
	make clean
	make updatewui
	make devinstall
	make restartservices

restartservices:
	/sbin/service cobblerd restart
	/sbin/service httpd restart

sdist: clean updatewui
	python setup.py sdist

rpms: clean updatewui manpage sdist
	mkdir -p rpm-build
	cp dist/*.gz rpm-build/
	rpmbuild --define "_topdir %(pwd)/rpm-build" \
	--define "_builddir %{_topdir}" \
	--define "_rpmdir %{_topdir}" \
	--define "_srcrpmdir %{_topdir}" \
	--define "_specdir %{_topdir}" \
	--define '_rpmfilename %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm' \
	--define "_sourcedir  %{_topdir}" \
	-ba cobbler.spec


updatewui:
	cheetah-compile ./webui_templates/master.tmpl
	-(rm ./webui_templates/*.bak)
	mv ./webui_templates/master.py ./cobbler/webui

eraseconfig:
	-rm /var/lib/cobbler/distros*
	-rm /var/lib/cobbler/profiles*
	-rm /var/lib/cobbler/systems*
	-rm /var/lib/cobbler/repos*
	-rm /var/lib/cobbler/networks*
	-rm /var/lib/cobbler/config/distros.d/*
	-rm /var/lib/cobbler/config/images.d/*
	-rm /var/lib/cobbler/config/profiles.d/*
	-rm /var/lib/cobbler/config/systems.d/*
	-rm /var/lib/cobbler/config/repos.d/*
	-rm /var/lib/cobbler/config/networks.d/*

tags:
	find . -type f -name '*.py' | xargs etags -c TAGS
