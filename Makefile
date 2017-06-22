MIX=mix
SMPPSEND_BIN=smppsend

VERSIONS=17 18 19 20

all: clean_bin $(VERSIONS) release

clean_bin:
	rm -rf bin

release:
	tar czf bin.tar.gz bin

escript: clean dependencies
	$(MIX) escript.build
	mv smppsend $(SMPPSEND_BIN)

dependencies:
	$(MIX) deps.get
	$(MIX) deps.compile

clean:
	rm -rf _build
	$(MIX) deps.clean --all
	$(MIX) clean

$(VERSIONS): %:
	./build.sh $@
