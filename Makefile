UUID := touch-guard@marcus-friction.github.io
DIST := dist

.PHONY: all check package test test-shell clean

all: package

check test:
	./check.sh

package:
	./build.sh

test-shell: package
	./test-shell.sh

clean:
	rm -rf $(DIST)
