class Article < ApplicationRecord
  validates :title, presence: true, uniqueness: true
  validates :filename, presence: true, uniqueness: true

  has_many :article_to_tag_relations, dependent: :destroy
  has_many :article_tags, through: :article_to_tag_relations
end
