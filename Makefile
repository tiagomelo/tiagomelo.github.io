.PHONY: help
## help: shows this help message
help:
	@ echo "Usage: make [target]\n"
	@ sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'

.PHONY: run
## run: runs website locally
run:
	@ cd docs && bundle exec jekyll serve

.PHONY: show-theme-files
## show-theme-files: shows theme files
show-theme-files:
	@ cd docs && open $$(bundle info --path minima)

.PHONY: create-post
## create-post: creates empty post markdown file
create-post:
	@ if [ -z "$(TITLE)" ]; then echo >&2 please set the desired title via the variable TITLE; exit 2; fi
	@ go run postgen/postgen.go -t $(TITLE)

.PHONY: create-app-policy
## create-app-policy: creates empty app policy MD file
create-app-policy:
	@ if [ -z "$(TITLE)" ]; then echo >&2 please set the desired title via the variable TITLE; exit 2; fi
	@ mkdir -p docs/apps/$(TITLE) && touch docs/apps/$(TITLE)/privacy-policy.md
	@ echo "Created app policy file at docs/apps/$(TITLE)/privacy-policy.md"
