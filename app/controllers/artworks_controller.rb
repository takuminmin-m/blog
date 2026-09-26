class ArtworksController < ApplicationController
  def index
    # Newest first for date-prefixed or camera-numbered filenames.
    @artworks = Picture.artworks.order(filename: :desc).with_attached_image
  end
end
