
check:
	for s in wsim.io wsim.distributions; do \
		$(MAKE) -C $${s} $@ || exit 1; \
	done;
html:
	for s in wsim.io wsim.distributions docs; do \
		$(MAKE) -C $${s} $@ || exit 1; \
	done;

.PHONY: check html
