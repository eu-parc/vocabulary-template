# Template customization checklist

Use this checklist immediately after creating a new vocabulary repository.

1. Rename the project in `pyproject.toml`.
2. Set all vocabulary variables at the top of `Makefile`.
3. Replace placeholder namespaces and nanopublication URIs.
4. Fetch or commit the LinkML schema expected by `SCHEMA`.
5. Align `schema/dropbox.schema.json` with the accepted YAML fields.
6. Update `schema/dropbox.example.yaml` with a real, valid example.
7. Decide whether GitHub Pages should be enabled and adapt `site/ui-shapes.ttl`.
8. Configure the publishing bot by following `docs/bot-identity-setup.md`.
9. Run `uv sync` and `make validate-pr` with an example proposal.

Keep generated artifacts out of the template until they are produced by the
derived vocabulary's own workflow.
