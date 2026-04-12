SHELL := /usr/bin/env bash

ARCH ?= x86_64
JOBS ?= $(shell nproc)
CI_QEMU_TIMEOUT ?= 600

CROSS_COMPILE ?=
OBJCOPY ?=
NM ?=
LLVM ?=
BUSYBOX_BIN ?=
BUSYBOX_DIR ?=
BUSYBOX_OUT_DIR ?=
BUSYBOX_STATIC ?=
KERNEL_CMDLINE ?=
QEMU_ARGS ?=

.PHONY: help install-deps run ci

help:
	@echo "CI helper targets"
	@echo ""
	@echo "Targets:"
	@echo "  make -C ci install-deps       Install Ubuntu dependencies for CI"
	@echo "  make -C ci run                Build + artifact checks + QEMU smoke run"
	@echo "  make -C ci ci                 Alias of run"
	@echo ""
	@echo "Common variables:"
	@echo "  ARCH=$(ARCH)"
	@echo "  JOBS=$(JOBS)"
	@echo "  CI_QEMU_TIMEOUT=$(CI_QEMU_TIMEOUT)"
	@echo "  QEMU_ARGS=$(QEMU_ARGS)"

install-deps:
	@./install-deps-ubuntu.sh

run:
	@ARCH="$(ARCH)" JOBS="$(JOBS)" CI_QEMU_TIMEOUT="$(CI_QEMU_TIMEOUT)" \
		CROSS_COMPILE="$(CROSS_COMPILE)" OBJCOPY="$(OBJCOPY)" NM="$(NM)" LLVM="$(LLVM)" \
		BUSYBOX_BIN="$(BUSYBOX_BIN)" BUSYBOX_DIR="$(BUSYBOX_DIR)" \
		BUSYBOX_OUT_DIR="$(BUSYBOX_OUT_DIR)" BUSYBOX_STATIC="$(BUSYBOX_STATIC)" \
		KERNEL_CMDLINE="$(KERNEL_CMDLINE)" \
		./run.sh $(QEMU_ARGS)

ci: run
