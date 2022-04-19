LUA ?= lua
LUA_VERSION ?= $(shell $(LUA) -e 'v=_VERSION:gsub("^Lua *","");print(v)')
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
LUADIR ?= $(PREFIX)/share/lua/$(LUA_VERSION)

build: fennel

TEST_LUA_PATH ?= test/?.lua;./?.lua

test: fennel
	export LUA_PATH="$(TEST_LUA_PATH)"; $(LUA) test/init.lua

testall: export FNL_TEST_OUTPUT ?= text
testall: fennel
	$(MAKE) test LUA=lua5.1
	$(MAKE) test LUA=lua5.2
	$(MAKE) test LUA=lua5.3
	$(MAKE) test LUA=lua5.4
	$(MAKE) test LUA=luajit

luacheck:
	luacheck fennel.lua test/init.lua test/mangling.lua \
		test/misc.lua test/quoting.lua

count:
	cloc fennel.lua
	cloc --force-lang=lisp fennelview.fnl fennelfriend.fnl fennelbinary.fnl \
		launcher.fnl

# For the time being, avoid chicken/egg situation thru the old Lua launcher.
LAUNCHER=$(LUA) old_launcher.lua

# Precompile fennel libraries
%.lua: %.fnl fennel.lua
	 $(LAUNCHER) --globals "" --compile $< > $@

# All-in-one pure-lua script:
fennel: launcher.fnl fennel.lua fennelview.lua fennelfriend.lua fennelbinary.fnl
	echo "#!/usr/bin/env $(LUA)" > $@
	$(LAUNCHER) --globals "" --require-as-include --metadata --compile $< >> $@
	chmod 755 $@

# Change these up to swap out the version of Lua or for other operating systems.
STATIC_LUA_LIB ?= /usr/lib/x86_64-linux-gnu/liblua5.3.a
LUA_INCLUDE_DIR ?= /usr/include/lua5.3

fennel-bin: launcher.fnl fennel
	./fennel --compile-binary $< $@ $(STATIC_LUA_LIB) $(LUA_INCLUDE_DIR)

# Cross-compile to Windows; very experimental:
fennel-bin.exe: launcher.fnl fennel lua-5.3.5/src/liblua-mingw.a
	CC=i686-w64-mingw32-gcc fennel --compile-binary $< fennel-bin \
		lua-5.3.5/src/liblua-mingw.a $(LUA_INCLUDE_DIR)

# Sadly git will not work; you have to get the tarball for a working makefile:
lua-5.3.5: ; curl https://www.lua.org/ftp/lua-5.3.5.tar.gz | tar xz

# install gcc-mingw-w64-i686
lua-5.3.5/src/liblua-mingw.a: lua-5.3.5
	make -C lua-5.3.5 mingw CC=i686-w64-mingw32-gcc
	mv lua-5.3.5/src/liblua.a $@

ci: luacheck testall count

clean:
	rm -f fennel fennel-bin *_binary.c fennel-bin.exe built-ins luacov.*
	make -C lua-5.3.5 clean || true # this dir might not exist

coverage: fennel
	# need a symlink for the fake 'built-ins' module set on macros in fennel.lua
	ln -s fennel.lua built-ins && rm -f luacov.*
	$(LUA) -lluacov test/init.lua && rm -f built-ins
	@echo "generated luacov.report.out"
	@echo "Note: 'built-ins' coverage is inaccurate because it isn't a real file."

install: fennel fennel.lua fennelview.lua
	mkdir -p $(DESTDIR)$(BINDIR) && \
		cp fennel $(DESTDIR)$(BINDIR)/
	mkdir -p $(DESTDIR)$(LUADIR) && \
		for f in fennel.lua fennelview.lua; do cp $$f $(DESTDIR)$(LUADIR)/; done

.PHONY: build test testall luacheck count ci clean coverage install
