class CreateArticleTags < ActiveRecord::Migration[8.0]
  def change
    create_table :article_tags do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :article_tags, :name, unique: true
  end
end
