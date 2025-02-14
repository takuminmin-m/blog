class ArticleTag < ApplicationRecord
  validates :name, presence: true, uniqueness: true
end
