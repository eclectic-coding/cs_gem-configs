#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=config.sh
source "$SCRIPT_DIR/config.sh"

if [ "$1" = "--config" ]; then
  run_config_prompt
  exit 0
fi

# --- 1. VALIDATE AND EXTRACT ARGUMENT ---
if [ -z "$1" ]; then
  echo "Usage: $0 <engine_name>"
  echo "       $0 --config  (reconfigure defaults)"
  echo "Example: $0 core_api"
  exit 1
fi

ensure_config

ENGINE_NAME="$1"

echo "🚀 Starting setup for isolated Rails Engine API: ${ENGINE_NAME}..."

# --- 2. GENERATE COMPACT ENGINE ---
cd "$BASE_DIR"

rails plugin new "$ENGINE_NAME" \
  --no-rc \
  --mountable \
  --api \
  --git \
  --git-username "$GITHUB_USERNAME" \
  --mit \
  --skip-test \
  --dummy-path=spec/dummy \
  --linter=rubocop \
  --skip-ci \
  --skip-bundle

cd "$BASE_DIR/$ENGINE_NAME"

# --- 3. INJECT ADDITIONAL DEPENDENCIES ---
echo "📝 Configuring dependencies..."

cat >> Gemfile << 'RUBY'
group :development do
  gem "rubocop-rails-omakase", require: false
  gem "bundler-audit"
end

group :development, :test do
  gem "puma"
  gem "sqlite3"
  gem "propshaft"
end

group :test do
  gem "rspec-rails"
  gem "simplecov", require: false
  gem "simplecov_json_formatter", require: false
end
RUBY

bundle install

# --- 4. SETUP RSpec ---
echo "🧪 Setting up RSpec..."

rails generate rspec:install

# --- 4b. INJECT DUMMY ENV INTO RAILS HELPER ---
RAILS_HELPER="spec/rails_helper.rb"
sed -i '' '/# Add additional requires below this line. Rails is not loaded until this point!/a\
require File.expand_path("../dummy/config/environment", __FILE__)
' "$RAILS_HELPER"

# --- 5. INJECT SIMPLECOV INTO SPEC HELPER ---
SPEC_HELPER="spec/spec_helper.rb"

read -r -d '' SIMPLECOV_BLOCK << 'RUBY' || true
require "simplecov"
require "simplecov_json_formatter"

SimpleCov.start do
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::JSONFormatter
  ])
  add_filter "/spec/"
  add_filter "/version.rb"
end


RUBY

echo "${SIMPLECOV_BLOCK}$(cat "$SPEC_HELPER")" > "$SPEC_HELPER"

# --- 6. CREATE RUBOCOP CONFIG ---
cat > .rubocop.yml << 'YAML'
inherit_gem: { rubocop-rails-omakase: rubocop.yml }

AllCops:
  SuggestExtensions: false
  TargetRubyVersion: 3.3
  NewCops: enable

  Exclude:
    - "bin/*"
    - "README.md"
    - "spec/**/*"
    - "vendor/**/*"

Metrics/BlockLength:
  Exclude:
    - 'spec/**/*'

Layout/SpaceInsideArrayLiteralBrackets:
  Enabled: true
  EnforcedStyle: no_space

Style/StringLiterals:
  EnforcedStyle: double_quotes

Style/StringLiteralsInInterpolation:
  EnforcedStyle: double_quotes
YAML

# --- 7. SETUP THE CI WORKFLOW PIPELINE ---
echo "🛠️ Creating GitHub Actions workflow configuration..."
mkdir -p .github/workflows

cp "$SCRIPT_DIR/files/main_engine.yml" .github/workflows/main.yml
cp "$SCRIPT_DIR/files/publish_engine.yml" .github/workflows/publish.yml
cp "$SCRIPT_DIR/files/release_engine" bin/release

sed -i '' "s/GEM_NAME/${ENGINE_NAME}/g" bin/release

# --- 8. CREATE CODECOV CONFIG ---
cat > codecov.yml << 'YAML'
comment:
  layout: "reach, diff, flags, files"
  behavior: default
  # Only post or update the comment if the coverage drops
  require_changes: "coverage_drop"

coverage:
  status:
    project:
      default:
        informational: false
    patch:
      default:
        informational: false
YAML

# --- 9. UPDATE RAKEFILE ---
sed -i '' '/require "bundler\/gem_tasks"/a\
\
require '"'"'rubocop/rake_task'"'"'\
require '"'"'bundler/audit/task'"'"'\
require '"'"'rspec/core/rake_task'"'"'\
\
RuboCop::RakeTask.new(:lint)\
Bundler::Audit::Task.new\
RSpec::Core::RakeTask.new(:spec)\
\
task default: [:lint, :'"'"'bundle:audit:update'"'"', '"'"'bundle:audit:check'"'"', :spec]
' Rakefile

# --- 10. GENERATE CHANGELOG ---
cat > CHANGELOG.md << 'MARKDOWN'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
MARKDOWN

# --- 11. FINALIZE ---
git init
git add .
git commit -m "chore: initial layout for ${ENGINE_NAME} api with rspec, rubocop, and ci"

echo "✅ Engine '${ENGINE_NAME}' configured successfully!"
echo "📍 Your isolated engine code resides in: $(pwd)"
