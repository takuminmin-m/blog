require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  test "index lists articles newest first with their dates" do
    get articles_url
    assert_response :success
    assert_select "title", "Articles | Blog"
    assert_equal [ article_path("second-post"), article_path("hello-world") ], article_links
    assert_select "a[href=?]", article_path("hello-world"), text: "Hello, world"
    assert_select "time[datetime=?]", "2026-09-15", text: "2026-09-15"
  end

  test "show renders the article's Markdown file with its date and tags" do
    get article_url("hello-world")
    assert_response :success
    assert_select "title", "Hello, world | Blog"
    assert_select "h1", "Hello, world"
    assert_select "time[datetime=?]", "2026-09-01", text: "2026-09-01"
    assert_select "a[href=?]", article_tag_path("ruby"), text: "#ruby"
    assert_select ".prose h2", "First post"
    assert_select ".prose strong", "Markdown"
  end

  test "show marks the articles section as current in the navigation" do
    get article_url("hello-world")
    assert_select "nav a[aria-current=page]", "Articles"
  end

  test "show describes the article for link previews" do
    get article_url("hello-world")
    assert_select "meta[property='og:title'][content=?]", "Hello, world"
    assert_select "meta[property='og:type'][content=?]", "article"
    assert_select "meta[property='og:url'][content=?]", article_url("hello-world")
    assert_select "meta[name=description][content=?]", "First post Written in Markdown."
    assert_select "meta[property='og:image']", count: 0
    assert_select "meta[name='twitter:card'][content=?]", "summary"
  end

  test "show previews the first article image once it's synced" do
    ContentSync.new.sync_articles
    picture = Picture.find_by!(filename: "photo.png")

    get article_url("hello-world")
    assert_select "meta[property='og:image'][content=?]", polymorphic_url(picture.image.variant(:article))
    assert_select "meta[name='twitter:card'][content=?]", "summary_large_image"
  end

  test "show serves the article's images as watermarked variants" do
    require "vips" # needs libvips installed
    ContentSync.new.sync_articles

    get article_url("hello-world")
    src = css_select("img[alt='A white photo']").first["src"]
    get src
    follow_redirect!

    assert_response :success
    image = Vips::Image.new_from_buffer(response.body, "")
    assert_equal [ 800, 600 ], [ image.width, image.height ], "resize_to_limit doesn't upscale"
    assert_equal [ 255, 0, 0 ], image.getpoint(image.width - 1, image.height - 1).first(3), "overlay pixel"
  end

  test "show responds 404 to an unknown article" do
    get article_url("no-such-post")
    assert_response :not_found
  end

  private
    def article_links
      css_select("main a[href^='/articles/']").pluck("href")
    end
end
