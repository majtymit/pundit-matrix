# frozen_string_literal: true

ActiveRecord::Migration.verbose = false

ActiveRecord::Schema.define do
  create_table :users do |t|
    t.string :email, null: false
  end
end

migration = File.expand_path('../../lib/generators/pundit/matrix/install/templates/create_pundit_matrix_tables.rb.tt',
                             __dir__)
eval( # rubocop:disable Security/Eval
  ERB.new(File.read(migration), trim_mode: '-').result_with_hash(
    migration_version: ActiveRecord::Migration.current_version,
    table_prefix: '',
    primary_key_type: nil,
    subject_id_type: nil
  )
)
CreatePunditMatrixTables.migrate(:up)
