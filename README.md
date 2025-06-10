# Template repo

for instructions see: [how to create a repo from a template](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template).

# .github
This folder contains the `ISSUE TEMPLATES` to add, modify or deprecate a vocabulary term as well as the config files to configure actions (`.github/workflows`).

# Data
Add the vocabulary content as `.csv` and/or `.yaml` depending on the reusable workflows you want to use.

# Rules
The `voc2skosmos` workflow that transforms a `.csv` into a SKOS vocabulary requires a set of `yarrml` rules.

# Schema
Contains the data schema for the vocabulary terms and the changelog schema. Note that the workflows implemented within the eu-parc repository also support the usage of a uri to point to a data schema.

# Changelog
The changelog should be used as an instrument to keep track of changes to the vocabulary in between releases. The changelog should be updated with each pull request.