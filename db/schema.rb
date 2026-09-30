# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_30_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "intake_batches", force: :cascade do |t|
    t.text "source_name", null: false
    t.integer "input_count", null: false
    t.datetime "created_at", null: false
    t.check_constraint "input_count >= 0", name: "intake_batches_input_count_nonnegative"
    t.check_constraint "source_name ~ '[^[:space:]]'::text", name: "intake_batches_source_name_not_blank"
  end

  create_table "intake_review_candidates", force: :cascade do |t|
    t.bigint "review_case_id", null: false
    t.bigint "product_id", null: false
    t.integer "evidence_revision", null: false
    t.integer "rank", null: false
    t.decimal "score", precision: 8, scale: 7, null: false
    t.jsonb "original", null: false
    t.jsonb "comparison", null: false
    t.jsonb "differing_fields", default: [], null: false
    t.jsonb "conflicting_association"
    t.datetime "created_at", null: false
    t.index ["product_id"], name: "index_intake_review_candidates_on_product_id"
    t.index ["review_case_id", "evidence_revision", "product_id"], name: "index_intake_review_candidates_on_case_revision_product", unique: true
    t.index ["review_case_id", "evidence_revision", "rank"], name: "index_intake_review_candidates_on_case_revision_rank", unique: true
    t.check_constraint "evidence_revision >= 1 AND rank >= 1", name: "intake_review_candidates_positive_order"
    t.check_constraint "score >= 0::numeric AND score <= 1::numeric", name: "intake_review_candidates_score_range"
  end

  create_table "intake_review_cases", force: :cascade do |t|
    t.bigint "seller_item_id", null: false
    t.bigint "batch_id", null: false
    t.integer "source_position", null: false
    t.text "status", null: false
    t.text "reason", null: false
    t.jsonb "source_input", null: false
    t.jsonb "source_comparison", null: false
    t.integer "evidence_revision", default: 0, null: false
    t.jsonb "conflicting_association"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["batch_id", "status"], name: "index_intake_review_cases_on_batch_and_status"
    t.index ["seller_item_id"], name: "index_intake_review_cases_on_active_seller_item", unique: true, where: "(status = ANY (ARRAY['pending'::text, 'resolved'::text]))"
    t.index ["seller_item_id"], name: "index_intake_review_cases_on_seller_item_id"
    t.check_constraint "evidence_revision >= 0", name: "intake_review_cases_revision_nonnegative"
    t.check_constraint "reason ~ '[^[:space:]]'::text", name: "intake_review_cases_reason_not_blank"
    t.check_constraint "source_position >= 1", name: "intake_review_cases_position_positive"
    t.check_constraint "status = ANY (ARRAY['pending'::text, 'resolved'::text, 'superseded'::text])", name: "intake_review_cases_status_valid"
  end

  create_table "intake_review_corrections", force: :cascade do |t|
    t.bigint "review_case_id", null: false
    t.text "reviewer", null: false
    t.jsonb "corrected_input", null: false
    t.jsonb "corrected_comparison", null: false
    t.datetime "corrected_at", null: false
    t.index ["review_case_id", "corrected_at", "id"], name: "index_intake_review_corrections_on_case_time"
    t.check_constraint "reviewer ~ '[^[:space:]]'::text", name: "intake_review_corrections_reviewer_not_blank"
  end

  create_table "intake_review_decisions", force: :cascade do |t|
    t.bigint "review_case_id", null: false
    t.text "reviewer", null: false
    t.text "result", null: false
    t.text "reason"
    t.bigint "product_id"
    t.bigint "displaced_seller_item_id"
    t.bigint "declined_seller_item_id"
    t.datetime "decided_at", null: false
    t.index ["declined_seller_item_id"], name: "index_intake_review_decisions_on_declined_seller_item_id"
    t.index ["displaced_seller_item_id"], name: "index_intake_review_decisions_on_displaced_seller_item_id"
    t.index ["product_id"], name: "index_intake_review_decisions_on_product_id"
    t.index ["review_case_id"], name: "index_intake_review_decisions_on_review_case_id", unique: true
    t.check_constraint "(result = 'kept_existing'::text) = (declined_seller_item_id IS NOT NULL)", name: "intake_review_decisions_declined_matches_result"
    t.check_constraint "product_id IS NOT NULL", name: "intake_review_decisions_result_has_product"
    t.check_constraint "result = ANY (ARRAY['linked'::text, 'created'::text, 'kept_existing'::text])", name: "intake_review_decisions_result_valid"
    t.check_constraint "reviewer ~ '[^[:space:]]'::text", name: "intake_review_decisions_reviewer_not_blank"
  end

  create_table "intake_review_rejections", force: :cascade do |t|
    t.bigint "review_candidate_id", null: false
    t.text "reviewer", null: false
    t.text "reason", null: false
    t.datetime "rejected_at", null: false
    t.index ["review_candidate_id"], name: "index_intake_review_rejections_on_review_candidate_id", unique: true
    t.check_constraint "reviewer ~ '[^[:space:]]'::text AND reason ~ '[^[:space:]]'::text", name: "intake_review_rejections_required_text"
  end

  create_table "intake_row_results", force: :cascade do |t|
    t.bigint "batch_id", null: false
    t.integer "source_position", null: false
    t.text "input_json", null: false
    t.text "seller_name"
    t.text "seller_product_id"
    t.text "outcome", null: false
    t.text "reason", null: false
    t.jsonb "validation_errors", default: [], null: false
    t.bigint "product_id"
    t.bigint "review_case_id"
    t.datetime "created_at", null: false
    t.index ["batch_id", "source_position"], name: "index_intake_row_results_on_batch_position", unique: true
    t.index ["product_id"], name: "index_intake_row_results_on_product_id"
    t.index ["review_case_id"], name: "index_intake_row_results_on_review_case_id"
    t.index ["seller_name", "seller_product_id"], name: "index_intake_row_results_on_seller_key"
    t.check_constraint "(seller_name IS NULL) = (seller_product_id IS NULL)", name: "intake_row_results_key_pair_complete"
    t.check_constraint "input_json IS JSON", name: "intake_row_results_input_valid_json"
    t.check_constraint "outcome <> 'pending_review'::text OR review_case_id IS NOT NULL", name: "intake_row_results_pending_has_case"
    t.check_constraint "outcome = ANY (ARRAY['linked'::text, 'created'::text, 'already_imported'::text, 'pending_review'::text, 'failed'::text])", name: "intake_row_results_outcome_valid"
    t.check_constraint "reason ~ '[^[:space:]]'::text", name: "intake_row_results_reason_not_blank"
    t.check_constraint "source_position >= 1", name: "intake_row_results_position_positive"
  end

  create_table "intake_seller_items", force: :cascade do |t|
    t.text "seller_name", null: false
    t.text "seller_product_id", null: false
    t.jsonb "active_source_input", null: false
    t.jsonb "active_source_comparison", null: false
    t.text "resolution", null: false
    t.bigint "product_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_intake_seller_items_on_product_id"
    t.index ["seller_name", "seller_product_id"], name: "index_intake_seller_items_on_exact_key", unique: true
    t.check_constraint "resolution = 'pending'::text OR (resolution = ANY (ARRAY['linked'::text, 'created'::text])) AND product_id IS NOT NULL OR (resolution = ANY (ARRAY['declined'::text, 'displaced'::text])) AND product_id IS NULL", name: "intake_seller_items_product_matches_resolution"
    t.check_constraint "resolution = ANY (ARRAY['pending'::text, 'linked'::text, 'created'::text, 'declined'::text, 'displaced'::text])", name: "intake_seller_items_resolution_valid"
    t.check_constraint "seller_name ~ '[^[:space:]]'::text", name: "intake_seller_items_name_not_blank"
    t.check_constraint "seller_product_id ~ '[^[:space:]]'::text", name: "intake_seller_items_id_not_blank"
  end

  create_table "products", force: :cascade do |t|
    t.text "name", null: false
    t.text "brand"
    t.text "category"
    t.check_constraint "name ~ '[^[:space:]]'::text", name: "products_name_not_blank"
  end

  create_table "seller_products", force: :cascade do |t|
    t.text "seller_name", null: false
    t.text "seller_product_id", null: false
    t.bigint "product_id", null: false
    t.index ["product_id"], name: "index_seller_products_on_product_id"
    t.index ["seller_name", "product_id"], name: "index_seller_products_on_seller_and_product", unique: true
    t.index ["seller_name", "seller_product_id"], name: "index_seller_products_on_seller_identity", unique: true
    t.check_constraint "seller_name ~ '[^[:space:]]'::text", name: "seller_products_seller_name_not_blank"
    t.check_constraint "seller_product_id ~ '[^[:space:]]'::text", name: "seller_products_seller_product_id_not_blank"
  end

  add_foreign_key "intake_review_candidates", "intake_review_cases", column: "review_case_id"
  add_foreign_key "intake_review_candidates", "products"
  add_foreign_key "intake_review_cases", "intake_batches", column: "batch_id"
  add_foreign_key "intake_review_cases", "intake_seller_items", column: "seller_item_id"
  add_foreign_key "intake_review_corrections", "intake_review_cases", column: "review_case_id"
  add_foreign_key "intake_review_decisions", "intake_review_cases", column: "review_case_id"
  add_foreign_key "intake_review_decisions", "intake_seller_items", column: "declined_seller_item_id"
  add_foreign_key "intake_review_decisions", "intake_seller_items", column: "displaced_seller_item_id"
  add_foreign_key "intake_review_decisions", "products"
  add_foreign_key "intake_review_rejections", "intake_review_candidates", column: "review_candidate_id"
  add_foreign_key "intake_row_results", "intake_batches", column: "batch_id"
  add_foreign_key "intake_row_results", "intake_review_cases", column: "review_case_id"
  add_foreign_key "intake_row_results", "products"
  add_foreign_key "intake_seller_items", "products"
  add_foreign_key "seller_products", "products"
end
