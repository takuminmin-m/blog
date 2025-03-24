class ImagesController < ApplicationController
  def show
    redirect_to Picture.all[0].image.url
  end
end
