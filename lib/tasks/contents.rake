# TODO: implement update article function
def sync_articles
  dir = Rails.root.join("content/articles")
  Dir.glob("#{dir}/*.md") do |file|
    filename = File.basename(file, ".md")

    article = Article.find_or_initialize_by(filename: filename)
    article.title = filename
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
