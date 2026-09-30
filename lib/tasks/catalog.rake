namespace :catalog do
  desc "Load the unchanged SQLite reference products into PostgreSQL"
  task load_reference: :environment do
    inserted = Catalog::Services::ReferenceCatalogLoader.call
    puts "Reference catalog ready: #{inserted} products inserted, #{975 - inserted} already present"
  end
end
