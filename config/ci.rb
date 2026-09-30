# Run using bin/ci

ActiveSupport::ContinuousIntegration.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"
  step "Style: ERB", "bundle exec erb_lint --lint-all"
  step "Style: JavaScript", "npm run lint:js"
  step "Types: Sorbet", "bundle exec srb tc"
  step "Types: Concept sigils", "bin/check-concept-types"
  step "Types: Gem RBI freshness", "bin/tapioca gems --verify"
  step "Types: Rails RBI freshness", "bin/tapioca dsl --verify"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Database: Prepare test", "env RAILS_ENV=test bin/rails db:prepare"
  step "Tests: RSpec", "env RAILS_ENV=test bundle exec rspec"
  step "Tests: JavaScript", "npm run test:js"
  step "Database: Model and schema consistency", "env RAILS_ENV=test bundle exec database_consistency"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
