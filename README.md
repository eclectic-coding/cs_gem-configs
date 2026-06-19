![CI](https://github.com/eclectic-coding/cs_gem-configs/actions/workflows/ci.yml/badge.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)

# Gem & Engine Setup Scripts

Opinionated scaffolding for Ruby gems and Rails engine APIs, pre-configured with RSpec, SimpleCov, RuboCop, Bundler Audit, Codecov, and GitHub Actions CI/CD.

## Prerequisites

- Ruby (>= 3.3)
- Bundler
- Rails (for engine setup only)

## Installation

Clone the repo anywhere:

```bash
git clone https://github.com/eclectic-coding/cs_gem-configs.git gem-configs
cd gem-configs
```

Optionally, add the directory to your `PATH`:

```bash
export PATH="$PATH:/path/to/gem-configs"
```

## Configuration

On first run, you'll be prompted for two settings:

- **Base directory** -- where new gems/engines will be created
- **GitHub username** -- used for gem/engine metadata

These are saved to `~/.gem_setuprc` and reused on subsequent runs. On each subsequent run, the current settings are displayed and you're given the option to update them before proceeding.

To reconfigure without running a setup:

```bash
./setup_gem.sh --config
./setup_engine.sh --config
```

## Usage

### Create a new gem

```bash
./setup_gem.sh my_gem
```

### Create a new Rails engine API

```bash
./setup_engine.sh my_engine
```

## What gets scaffolded

- RSpec with SimpleCov code coverage (HTML + JSON)
- RuboCop with opinionated defaults
- Bundler Audit for dependency vulnerability checking
- Codecov configuration
- GitHub Actions workflows for CI and publishing
- Release script in `bin/release`
- CHANGELOG.md (Keep a Changelog format)
- Rakefile wired with a default task running lint, audit, and specs

## CI

This repo runs [ShellCheck](https://www.shellcheck.net/) on all shell scripts via GitHub Actions on every push and PR to `main`.

## File structure

```
gem-configs/
  config.sh           # Shared configuration logic (sourced by both scripts)
  setup_gem.sh        # Scaffolds a Ruby gem
  setup_engine.sh     # Scaffolds a Rails engine API
  files/              # CI workflow templates and release scripts
    main.yml
    publish.yml
    release_gem
    main_engine.yml
    publish_engine.yml
    release_engine
  .github/workflows/
    ci.yml             # ShellCheck linting
```