class CreateArticles < ActiveRecord::Migration[8.0]
  def change
    create_table :articles do |t|
      t.string :title, null: false
      t.string :filename, null: false

      t.timestamps
    end

    add_index :articles, :title, unique: true
    add_index :articles, :filename, unique: true
  end
end
