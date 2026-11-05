# frozen_string_literal: true

# Admin-managed participant groups (plan U5, tender D2/D4): organization-scoped groups, their
# members and the alerts sent to them. See lib/cct/groups.rb.
class CreateCctGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :cct_groups do |t|
      t.references :decidim_organization, null: false, index: false,
                                          foreign_key: { to_table: :decidim_organizations, on_delete: :cascade }
      t.string :slug, null: false
      t.jsonb :name, null: false, default: {}
      t.jsonb :description, null: false, default: {}
      # Demo groups created by `cct:seed` (removed by `cct:seed:reset_demo_content`).
      t.boolean :seeded, null: false, default: false
      t.timestamps
    end
    add_index :cct_groups, [:decidim_organization_id, :slug], unique: true

    create_table :cct_group_memberships do |t|
      t.references :cct_group, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :decidim_user, null: false, index: true,
                                  foreign_key: { to_table: :decidim_users, on_delete: :cascade }
      t.timestamps
    end
    add_index :cct_group_memberships, [:cct_group_id, :decidim_user_id], unique: true

    create_table :cct_group_alerts do |t|
      t.references :decidim_organization, null: false, index: false,
                                          foreign_key: { to_table: :decidim_organizations, on_delete: :cascade }
      t.references :cct_group, null: true, index: true, foreign_key: { on_delete: :nullify }
      t.references :decidim_author, null: true, index: false, foreign_key: { to_table: :decidim_users, on_delete: :nullify }
      t.references :participatory_space, polymorphic: true, null: false, index: false
      # Plain text, rendered escaped.
      t.text :message
      # One token per alert form: a resubmitted form never sends twice.
      t.string :token, null: false
      t.integer :recipients_count, null: false, default: 0
      t.timestamps
    end
    add_index :cct_group_alerts, [:decidim_organization_id, :token], unique: true
  end
end
