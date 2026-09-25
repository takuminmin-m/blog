class Article < ApplicationRecord
  validates :title, presence: true, uniqueness: true
  # filename becomes part of a file path, so it must stay a single path segment.
  validates :filename, presence: true, uniqueness: true, format: { without: %r{[/\\]} }

  has_many :article_to_tag_relations, dependent: :destroy
  has_many :article_tags, through: :article_to_tag_relations

  def body
    MarkdownDocument.read(Rails.configuration.x.content_root.join("articles/#{filename}.md")).body
  end
end
