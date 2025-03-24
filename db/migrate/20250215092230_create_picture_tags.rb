class CreatePictureTags < ActiveRecord::Migration[8.0]
  def change
    create_table :picture_tags do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :picture_tags, :name, unique: true
  end
end
