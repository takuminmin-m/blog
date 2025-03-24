require_relative "../../app/helpers/markdown_helper.rb"
include MarkdownHelper

# TODO: implement update article function
def sync_articles
  dir = Rails.root.join("content/articles")
  Dir.glob("#{dir}/*.md") do |file|
    filename = File.basename(file, ".md")

    params = read_yaml_frontmatter(File.read("#{dir}/#{filename}.md"))
    article_tags = params["tags"].map do |article_tag|
      ArticleTag.find_or_create_by(name: article_tag)
    end

    article = Article.find_or_initialize_by(filename: filename)
    article.title = params["title"]
    article.article_tags = article_tags
    article.save!
  end

  Dir.glob("#{dir}/images/*.{jpg,JPG,jpeg,JPEG,png,PNG}") do |file|
    # avoid ActiveJob::SerializationError
    # p file.class
    filename = File.basename(file)

    picture = Picture.find_or_initialize_by(filename: filename)
    picture.image.attach(io: File.open(file), filename: filename)
    picture.artwork = false
    picture.save!
  end
end

# Sync gallery photos
# artwork? flag of Picture model is true.
def sync_gallery
  dir = Rails.root.join("content/gallery")
  Dir.glob("#{dir}/*.{jpg,JPG,jpeg,JPEG,png,PNG}") do |file|
    filename = File.basename(file)

    picture = Picture.find_or_initialize_by(filename: filename)
    picture.image.attach(io: File.open(file), filename: filename)
    picture.artwork = true
    picture.save!
  end
end

namespace :contents do
  desc "Sync contents with database"

  task sync: :environment do
    sync_articles
    sync_gallery
  end

  task sync_articles: :environment do
    sync_articles
  end

  task sync_gallery: :environment do
    sync_gallery
  end
end
