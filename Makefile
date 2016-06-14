MIX=mix

all: escript

escript: deps
	$(MIX) escript.build

deps:
	$(MIX) deps.get
	$(MIX) deps.compile

clean:
	$(MIX) deps.clean --all
	$(MIX) clean
