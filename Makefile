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
	@ open $$(bundle info --path minima)

.PHONY: create-post
## create-post: creates empty post markdown file
create-post:
	@ if [ -z "$(TITLE)" ]; then echo >&2 please set the desired title via the variable TITLE; exit 2; fi
	@ touch "docs/_posts/`date +%Y-%m-%d`-$(TITLE).markdown"
	@ echo "Post created: docs/_posts/`date +%Y-%m-%d`-$(TITLE).markdown"

.PHONY: create-post-with-imgs
## create-post-with-imgs: creates empty post markdown file and empty imgs dir
create-post-with-imgs:
	@ if [ -z "$(TITLE)" ]; then echo >&2 please set the desired title via the variable TITLE; exit 2; fi
	@ touch "docs/_posts/`date +%Y-%m-%d`-$(TITLE).markdown"
	@ mkdir "docs/assets/images/`date +%Y-%m-%d`-$(TITLE)"
	@ echo "Post created: docs/_posts/`date +%Y-%m-%d`-$(TITLE).markdown"
	@ echo "Post imgs dir created: assets/images/`date +%Y-%m-%d`-$(TITLE)"

.PHONY: create-post-imgs-dir
## create-post-imgs-dir: creates imgs dir for post with given title
create-post-imgs-dir:
	@ if [ -z "$(TITLE)" ]; then echo >&2 please set the desired title via the variable TITLE; exit 2; fi
	@ mkdir "docs/assets/images/`date +%Y-%m-%d`-$(TITLE)"
	@ echo "Post imgs dir created: assets/images/`date +%Y-%m-%d`-$(TITLE)"