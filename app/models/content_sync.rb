# Mirrors the content repository checkout into the database: Article rows keyed by filename
# with title and tags from front matter, and a Picture for every image. Rows whose files are
# gone are deleted, and images whose bytes haven't changed are left alone.
class ContentSync
  class MissingCheckout < StandardError; end

  IMAGES = "*.{jpg,JPG,jpeg,JPEG,png,PNG}"

  def initialize(root = Rails.configuration.x.content_root)
    @root = root
  end

  def sync
    sync_articles
    sync_gallery
  end

  def sync_articles
    ensure_checkout
    documents = @root.join("articles").glob("*.md").to_h { |path| [ path.basename(".md").to_s, MarkdownDocument.read(path) ] }

    Article.transaction do
      # Delete first, so a renamed article's title is free again before it's saved.
      Article.where.not(filename: documents.keys).destroy_all

      documents.each do |filename, document|
        article = Article.find_or_initialize_by(filename: filename)
        article.title = document.front_matter["title"]
        article.article_tags = Array(document.front_matter["tags"]).map { |name| ArticleTag.find_or_create_by!(name: name) }
        article.save!
      end

      ArticleTag.where.missing(:article_to_tag_relations).destroy_all
    end

    sync_pictures @root.join("articles/images"), artwork: false
  end

  def sync_gallery
    ensure_checkout
    sync_pictures @root.join("gallery"), artwork: true
  end

  private
    # An unmounted or uncloned checkout would look like content with nothing in it, and
    # syncing that would delete every row.
    def ensure_checkout
      raise MissingCheckout, "#{@root} has no articles directory" unless @root.join("articles").directory?
    end

    def sync_pictures(dir, artwork:)
      paths = dir.glob(IMAGES)
      Picture.where(artwork: artwork).where.not(filename: paths.map { |path| path.basename.to_s }).destroy_all

      paths.each do |path|
        picture = Picture.find_or_initialize_by(filename: path.basename.to_s)
        next if picture.artwork == artwork && same_image?(picture, path)

        picture.artwork = artwork
        path.open do |io|
          picture.image.attach(io: io, filename: picture.filename)
          picture.save!
        end
      end
    end

    # Re-attaching uploads a new blob and regenerates every preprocessed variant, so skip files
    # whose checksum (Active Storage's Base64 MD5, see Blob#compute_checksum_in_chunks) matches.
    def same_image?(picture, path)
      picture.image.attached? && picture.image.blob.checksum == OpenSSL::Digest::MD5.file(path).base64digest
    end
end
