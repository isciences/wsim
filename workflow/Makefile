check:
	cd tests && python3 -m unittest -v
	cd config && python3 -m unittest -v

install:
	./setup.py install
	python3 -s -c 'import wsim_workflow.version; print("Installed wsim_workflow v", wsim_workflow.version.__version__)'
