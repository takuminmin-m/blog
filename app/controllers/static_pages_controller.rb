class StaticPagesController < ApplicationController
  RECENT_ARTWORKS = 4

  def index
    @intro = read_static_page("index.md") if static_page_path("index.md").exist?
    @articles = Article.newest_first.limit(10)
    @artworks = Picture.artworks.newest_first.with_attached_image.limit(RECENT_ARTWORKS)
  end

  def about
    @about = read_static_page("about.md")
  end

  private
    def static_page_path(filename)
      Rails.configuration.x.content_root.join("static_pages", filename)
    end

    def read_static_page(filename)
      MarkdownDocument.read(static_page_path(filename))
    end
end
