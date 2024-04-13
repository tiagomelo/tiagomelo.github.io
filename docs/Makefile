.PHONY: help
## help: shows this help message
help:
	@ echo "Usage: make [target]\n"
	@ sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'

.PHONY: run
## run: runs website locally
run:
	@ bundle exec jekyll serve

.PHONY: show-theme-files
## show-theme-files: shows theme files
show-theme-files:
	@ open $$(bundle info --path minima)