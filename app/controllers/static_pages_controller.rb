class StaticPagesController < ApplicationController
  def index
  end

  def about
    @about = MarkdownDocument.read(Rails.configuration.x.content_root.join("static_pages/about.md"))
  end
end
