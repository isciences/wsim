
check:
	for s in wsim.io wsim.distributions wsim.lsm; do \
		$(MAKE) -C $${s} $@ || exit 1; \
	done;
html:
	for s in wsim.io wsim.distributions wsim.lsm docs; do \
		$(MAKE) -C $${s} $@ || exit 1; \
	done;

.PHONY: check html
