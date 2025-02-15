class CreateArticleToTagRelations < ActiveRecord::Migration[8.0]
  def change
    create_table :article_to_tag_relations do |t|
      t.references :article, null: false, foreign_key: true
      t.references :article_tag, null: false, foreign_key: true

      t.timestamps
    end
  end
end
