# Publishing happens on GitHub Actions — `make publish` only dispatches it. The
# other targets are the same runner scripts, for driving an entry locally:
# `make build ARGS=fastqc`.

.PHONY: publish
publish:
	bash ./publish.sh $(ARGS)

.PHONY: options
options:
	bash ./.github/scripts/options.sh

.PHONY: prepare
prepare:
	bash ./.github/scripts/prepare.sh

.PHONY: boot
boot:
	bash ./.github/scripts/boot.sh

.PHONY: build
build:
	bash ./.github/scripts/build.sh $(ARGS)

.PHONY: verify
verify:
	bash ./.github/scripts/verify.sh $(ARGS)

.PHONY: run
run:
	bash ./.github/scripts/run.sh $(ARGS)
