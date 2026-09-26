class StaticPagesController < ApplicationController
  def index
    @articles = Article.newest_first.limit(10)
  end

  def about
    @about = MarkdownDocument.read(Rails.configuration.x.content_root.join("static_pages/about.md"))
  end
end
