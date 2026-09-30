# Run with: docker compose run --rm -e RAILS_ENV=test web bin/rails runner script/acceptance_reference_aggregate.rb

abort "Acceptance aggregate runs only in the test environment" unless Rails.env.test?

initial_counts = [ Catalog::Models::Product.count, Intake::Models::Batch.count ]
abort "Acceptance aggregate requires zero Products and Batches in the test database" unless initial_counts == [ 0, 0 ]

observed = nil
ActiveRecord::Base.transaction do
  reference_count = Catalog::Services::ReferenceCatalogLoader.call
  json = File.read(Rails.root.join("docs/refs/ProductEntry.json"))
  first = Intake::Services::ImportProcessor.call(json: json, source_name: "ProductEntry.json")
  entity_counts = [ Catalog::Models::Product.count, Catalog::Models::SellerProduct.count,
    Intake::Models::SellerItem.count, Intake::Models::ReviewCase.count ]
  second = Intake::Services::ImportProcessor.call(json: json, source_name: "ProductEntry.json")
  second_entity_counts = [ Catalog::Models::Product.count, Catalog::Models::SellerProduct.count,
    Intake::Models::SellerItem.count, Intake::Models::ReviewCase.count ]

  [ first, second ].each do |result|
    raise "Import did not reconcile 269 rows" unless result.input_count == 269 &&
      result.rows.map(&:position) == (1..269).to_a && result.totals.values.sum == 269
  end
  raise "Rerun changed entity counts" unless entity_counts == second_entity_counts

  observed = { reference_count: reference_count, first_totals: first.totals,
    second_totals: second.totals, first_entity_counts: entity_counts,
    second_entity_counts: second_entity_counts }
  raise ActiveRecord::Rollback
end

abort "Acceptance aggregate left test database writes behind" unless
  [ Catalog::Models::Product.count, Intake::Models::Batch.count ] == initial_counts

puts JSON.pretty_generate(observed)
