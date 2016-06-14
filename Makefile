MIX=mix

all: clean escript

escript: folder deps
	$(MIX) escript.build
	mv smppsend $(BUILD_TO)

folder:
	mkdir -p $(BUILD_TO)

deps: hex
	$(MIX) deps.get
	$(MIX) deps.compile

hex:
	$(MIX) local.hex --force

clean:
	$(MIX) deps.clean --all
	$(MIX) clean
