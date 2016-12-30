project_root := $(realpath $(PWD)/..)
include $(project_root)/Makefile.variables

image_name := registry-monitor
image_registry := quay.io/nordstrom
test_registry := docker.registry.$(platform_domain_name)/k8s
image_release := 0.0.1

.PHONY: build/image tag/image push/image

ifdef http_proxy
build_args += --build-arg=http_proxy=$(http_proxy)
build_args += --build-arg=HTTP_PROXY=$(http_proxy)
build_args += --build-arg=https_proxy=$(http_proxy)
build_args += --build-arg=HTTPS_PROXY=$(http_proxy)
endif

build/image: build/registry-monitor
	docker build $(build_args) -t $(image_name) .

tag/image: build/image
	docker tag $(image_name) $(image_registry)/$(image_name):$(image_release)

tag/test-image: build/image
	docker tag $(image_name) $(test_registry)/$(image_name):$(image_release)

push/image: tag/image
	docker push $(image_registry)/$(image_name):$(image_release)

push/test-image: tag/test-image
	docker push $(test_registry)/$(image_name):$(image_release)

build/registry-monitor: $(GOPATH)/src/github.com/coreos/registry-monitor | build
	GOOS=linux GOARCH=amd64 go build -o $@ github.com/coreos/registry-monitor

$(GOPATH)/src/github.com/coreos/registry-monitor:
	go get -d github.com/coreos/registry-monitor

build:
	mkdir -p build
