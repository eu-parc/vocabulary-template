# Setting up the publishing bot identity

Defining nanopublications are signed and published by a bot: a software agent
with its own RSA keypair. The bot is introduced once by an introduction
nanopublication that binds the bot agent URI to its public key. Later published
nanopublications can then be verified as signed by that bot.

This is a one-time setup. The private key is the bot's identity, so keep it out
of git and store it in a secret manager.

## Defaults to customize

These values are Makefile variables. Override them in the Makefile or on the
command line before creating the identity.

| Variable | Default |
| --- | --- |
| `BOT_NAME` | `$(VOCABULARY_LABEL) bot` |
| `BOT_ID` | `$(VOCABULARY_SLUG)-bot` |
| `BOT_OWNER_ORCID` | `https://orcid.org/0000-0002-1825-0097` |
| `BOT_OWNER_NAME` | `Vocabulary Maintainer` |
| `CI_REPO` | `owner/$(VOCABULARY_SLUG)-vocabulary` |

## Steps

Generate a local keypair and signed introduction:

```bash
make bot-identity
```

Review `bot-identity/introduction.trig`. Then publish the introduction:

```bash
make publish-bot-introduction
```

Use the test registry while rehearsing:

```bash
make publish-bot-introduction BOT_PUBLISH_ARGS=--test-server
```

Push the signing key and identity URIs to GitHub Actions:

```bash
make bot-ci-secrets
```

This sets:

- secret `NANOPUB_BOT_PRIVATE_KEY`
- variable `NANOPUB_BOT_PUBLIC_KEY`
- variable `NANOPUB_BOT_URI`
- variable `NANOPUB_BOT_INTRO_URI`

Once those are configured, production runs of
`.github/workflows/publish.yaml` can sign and publish accepted assertions.
