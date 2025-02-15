class ArticleTag < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  has_many :article_to_tag_relations, dependent: :destroy
  has_many :articles, through: :article_to_tag_relations
end
