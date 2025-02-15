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
end

# TODO: implement this
# def sync_pictures
# end

namespace :contents do
  desc "Sync contents with database"

  task sync: :environment do
    sync_articles
    # sync_pictures
  end

  task sync_articles: :environment do
    sync_articles
  end

  task sync_pictures: :environment do
    # sync_pictures
  end
end
