program_name := imageleap

CFLAGS += -std=c99
LDFLAGS += -framework Cocoa -framework QuartzCore
PREFIX ?= /usr/local

.PHONY: all clean

all: $(program_name)

$(program_name): main
	@ mkdir -p build
	cp main build/$(program_name)

install: $(program_name)
	cp build/$(program_name) ${PREFIX}/bin
	cp $(program_name).1 $(PREFIX)/share/man/man1/

clean:
	@- $(RM) main
	@- $(RM) build/$(program_name)
