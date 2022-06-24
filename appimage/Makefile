RESOURCES = $(shell find rsc/ -type f)
ARCH = $(shell uname -m)
APPIMAGE = Fault-$(ARCH).AppImage

all: $(APPIMAGE)

.PHONY: squashfs-root/build/bin/fault
squashfs-root/build/bin/fault: ../Dockerfile Makefile
	rm -rf squashfs-root
	mkdir -p ./squashfs-root/lib ;\
	docker build -t fault_build -f ../Dockerfile ..
	id=$$(docker create fault_build) ; \
	docker cp $$id:/build ./squashfs-root/build ; \
	docker rm -v $$id

appimagetool:
	curl -L https://github.com/AppImage/AppImageKit/releases/download/13/appimagetool-x86_64.AppImage > ./appimagetool
	chmod +x ./appimagetool

$(APPIMAGE): squashfs-root/build/bin/fault appimagetool $(RESOURCES) 
	cp $(RESOURCES) ./squashfs-root
	mkdir -p ./squashfs-root/test
	cp ../Tests/RTL/spm.v ./squashfs-root/test/spm.v
	cp -r ../Tech/osu035 ./squashfs-root/test/osu035
	./appimagetool ./squashfs-root

PREFIX ?= /usr/local
install:
	install $(APPIMAGE) $(PREFIX)/bin/fault

.PHONY: clean
clean:
	rm -f *.AppImage
	rm -rf squashfs-root
	rm -rf build