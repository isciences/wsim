install:
	for s in wsim.io wsim.distributions wsim.lsm; do \
		$(MAKE) -C $${s} $@ || exit 1; \
	done;
check:
	./test_cli.sh 
	for s in wsim.io wsim.distributions wsim.lsm workflow; do \
		$(MAKE) -C $${s} $@ || exit 1; \
	done;
	Rscript test_cli.R
html:
	for s in wsim.io wsim.distributions wsim.lsm docs; do \
		$(MAKE) -C $${s} $@ || exit 1; \
	done;

build-ci:
	docker build -f Dockerfile.gitlabci -t isciences/wsim-gitlabci:latest .

push-ci:
	docker push isciences/wsim-gitlabci:latest

build:
	docker build -t isciences/wsim:2_latest .

push:
	docker push isciences/wsim:2_latest

.PHONY: check html
