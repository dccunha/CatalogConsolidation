# typed: true

require "sqlite3"
require "tempfile"

module Catalog
  module Services
    class SqliteExporter
      extend T::Sig

      class Error < StandardError; end

      SCHEMA = <<~SQL.freeze
        CREATE TABLE Product (
          Id INTEGER PRIMARY KEY AUTOINCREMENT,
          Name TEXT NOT NULL,
          Brand TEXT,
          Category TEXT
        );
        CREATE TABLE SellerProduct (
          Id INTEGER PRIMARY KEY AUTOINCREMENT,
          SellerName TEXT NOT NULL,
          ProductId INTEGER NOT NULL REFERENCES Product (Id),
          SellerProductId TEXT NOT NULL,
          UNIQUE (SellerName, SellerProductId),
          UNIQUE (SellerName, ProductId)
        );
        CREATE INDEX index_SellerProduct_ProductId ON SellerProduct (ProductId);
      SQL

      sig { returns(String) }
      def self.call
        new.call
      end

      sig { returns(String) }
      def call
        Tempfile.create([ "catalog-export-", ".db" ]) do |file|
          database = SQLite3::Database.new(file.path)
          begin
            build(database)
            database.close
            File.binread(file.path)
          ensure
            database.close unless database.closed?
          end
        end
      rescue SQLite3::Exception, IOError, SystemCallError => error
        raise Error, "Could not build the catalog download: #{error.message}"
      end

      private

      sig { params(database: SQLite3::Database).void }
      def build(database)
        database.execute("PRAGMA foreign_keys = ON")
        database.execute_batch(SCHEMA)
        database.transaction do
          insert_products(database)
          insert_seller_products(database)
        end
        verify(database)
      end

      sig { params(database: SQLite3::Database).void }
      def insert_products(database)
        Catalog::Models::Product.find_each do |product|
          database.execute("INSERT INTO Product (Id, Name, Brand, Category) VALUES (?, ?, ?, ?)",
            [ product.id, product.name, product.brand, product.category ])
        end
      end

      sig { params(database: SQLite3::Database).void }
      def insert_seller_products(database)
        Catalog::Models::SellerProduct.find_each do |association|
          database.execute("INSERT INTO SellerProduct (Id, SellerName, ProductId, SellerProductId) VALUES (?, ?, ?, ?)",
            [ association.id, association.seller_name, association.product_id, association.seller_product_id ])
        end
      end

      sig { params(database: SQLite3::Database).void }
      def verify(database)
        raise Error, "SQLite integrity check failed" unless database.get_first_value("PRAGMA integrity_check") == "ok"
        raise Error, "SQLite foreign key check failed" unless database.execute("PRAGMA foreign_key_check").empty?
      end
    end
  end
end
