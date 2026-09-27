class ArtworksController < ApplicationController
  PER_PAGE = 24

  def index
    @pagination = Pagination.new(Picture.artworks.newest_first.with_attached_image, page: params[:page], per_page: PER_PAGE)
    @artworks = @pagination.records
  end
end
