class AttachImageJob < ApplicationJob
  queue_as :default

  def perform(path, artwork)
    filename = File.basename(path)

    picture = Picture.find_or_initialize_by(filename: filename)
    picture.image.attach(io: File.open(path), filename: filename)
    picture.artwork = artwork
    picture.save!
  end
end
