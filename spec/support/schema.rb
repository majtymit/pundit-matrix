require 'tmpdir'

ActiveRecord::Migration.verbose = false

ActiveRecord::Schema.define do
  create_table :users do |t|
    t.string :email, null: false
  end
end

template = File.expand_path('../../lib/generators/pundit/matrix/install/templates/create_pundit_matrix_tables.rb.tt',
                            __dir__)
Dir.mktmpdir do |dir|
  migration = File.join(dir, 'create_pundit_matrix_tables.rb')
  File.write(
    migration,
    ERB.new(File.read(template), trim_mode: '-').result_with_hash(
      migration_version: ActiveRecord::Migration.current_version,
      table_prefix: '',
      primary_key_type: nil,
      subject_id_type: nil
    )
  )
  load migration
end
CreatePunditMatrixTables.migrate(:up)
