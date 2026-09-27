class ArtworksController < ApplicationController
  PER_PAGE = 24

  def index
    # Newest first for date-prefixed or camera-numbered filenames.
    @pagination = Pagination.new(Picture.artworks.order(filename: :desc).with_attached_image, page: params[:page], per_page: PER_PAGE)
    @artworks = @pagination.records
  end
end
