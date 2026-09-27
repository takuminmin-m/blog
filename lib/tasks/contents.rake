namespace :contents do
  desc "Import content/ (articles, their images, and the gallery) into the database"
  task sync: :environment do
    ContentSync.new.sync
  end

  desc "Import content/articles and content/articles/images into the database"
  task sync_articles: :environment do
    ContentSync.new.sync_articles
  end

  desc "Import content/gallery into the database"
  task sync_gallery: :environment do
    ContentSync.new.sync_gallery
  end

  desc "Put the shooting date from EXIF in front of content/gallery images named without one"
  task date_gallery: :environment do
    GalleryDating.new.date.each { |result| puts result }
  end
end
