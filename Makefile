VOCABULARY_SLUG ?= vocabulary
VOCABULARY_LABEL ?= Vocabulary

DROPBOX_FOLDER ?= dropbox
UNPUBLISHED_FOLDER ?= unpublished
PUBLISHED_FOLDER ?= published
ARCHIVE_FOLDER ?= archive
REDIRECT_FOLDER ?= redirect

SCHEMA ?= schema/schema.yaml
SCHEMA_REPO ?= example/example-schema
SCHEMA_TAG ?= v0.1.0
SCHEMA_SOURCE_PATH ?= schema/schema.yaml
SCHEMA_DEST ?= $(SCHEMA)
SCHEMA_URL ?= https://raw.githubusercontent.com/$(SCHEMA_REPO)/$(SCHEMA_TAG)/$(SCHEMA_SOURCE_PATH)

OUT_FOLDER ?= build
ASSERTIONS_FOLDER ?= $(OUT_FOLDER)/assertions
PR_ASSERTIONS_FOLDER ?= $(OUT_FOLDER)/pr-assertions
ONTOLOGY_LABEL ?= $(VOCABULARY_SLUG).ttl
COMBINED_DATA ?= $(OUT_FOLDER)/combined.yaml
ID_MAP_FILE ?= $(REDIRECT_FOLDER)/id-map.tsv

# Vocabulary-specific settings. Override these in derived repositories.
TARGET_CLASS ?= terms
LINKML_TARGET_CLASS ?= EntityList
BASE_NAMESPACE ?= https://w3id.org/example/terms/
TERM_PARENT_CLASS ?= https://w3id.org/example/terms/RootTerm
MINT_NAMESPACE ?= https://w3id.org/example/$(VOCABULARY_SLUG)/
ENTITY_LIST_PREDICATE ?= https://w3id.org/example/terms/hasTerm

# Nanopublication metadata. Replace placeholders before production publishing.
NANOPUB_TYPE ?= $(TERM_PARENT_CLASS)
NANOPUB_TEMPLATE ?= https://w3id.org/np/REPLACE_WITH_TEMPLATE_NANOPUB
NANOPUB_PART_OF ?= https://w3id.org/spaces/$(VOCABULARY_SLUG)/r/vocabulary
PUBLISH_KEY_ARGS ?= --use-testsuite-keys
DRY ?=

# One-time migration default attribution, if a derived vocabulary imports
# existing terms into nanopublications.
MIGRATE_SUGGESTER ?= https://orcid.org/0000-0002-1825-0097

# Publishing bot identity. See docs/bot-identity-setup.md.
BOT_NAME ?= $(VOCABULARY_LABEL) bot
BOT_ID ?= $(VOCABULARY_SLUG)-bot
BOT_OWNER_ORCID ?= https://orcid.org/0000-0002-1825-0097
BOT_OWNER_NAME ?= Vocabulary Maintainer
BOT_IDENTITY_DIR ?= bot-identity
CI_REPO ?= owner/$(VOCABULARY_SLUG)-vocabulary
BOT_PUBLISH_ARGS ?=
_BOOTSTRAP_ARGS = --bot-name "$(BOT_NAME)" --bot-id "$(BOT_ID)" \
	--owner-orcid "$(BOT_OWNER_ORCID)" --owner-name "$(BOT_OWNER_NAME)" \
	--output-dir "$(BOT_IDENTITY_DIR)"

