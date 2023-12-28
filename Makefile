build:
	@mkdir -p $(TARGET)/boot
	@#python3 $(BASE)/scripts/preprocess.py $(SRC)/src/main.lua $(TARGET)/boot/kernel.lua -c $(SRC)/config.lua
	python3 $(SRC)/tool/build.py
