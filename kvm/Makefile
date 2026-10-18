PACKER       ?= packer
OS           ?= ubuntu-24.04
PLATFORM     ?= openstack
OS_ALL       := $(basename $(basename $(notdir $(wildcard os/*.pkrvars.hcl))))
PLATFORM_ALL := openstack cloudstack

PACKER_ARGS = -var-file=os/$(1).pkrvars.hcl -var platform=$(2)

.PHONY: help init fmt validate validate-all build build-all clean

help:
	@echo "make init                                 - cài plugin Packer"
	@echo "make validate OS=<os> PLATFORM=<platform> - validate (mặc định OS=$(OS) PLATFORM=$(PLATFORM))"
	@echo "make build    OS=<os> PLATFORM=<platform> - build image"
	@echo "make validate-all|build-all               - chạy mọi tổ hợp OS x PLATFORM"
	@echo "    OS:       $(OS_ALL)"
	@echo "    PLATFORM: $(PLATFORM_ALL)"
	@echo "make clean                                - xoá output/"

init:
	$(PACKER) init .

fmt:
	$(PACKER) fmt -recursive .

validate: init
	$(PACKER) validate $(call PACKER_ARGS,$(OS),$(PLATFORM)) .

validate-all: init
	@set -e; for os in $(OS_ALL); do for pf in $(PLATFORM_ALL); do \
		echo "== $$os / $$pf"; $(PACKER) validate -var-file=os/$$os.pkrvars.hcl -var platform=$$pf .; \
	done; done

build: init
	$(PACKER) build $(call PACKER_ARGS,$(OS),$(PLATFORM)) .

build-all: init
	@set -e; for os in $(OS_ALL); do for pf in $(PLATFORM_ALL); do \
		echo "== $$os / $$pf"; $(PACKER) build -var-file=os/$$os.pkrvars.hcl -var platform=$$pf .; \
	done; done

clean:
	rm -rf output
