class CreateCatalogProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |table|
      table.text :name, null: false
      table.text :brand
      table.text :category

      table.check_constraint "name ~ '[^[:space:]]'", name: "products_name_not_blank"
    end

    create_table :seller_products do |table|
      table.text :seller_name, null: false
      table.text :seller_product_id, null: false
      table.references :product, null: false, foreign_key: true, index: true

      table.check_constraint "seller_name ~ '[^[:space:]]'", name: "seller_products_seller_name_not_blank"
      table.check_constraint "seller_product_id ~ '[^[:space:]]'", name: "seller_products_seller_product_id_not_blank"
    end

    add_index :seller_products, [ :seller_name, :seller_product_id ], unique: true,
      name: "index_seller_products_on_seller_identity"
    add_index :seller_products, [ :seller_name, :product_id ], unique: true,
      name: "index_seller_products_on_seller_and_product"
  end
end
