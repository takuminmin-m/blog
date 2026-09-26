class AddPublishedOnToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :published_on, :date
  end
end
