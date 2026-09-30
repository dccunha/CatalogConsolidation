class CreateIntakePersistence < ActiveRecord::Migration[8.1]
  def change
    create_table :intake_batches do |t|
      t.text :source_name, null: false
      t.integer :input_count, null: false
      t.datetime :created_at, null: false
      t.check_constraint "source_name ~ '[^[:space:]]'", name: "intake_batches_source_name_not_blank"
      t.check_constraint "input_count >= 0", name: "intake_batches_input_count_nonnegative"
    end

    create_table :intake_seller_items do |t|
      t.text :seller_name, null: false
      t.text :seller_product_id, null: false
      t.jsonb :active_source_input, null: false
      t.jsonb :active_source_comparison, null: false
      t.text :resolution, null: false
      t.references :product, foreign_key: { to_table: :products }, index: true
      t.timestamps
      t.check_constraint "seller_name ~ '[^[:space:]]'", name: "intake_seller_items_name_not_blank"
      t.check_constraint "seller_product_id ~ '[^[:space:]]'", name: "intake_seller_items_id_not_blank"
      t.check_constraint "resolution IN ('pending', 'linked', 'created', 'declined', 'displaced')",
        name: "intake_seller_items_resolution_valid"
      t.check_constraint "resolution = 'pending' OR " \
        "(resolution IN ('linked', 'created') AND product_id IS NOT NULL) OR " \
        "(resolution IN ('declined', 'displaced') AND product_id IS NULL)",
        name: "intake_seller_items_product_matches_resolution"
      t.index [ :seller_name, :seller_product_id ], unique: true, name: "index_intake_seller_items_on_exact_key"
    end

    create_table :intake_review_cases do |t|
      t.references :seller_item, null: false, foreign_key: { to_table: :intake_seller_items }
      t.references :batch, null: false, foreign_key: { to_table: :intake_batches }, index: false
      t.integer :source_position, null: false
      t.text :status, null: false
      t.text :reason, null: false
      t.jsonb :source_input, null: false
      t.jsonb :source_comparison, null: false
      t.integer :evidence_revision, null: false, default: 0
      t.jsonb :conflicting_association
      t.timestamps
      t.check_constraint "source_position >= 1", name: "intake_review_cases_position_positive"
      t.check_constraint "status IN ('pending', 'resolved', 'superseded')", name: "intake_review_cases_status_valid"
      t.check_constraint "reason ~ '[^[:space:]]'", name: "intake_review_cases_reason_not_blank"
      t.check_constraint "evidence_revision >= 0", name: "intake_review_cases_revision_nonnegative"
      t.index :seller_item_id, unique: true, where: "status IN ('pending', 'resolved')",
        name: "index_intake_review_cases_on_active_seller_item"
      t.index [ :batch_id, :status ], name: "index_intake_review_cases_on_batch_and_status"
    end

    create_table :intake_row_results do |t|
      t.references :batch, null: false, foreign_key: { to_table: :intake_batches }, index: false
      t.integer :source_position, null: false
      t.text :input_json, null: false
      t.text :seller_name
      t.text :seller_product_id
      t.text :outcome, null: false
      t.text :reason, null: false
      t.jsonb :validation_errors, null: false, default: []
      t.references :product, foreign_key: { to_table: :products }, index: true
      t.references :review_case, foreign_key: { to_table: :intake_review_cases }, index: true
      t.datetime :created_at, null: false
      t.check_constraint "source_position >= 1", name: "intake_row_results_position_positive"
      t.check_constraint "input_json::jsonb IS NOT NULL", name: "intake_row_results_input_valid_json"
      t.check_constraint "outcome IN ('linked', 'created', 'already_imported', 'pending_review', 'failed')",
        name: "intake_row_results_outcome_valid"
      t.check_constraint "reason ~ '[^[:space:]]'", name: "intake_row_results_reason_not_blank"
      t.check_constraint "(seller_name IS NULL) = (seller_product_id IS NULL)",
        name: "intake_row_results_key_pair_complete"
      t.check_constraint "outcome <> 'pending_review' OR review_case_id IS NOT NULL",
        name: "intake_row_results_pending_has_case"
      t.index [ :batch_id, :source_position ], unique: true, name: "index_intake_row_results_on_batch_position"
      t.index [ :seller_name, :seller_product_id ], name: "index_intake_row_results_on_seller_key"
    end

    create_table :intake_review_candidates do |t|
      t.references :review_case, null: false, foreign_key: { to_table: :intake_review_cases }, index: false
      t.references :product, null: false, foreign_key: { to_table: :products }
      t.integer :evidence_revision, null: false
      t.integer :rank, null: false
      t.decimal :score, precision: 8, scale: 7, null: false
      t.jsonb :original, null: false
      t.jsonb :comparison, null: false
      t.jsonb :differing_fields, null: false, default: []
      t.jsonb :conflicting_association
      t.datetime :created_at, null: false
      t.check_constraint "evidence_revision >= 1 AND rank >= 1", name: "intake_review_candidates_positive_order"
      t.check_constraint "score >= 0 AND score <= 1", name: "intake_review_candidates_score_range"
      t.index [ :review_case_id, :evidence_revision, :rank ], unique: true,
        name: "index_intake_review_candidates_on_case_revision_rank"
      t.index [ :review_case_id, :evidence_revision, :product_id ], unique: true,
        name: "index_intake_review_candidates_on_case_revision_product"
    end

    create_table :intake_review_rejections do |t|
      t.references :review_candidate, null: false, foreign_key: { to_table: :intake_review_candidates }, index: { unique: true }
      t.text :reviewer, null: false
      t.text :reason, null: false
      t.datetime :rejected_at, null: false
      t.check_constraint "reviewer ~ '[^[:space:]]' AND reason ~ '[^[:space:]]'",
        name: "intake_review_rejections_required_text"
    end

    create_table :intake_review_corrections do |t|
      t.references :review_case, null: false, foreign_key: { to_table: :intake_review_cases }, index: false
      t.text :reviewer, null: false
      t.jsonb :corrected_input, null: false
      t.jsonb :corrected_comparison, null: false
      t.datetime :corrected_at, null: false
      t.check_constraint "reviewer ~ '[^[:space:]]'", name: "intake_review_corrections_reviewer_not_blank"
      t.index [ :review_case_id, :corrected_at, :id ], name: "index_intake_review_corrections_on_case_time"
    end

    create_table :intake_review_decisions do |t|
      t.references :review_case, null: false, foreign_key: { to_table: :intake_review_cases }, index: { unique: true }
      t.text :reviewer, null: false
      t.text :result, null: false
      t.text :reason
      t.references :product, foreign_key: { to_table: :products }
      t.references :displaced_seller_item, foreign_key: { to_table: :intake_seller_items }
      t.references :declined_seller_item, foreign_key: { to_table: :intake_seller_items }
      t.datetime :decided_at, null: false
      t.check_constraint "reviewer ~ '[^[:space:]]'", name: "intake_review_decisions_reviewer_not_blank"
      t.check_constraint "result IN ('linked', 'created', 'kept_existing')", name: "intake_review_decisions_result_valid"
      t.check_constraint "(result = 'kept_existing') = (declined_seller_item_id IS NOT NULL)",
        name: "intake_review_decisions_declined_matches_result"
      t.check_constraint "product_id IS NOT NULL",
        name: "intake_review_decisions_result_has_product"
    end
  end
end