DATA_FILES = $(sort $(wildcard $(DROPBOX_FOLDER)/*.yaml))

.PHONY: help print-data prepare fetch-schema aggregate mint build graph2assertions \
	validate-pipeline validate-nanopubs validate-pr archive-dropbox process-dropbox \
	pipeline publish-defining migrate assertions bot-identity publish-bot-introduction \
	bot-ci-secrets test-flow clean

help:
	@echo "Targets:"
	@echo "  make fetch-schema             # download configured LinkML schema"
	@echo "  make validate-pipeline        # process dropbox -> build + unpublished, without archiving"
	@echo "  make validate-pr              # PR gate: build proposed terms + validate defining nanopubs"
	@echo "  make pipeline                 # process dropbox -> unpublished + archive"
	@echo "  make publish-defining         # mint unpublished assertions -> published/*.trig + id-map"
	@echo "  make publish-defining DRY=--dry-run"
	@echo "  make assertions               # extract published/*.trig -> build/assertions"
	@echo "  make bot-identity             # generate bot keypair + introduction to review"
	@echo "  make publish-bot-introduction # publish reviewed bot introduction"
	@echo "  make bot-ci-secrets           # push bot signing material to GitHub Actions"
	@echo "  make test-flow                # local smoke test"

print-data:
	@echo "$(DATA_FILES)"

prepare:
	mkdir -p $(OUT_FOLDER) $(UNPUBLISHED_FOLDER) $(PUBLISHED_FOLDER) $(ARCHIVE_FOLDER) $(REDIRECT_FOLDER)

fetch-schema:
	@if [ -z "$(SCHEMA_TAG)" ]; then \
		echo "SCHEMA_TAG must be set to a released upstream schema tag."; \
		exit 1; \
	fi
	mkdir -p $(dir $(SCHEMA_DEST))
	curl -fsSL "$(SCHEMA_URL)" -o "$(SCHEMA_DEST)"
	@echo "Downloaded $(SCHEMA_DEST) from $(SCHEMA_REPO) tag $(SCHEMA_TAG)"

aggregate: prepare
	@set -e; \
	if [ -z "$(DATA_FILES)" ]; then \
		echo "No YAML files found in $(DROPBOX_FOLDER). Skipping aggregation."; \
	else \
		uv run pubmate-yamlconcat \
			--target $(TARGET_CLASS) \
			--inherit suggester \
			$(COMBINED_DATA) \
			$(DATA_FILES); \
	fi

mint: aggregate
	@set -e; \
	if [ ! -f "$(COMBINED_DATA)" ]; then \
		echo "No combined YAML available. Skipping mint."; \
	else \
		uv run pubmate-mint \
			--data $(COMBINED_DATA) \
			--target $(TARGET_CLASS) \
			--namespace "$(MINT_NAMESPACE)" \
			--verbose \
			--preflabel name; \
	fi

build: mint
	@set -e; \
	if [ ! -f "$(COMBINED_DATA)" ]; then \
		echo "No combined YAML available. Skipping RDF conversion."; \
	elif [ ! -f "$(SCHEMA)" ]; then \
		echo "Missing $(SCHEMA). Run make fetch-schema or provide the schema file."; \
		exit 1; \
	else \
		echo "Building $(OUT_FOLDER)/$(ONTOLOGY_LABEL)"; \
		uv run linkml-convert \
			--target-class $(LINKML_TARGET_CLASS) \
			-s $(SCHEMA) \
			-o $(OUT_FOLDER)/$(ONTOLOGY_LABEL) \
			$(COMBINED_DATA); \
	fi

graph2assertions: build
	@set -e; \
	if [ ! -f "$(OUT_FOLDER)/$(ONTOLOGY_LABEL)" ]; then \
		echo "No ontology file available. Skipping assertion extraction."; \
	else \
		uv run pubmate-cleanrdf \
			--input-ontology-path $(OUT_FOLDER)/$(ONTOLOGY_LABEL) \
			--base-namespace $(BASE_NAMESPACE) \
			--term-output-path $(UNPUBLISHED_FOLDER) \
			--subjects-from-predicate $(ENTITY_LIST_PREDICATE); \
	fi

validate-pipeline: graph2assertions

validate-nanopubs:
	@set -e; \
	uv run pubmate-validate-defining \
		--assertion-folder $(PR_ASSERTIONS_FOLDER) \
		--namespace "$(MINT_NAMESPACE)"

validate-pr:
	$(MAKE) validate-pipeline UNPUBLISHED_FOLDER=$(PR_ASSERTIONS_FOLDER)
	$(MAKE) validate-nanopubs

archive-dropbox: graph2assertions
	@set -e; \
	if [ -n "$(DRY)" ]; then \
		echo "DRY mode enabled. Keeping YAML files in $(DROPBOX_FOLDER)."; \
		exit 0; \
	fi; \
	files="$(DATA_FILES)"; \
	if [ -z "$$files" ]; then \
		echo "No YAML files found in $(DROPBOX_FOLDER). Nothing to archive."; \
		exit 0; \
	fi; \
	if [ ! -f "$(COMBINED_DATA)" ]; then \
		echo "No minted combined YAML available. Nothing to archive."; \
		exit 1; \
	fi; \
	while :; do \
		label=$$(python3 -c 'import os, time; alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"; value = (int(time.time() * 1000) << 80) | int.from_bytes(os.urandom(10), "big"); print("".join(alphabet[(value >> shift) & 31] for shift in range(125, -1, -5)))'); \
		dest="$(ARCHIVE_FOLDER)/combined_$${label}.yaml"; \
		[ ! -e "$$dest" ] && break; \
	done; \
	cp "$(COMBINED_DATA)" "$$dest"; \
	echo "Archived minted combined YAML -> $$dest"; \
	for src in $$files; do \
		rm "$$src"; \
		echo "Removed processed dropbox file $$src"; \
	done

process-dropbox: archive-dropbox

pipeline: process-dropbox

publish-defining: prepare
	@set -e; \
	uv run pubmate-mint-publish \
		--assertion-folder $(UNPUBLISHED_FOLDER) \
		--namespace "$(MINT_NAMESPACE)" \
		--output-dir $(PUBLISHED_FOLDER) \
		--id-map-file $(ID_MAP_FILE) \
		--part-of "$(NANOPUB_PART_OF)" \
		--nanopub-type "$(NANOPUB_TYPE)" \
		--template "$(NANOPUB_TEMPLATE)" \
		$(PUBLISH_KEY_ARGS) \
		$(DRY)

migrate: prepare
	@set -e; \
	uv run pubmate-migrate \
		--assertion-folder $(UNPUBLISHED_FOLDER) \
		--namespace "$(MINT_NAMESPACE)" \
		--output-dir $(PUBLISHED_FOLDER) \
		--id-map-file $(ID_MAP_FILE) \
		--default-suggester "$(MIGRATE_SUGGESTER)" \
		--nanopub-type "$(NANOPUB_TYPE)" \
		--template "$(NANOPUB_TEMPLATE)" \
		--part-of "$(NANOPUB_PART_OF)" \
		$(PUBLISH_KEY_ARGS) \
		$(DRY)

bot-identity:
	uv run pubmate-bootstrap-identity $(_BOOTSTRAP_ARGS) --generate-keys

publish-bot-introduction:
	uv run pubmate-bootstrap-identity $(_BOOTSTRAP_ARGS) \
		--private-key $(BOT_IDENTITY_DIR)/id_rsa --public-key $(BOT_IDENTITY_DIR)/id_rsa.pub \
		--publish $(BOT_PUBLISH_ARGS)

bot-ci-secrets:
	@set -e; \
	intro=$$(grep -oP '@prefix this: <\K[^>]+' $(BOT_IDENTITY_DIR)/introduction.trig); \
	bot="$$intro/$(BOT_ID)"; \
	echo "Introduction : $$intro"; echo "Bot agent URI: $$bot"; \
	gh secret   set NANOPUB_BOT_PRIVATE_KEY --repo $(CI_REPO) < $(BOT_IDENTITY_DIR)/id_rsa; \
	gh variable set NANOPUB_BOT_PUBLIC_KEY  --repo $(CI_REPO) < $(BOT_IDENTITY_DIR)/id_rsa.pub; \
	gh variable set NANOPUB_BOT_URI         --repo $(CI_REPO) --body "$$bot"; \
	gh variable set NANOPUB_BOT_INTRO_URI   --repo $(CI_REPO) --body "$$intro"; \
	echo "Pushed signing key + identity URIs to $(CI_REPO)."

assertions: prepare
	@set -e; \
	uv run pubmate-extract-assertions \
		--nanopub-folder $(PUBLISHED_FOLDER) \
		--out $(ASSERTIONS_FOLDER)

test-flow:
	$(MAKE) validate-pipeline

clean:
	rm -rf $(OUT_FOLDER)/* $(UNPUBLISHED_FOLDER)/*.ttl
