install:
	for s in wsim.io wsim.distributions wsim.lsm wsim.electricity wsim.agriculture wsim.gldas; do \
		$(MAKE) -C $${s} $@ || exit 1; \
	done;
check:
	for s in wsim.io wsim.distributions wsim.lsm wsim.electricity wsim.agriculture workflow wsim.gldas; do \
		$(MAKE) -C $${s} $@ || exit 1; \
	done;
	Rscript test_cli.R
html:
	for s in wsim.io wsim.distributions wsim.electricity wsim.agriculture wsim.lsm wsim.gldas; do \
		$(MAKE) -C $${s} $@ || exit 1; \
	done;
	$(MAKE) -C docs images html;

publish-docs:
	docs/_publish.sh

build-ci:
	docker build --pull -t isciences/wsim-gitlabci:latest - < Dockerfile.gitlabci

push-ci:
	docker push isciences/wsim-gitlabci:latest

build-dev:
	docker build --pull --build-arg WSIM_VERSION=0.0 -t isciences/wsim:dev .

push-dev:
	docker push isciences/wsim:dev

build:
	docker build --pull -t isciences/wsim:latest .

push:
	docker push isciences/wsim:latest

.PHONY: check html
