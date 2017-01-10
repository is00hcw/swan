PACKAGES = $(shell go list ./...)
TEST_PACKAGES = $(shell go list ./... | grep -v scheduler | grep -v vendor)

.PHONY: build fmt test test-cover-html test-cover-func collect-cover-data

# Prepend our vendor directory to the system GOPATH
# so that import path resolution will prioritize
# our third party snapshots.
export GO15VENDOREXPERIMENT=1
# GOPATH := ${PWD}/vendor:${GOPATH}
# export GOPATH

default: build

build: fmt build-swan

build-swan:
	go build  -ldflags "-X github.com/Dataman-Cloud/swan/srv/version.BuildTime=`date -u +%Y-%m-%d:%H-%M-%S` -X github.com/Dataman-Cloud/swan/src/version.Version=0.01-`git rev-parse --short HEAD`"  -v -o bin/swan main.go node.go

build-swancfg:
	go build -v -o bin/swancfg src/cli/cli.go

install:
	install -v bin/swan /usr/local/bin
	install -v bin/swancfg /usr/local/bin

generate:
	protoc --proto_path=./vendor/github.com/gogo/protobuf/:./src/manager/raft/types/:. --gogo_out=./src/manager/raft/types/ ./src/manager/raft/types/*.proto

clean:
	rm -rf bin/*

fmt:
	go fmt ./src/...

test:
	go test -cover=true ${TEST_PACKAGES}

collect-cover-data:
	@echo "mode: count" > coverage-all.out
	$(foreach pkg,$(TEST_PACKAGES),\
		go test -v -coverprofile=coverage.out -covermode=count $(pkg) || exit $?;\
		if [ -f coverage.out ]; then\
			tail -n +2 coverage.out >> coverage-all.out;\
		fi\
		;)
test-cover-html:
	go tool cover -html=coverage-all.out -o coverage.html

test-cover-func:
	go tool cover -func=coverage-all.out

release: list-authors

list-authors:
	./contrib/list-authors.sh


docker-build:
	docker build --tag swan --rm .

docker-run:
	docker rm -f swan-node-1 2>&1 || echo 0
	docker run --interactive --tty --env-file Envfile --name swan-node-1  --rm  -p 9999:9999 -p 2111:2111 -p 53:53/udp -p 80:80 -v `pwd`/data:/go/src/github.com/Dataman-Cloud/swan/data swan

docker-run-detached:
	docker rm -f swan-node-1 2>&1 || echo 0
	docker run --interactive --tty --env-file Envfile --name swan-node-1  -p 9999:9999 -p 2111:2111 -p 53:53/udp -p 80:80 -v /var/lib/swan:/go/src/github.com/Dataman-Cloud/swan/data --detach swan
