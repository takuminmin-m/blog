class StaticPagesController < ApplicationController
  def index
  end

  def about
    @content = File.read(Rails.root.join("content/static_pages/about.md"))
  end
end
