# Vocabulary Nanopublication Template

This repository is a template for vocabularies that are curated through pull
requests, transformed into RDF assertions, and published as defining
nanopublications.

The workflow is:

1. Contributors add one or more YAML files to `dropbox/`.
2. The pipeline validates and combines those files.
3. Missing term identifiers are minted.
4. The combined YAML is converted to RDF with LinkML.
5. One assertion file per term is written to `unpublished/`.
6. A publishing bot signs and publishes those assertions as nanopublications.
7. Published nanopublications are committed to `published/`, with redirect
   mappings in `redirect/`.

The template is intentionally small. Generated vocabulary data, published
nanopublications, private bot keys, and vocabulary-specific scripts should live
in derived repositories, not here.

## First-Time Setup For A New Vocabulary

After creating a repository from this template, edit the vocabulary settings at
the top of `Makefile`.

Required settings:

| Variable | Meaning |
| --- | --- |
| `VOCABULARY_SLUG` | Short lowercase name used for generated filenames and bot IDs. |
| `TARGET_CLASS` | YAML list key consumed by `pubmate-yamlconcat`. |
| `LINKML_TARGET_CLASS` | LinkML class passed to `linkml-convert`. |
| `BASE_NAMESPACE` | Namespace of ontology terms in the LinkML schema. |
| `MINT_NAMESPACE` | Namespace where new term identifiers are minted. |
| `TERM_PARENT_CLASS` | Parent class URI for new terms, when applicable. |
| `ENTITY_LIST_PREDICATE` | Predicate used to find term subjects in the converted RDF. |
| `NANOPUB_TYPE` | Type stamped on published nanopublications. |
| `NANOPUB_TEMPLATE` | Nanodash template nanopub URI for this vocabulary. |
| `NANOPUB_PART_OF` | Vocabulary or space URI used in `dcterms:isPartOf`. |

Then adjust `schema/dropbox.schema.json` and
`schema/dropbox.example.yaml` so the accepted YAML fields match your upstream
LinkML schema.

## Proposing Terms

Add a YAML file to `dropbox/` and open a pull request. A minimal proposal looks
like this:

```yaml
suggester: https://orcid.org/0000-0002-1825-0097

terms:
  - name: example term
    description: A short definition of the term.
    parent_terms:
      - https://w3id.org/example/terms/RootTerm
```

`suggester` is optional. When present, it is used as the provenance attribution
for resulting nanopublications. It may be set once at file level or overridden
per term.

Identifiers are optional for new terms. If an `id` is not provided, the pipeline
mints one in `MINT_NAMESPACE`.

## Repository Layout

| Path | Purpose |
| --- | --- |
| `dropbox/` | Incoming YAML proposal files. |
| `archive/` | Processed combined YAML files with minted identifiers. |
| `unpublished/` | Generated RDF assertion files waiting for publication. |
| `published/` | Published nanopublications as `.trig` files. |
| `redirect/` | Term identifier to nanopublication identifier mappings. |
| `schema/` | Dropbox JSON Schema, example YAML, and fetched LinkML schema. |
| `site/` | Optional browser shape/configuration files. |
| `build/` | Local transient build artifacts, ignored by git. |

Empty state directories contain `.gitkeep` files so newly generated artifacts
have a stable destination.

## Local Usage

Install dependencies:

```bash
uv sync
```

Download the configured upstream LinkML schema:

```bash
make fetch-schema
```

Validate and process incoming YAML without archiving:

```bash
make validate-pipeline
```

Process accepted YAML from `dropbox/`:

```bash
make pipeline
```

Dry-run publication:

```bash
make publish-defining DRY=--dry-run
```

Real publication requires a configured bot identity:

```bash
make publish-defining PUBLISH_KEY_ARGS="--private-key bot_id_rsa --public-key bot_id_rsa.pub --orcid-id https://w3id.org/np/.../bot --name 'Vocabulary bot' --intro-nanopub-uri https://w3id.org/np/..."
```

Run a local smoke test:

```bash
make test-flow
```

## GitHub Workflow

`.github/workflows/publish.yaml` handles both validation and publication:

- Pull requests build proposed terms into disposable `build/pr-assertions/`,
  validate that they can become defining nanopublications, and upload artifacts.
- Pushes to `main` process accepted `dropbox/` files, archive the minted YAML,
  publish with the bot if configured, and commit generated artifacts.
- Manual runs support `dry-run`, `test-publish`, and `production` modes.

Before production publishing can run, create and register a bot identity. See
`docs/bot-identity-setup.md`.

## What To Customize

At minimum, each derived vocabulary should customize:

- `Makefile` vocabulary variables.
- `pyproject.toml` project name and description.
- `schema/dropbox.schema.json` and `schema/dropbox.example.yaml`.
- `site/ui-shapes.ttl`, if publishing a GitHub Pages browser.
- `docs/bot-identity-setup.md` identity defaults.

Do not commit private keys, local virtual environments, or generated `build/`
artifacts.
