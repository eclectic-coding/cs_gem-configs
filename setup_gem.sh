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
  echo "Usage: $0 <gem_name>"
  echo "       $0 --config  (reconfigure defaults)"
  echo "Example: $0 core_api"
  exit 1
fi

ensure_config

GEM_NAME="$1"

echo "🚀 Starting setup for Ruby gem: ${GEM_NAME}..."

# --- 2. GENERATE COMPACT GEM ---
cd "$BASE_DIR"

bundle gem "$GEM_NAME" \
  --no-exe \
  --no-coc \
  --git \
  --github-username "$GITHUB_USERNAME" \
  --mit \
  --test=rspec \
  --linter=rubocop \
  --skip-ci \
  --no-bundle

cd "$BASE_DIR/$GEM_NAME"

# --- 3. INJECT ADDITIONAL DEPENDENCIES ---
echo "📝 Configuring dependencies..."

sed -i '' 's/required_ruby_version.*=.*/required_ruby_version = ">= 3.3.0"/' "$GEM_NAME.gemspec"

sed -i '' '/gem "irb"/d' Gemfile
sed -i '' '/gem "rspec", "~> 3.0"/d' Gemfile
sed -i '' '/gem "rubocop", "~> 1.21"/d' Gemfile

cat >> Gemfile << 'RUBY'
group :development do
  gem "bundler-audit"
  gem "irb"
  gem "rubocop", "~> 1.21"
  gem "rubocop-rake"
end

group :test do
  gem "rspec", "~> 3.0"
  gem "simplecov", require: false
  gem "simplecov_json_formatter", require: false
end
RUBY

bundle install --quiet

# --- 4. INJECT SIMPLECOV INTO SPEC HELPER ---
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
  track_files "lib/**/*.rb"
end

RUBY

echo "${SIMPLECOV_BLOCK}$(cat "$SPEC_HELPER")" > "$SPEC_HELPER"

# --- 4. CREATE CODECOV CONFIG ---
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

# --- 5. CREATE RUBOCOP CONFIG ---
cat > .rubocop.yml << 'YAML'
plugins:
  - rubocop-rake

AllCops:
  SuggestExtensions: false
  TargetRubyVersion: 3.3
  NewCops: enable

  Exclude:
    - "bin/*"
    - "README.md"
    - "spec/**/*"
    - "vendor/**/*"

Style/Documentation:
  Enabled: false

Style/StringLiterals:
  EnforcedStyle: double_quotes

Style/StringLiteralsInInterpolation:
  EnforcedStyle: double_quotes
YAML

# --- 6. COPY CI WORKFLOWS ---
mkdir -p "$BASE_DIR/$GEM_NAME/.github/workflows"
cp "$SCRIPT_DIR/files/main.yml" "$BASE_DIR/$GEM_NAME/.github/workflows/main.yml"
cp "$SCRIPT_DIR/files/publish.yml" "$BASE_DIR/$GEM_NAME/.github/workflows/publish.yml"
cp "$SCRIPT_DIR/files/release_gem" bin/release

sed -i '' "s/GEM_NAME/${GEM_NAME}/g" bin/release

# --- 7. UPDATE RAKEFILE ---
RAKEFILE="Rakefile"

sed -i '' '/require "rubocop\/rake_task"/d' "$RAKEFILE"
sed -i '' '/require "rspec\/core\/rake_task"/a\
require "rubocop\/rake_task"' "$RAKEFILE"
sed -i '' '/require "rubocop\/rake_task"/a\
require "bundler\/audit\/task"' "$RAKEFILE"

sed -i '' '/RuboCop::RakeTask.new/d' "$RAKEFILE"
sed -i '' '/RSpec::Core::RakeTask.new(:spec)/a\
RuboCop::RakeTask.new' "$RAKEFILE"

sed -i '' '/RuboCop::RakeTask.new/a\
Bundler::Audit::Task.new' "$RAKEFILE"

sed -i '' 's/task default: %i\[spec rubocop\]/task default: ["bundle:audit:update", "bundle:audit:check", :rubocop, :spec]/' "$RAKEFILE"

# --- 10. GENERATE CHANGELOG ---
cat > CHANGELOG.md << 'MARKDOWN'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
MARKDOWN

# --- 8. INITIAL COMMIT ---
git add .
git commit -m "chore: initial gem setup"
