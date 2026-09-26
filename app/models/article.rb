class Article < ApplicationRecord
  validates :title, presence: true, uniqueness: true
  # filename becomes part of a file path, so it must stay a single path segment.
  validates :filename, presence: true, uniqueness: true, format: { without: %r{[/\\]} }
  validates :published_on, presence: true

  has_many :article_to_tag_relations, dependent: :destroy
  has_many :article_tags, through: :article_to_tag_relations

  scope :newest_first, -> { order(published_on: :desc, id: :desc) }

  delegate :body, to: :document

  def document
    @document ||= MarkdownDocument.read(Rails.configuration.x.content_root.join("articles/#{filename}.md"))
  end

  # A short plain-text summary of the body, for link previews.
  def summary
    document.plain_text.truncate(120)
  end

  # The picture behind the body's first images/<file> image, for link previews.
  def cover_picture
    filename = body[%r{!\[[^\]]*\]\(images/([^)\s]+)}, 1]
    Picture.find_by(filename: filename, artwork: false) if filename
  end
end
