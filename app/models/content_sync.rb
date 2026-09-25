# Imports the content repository checkout into the database: Article rows keyed by filename
# with title and tags from front matter, and a Picture for every image. Rows are upserted,
# never deleted.
class ContentSync
  IMAGES = "*.{jpg,JPG,jpeg,JPEG,png,PNG}"

  def initialize(root = Rails.configuration.x.content_root)
    @root = root
  end

  def sync
    sync_articles
    sync_gallery
  end

  def sync_articles
    @root.join("articles").glob("*.md").each do |path|
      front_matter = MarkdownDocument.read(path).front_matter

      article = Article.find_or_initialize_by(filename: path.basename(".md").to_s)
      article.title = front_matter["title"]
      article.article_tags = Array(front_matter["tags"]).map { |name| ArticleTag.find_or_create_by!(name: name) }
      article.save!
    end

    sync_pictures @root.join("articles/images"), artwork: false
  end

  def sync_gallery
    sync_pictures @root.join("gallery"), artwork: true
  end

  private
    def sync_pictures(dir, artwork:)
      dir.glob(IMAGES).each do |path|
        picture = Picture.find_or_initialize_by(filename: path.basename.to_s)
        picture.artwork = artwork

        path.open do |io|
          picture.image.attach(io: io, filename: picture.filename)
          picture.save!
        end
      end
    end
end
