# Membrane AWS Plugin

[![Hex.pm](https://img.shields.io/hexpm/v/membrane_aws_plugin.svg)](https://hex.pm/packages/membrane_aws_plugin)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/membrane_aws_plugin)
[![CircleCI](https://circleci.com/gh/jellyfish-dev/membrane_aws_plugin.svg?style=svg)](https://circleci.com/gh/jellyfish-dev/membrane_aws_plugin)
[![codecov](https://codecov.io/gh/jellyfish-dev/membrane_aws_plugin/branch/main/graph/badge.svg?token=ANWFKV2EDP)](https://codecov.io/gh/jellyfish-dev/membrane_aws_plugin)

This repository contains Membrane element that interacts with AWS.
Currently implemented are:
- `Membrane.AWS.S3.Source`


It's a part of the [Membrane Framework](https://membrane.stream).

## Installation

The package can be installed by adding `membrane_aws_plugin` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:membrane_aws_plugin, "~> 0.1.0"}
  ]
end
```

## Usage example

The `example/` folder contains an example usage of `Membrane.AWS.S3.Source`.

This demo downloads a file from S3 and saves it locally. It requires that you set these environment variables: `BUCKET`, `FILE_PATH`, `ACCESS_KEY_ID`, `SECRET_ACCESS_KEY`, `REGION`.
```bash
$ elixir examples/receive.exs
```

## Copyright and License

Copyright 2024, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_aws_plugin)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_aws_plugin)

Licensed under the [Apache License, Version 2.0](LICENSE)
