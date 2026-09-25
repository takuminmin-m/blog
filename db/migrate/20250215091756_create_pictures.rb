class CreatePictures < ActiveRecord::Migration[8.0]
  def change
    create_table :pictures do |t|
      t.string :filename, null: false
      t.boolean :artwork, null: false # rubocop:disable Rails/ThreeStateBooleanColumn -- no default on purpose: ContentSync always sets it
      t.text :description

      t.timestamps
    end

    add_index :pictures, :filename, unique: true
  end
end
