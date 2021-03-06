DEPOPTS = -MMD -MF .dep/$(subst /,^,$(subst .obj/,,$@)).d -MP
CCOPTS = $(DEPOPTS) -ggdb -Wall -pthread

IPMILIBS := -lfreeipmi -lconfuse $(IPMILIBS)
LIBS = $(IPMILIBS) -ldl -rdynamic

all: sysmgr clientapi cards sysmgr.conf.example tags

sysmgr: .obj/sysmgr.o .obj/mprintf.o .obj/scope_lock.o .obj/TaskQueue.o .obj/Crate.o .obj/mgmt_protocol.o .obj/versioninfo.o
	g++ $(CCOPTS) $(IPMILIBS) -ldl -rdynamic -o $@ $^

#.PHONY: .obj/versioninfo.o
.obj/versioninfo.o: $(shell git ls-files)
	@mkdir -p .dep/ "$(dir $@)"
	echo "const char *GIT_BRANCH = \"$$(git rev-parse --abbrev-ref HEAD)\"; const char *GIT_COMMIT = \"$$(git describe)\"; const char *GIT_DIRTY = \"$$(git status --porcelain -z | sed -re 's/\x0/\\n/g')\";" | g++ $(CCOPTS) $(DEPOPTS) -c -o $@ -xc++ -

.obj/mgmt_protocol.o: mgmt_protocol.cpp commandindex.h commandindex.inc

.obj/%.o: %.cpp
	@mkdir -p .dep/ "$(dir $@)"
	g++ $(CCOPTS) $(DEPOPTS) -c -o $@ $<

cards: sysmgr
	make -C cards all

commandindex.h commandindex.inc: configure $(wildcard commands/*.h)
	./configure

sysmgr.conf.example: sysmgr.conf.example.tmpl $(wildcard cards/*.cpp)
	./configure

clientapi:
	make -C clientapi all

tags: *.cpp *.h
	ctags -R . 2>/dev/null || true

distclean: clean
	rm -rf tags commandindex.h commandindex.inc *.rpm sysmgr.conf.example .dep/
	make -C clientapi distclean
	make -C cards distclean
clean:
	rm -f sysmgr
	rm -rf .obj/
	rm -rf rpm/
	make -C clientapi clean
	make -C cards clean

rpm: all
	SYSMGR_ROOT=$(PWD) rpmbuild --sign -ba --quiet --define "_topdir $(PWD)/rpm" sysmgr.spec
	cp -v $(PWD)/rpm/RPMS/*/*.rpm ./
	rm -rf rpm/

.PHONY: distclean clean all clientapi rpm cards

-include $(wildcard .dep/*)
