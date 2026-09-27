class ArtworksController < ApplicationController
  PER_PAGE = 24

  def index
    @pagination = Pagination.new(Picture.artworks.newest_first.with_attached_image, page: params[:page], per_page: PER_PAGE)
    @artworks = @pagination.records
  end

  def show
    @artwork = Picture.artworks.named(params.expect(:name)).first!
    # The index page it's on: its rank among the artworks, newest first, split into pages.
    @page = Picture.artworks.where(filename: @artwork.filename..).count.fdiv(PER_PAGE).ceil
  end
end
