require "test_helper"

class StaticPagesControllerTest < ActionDispatch::IntegrationTest
  test "index lists recent articles newest first under the site name" do
    get root_url
    assert_response :success
    assert_select "title", "takuminmin-m"
    assert_equal [ article_path("second-post"), article_path("hello-world") ], css_select("main a[href^='/articles/']").pluck("href")
  end

  test "index introduces the site with static_pages/index.md, which also describes the page" do
    get root_url
    assert_select "h1", "takuminmin-m"
    assert_select "section .prose strong", "Ruby"
    assert_select "main a[href=?]", about_path, "About →"
    assert_select "meta[name=description][content=?]", "Notes on Ruby, things I make, and photos."
  end

  test "index goes without the introduction when static_pages/index.md is missing" do
    Dir.mktmpdir do |dir|
      FileUtils.cp_r(Rails.configuration.x.content_root.children, dir)
      FileUtils.rm(File.join(dir, "static_pages/index.md"))
      with_content_root(Pathname(dir)) { get root_url }
    end

    assert_response :success
    assert_select ".prose", count: 0
    assert_select "meta[name=description]", count: 0
  end

  test "index shows the newest #{StaticPagesController::RECENT_ARTWORKS} artworks, linking to the gallery" do
    ContentSync.new.sync
    image = Picture.find_by!(filename: "sunset.jpg").image.blob
    %w[ 2026-01-01 2026-02-01 2026-03-01 2026-04-01 ].each { |name| Picture.create!(filename: "#{name}.jpg", artwork: true, image: image) }
    Picture.create!(filename: "zzz-article-image.jpg", artwork: false, image: image)

    get root_url
    assert_equal %w[ sunset artwork 2026-04-01 2026-03-01 ], css_select("main a[href='#{artworks_path}'] img").pluck("alt")
    assert_select "main a[href=?]", artworks_path, text: "Gallery →"
  end

  test "index has no photos section without artworks" do
    get root_url
    assert_select "h2", text: "Recent photos", count: 0
  end

  test "about renders static_pages/about.md, titled by its front matter" do
    get about_url
    assert_response :success
    assert_select "title", "About | takuminmin-m"
    assert_select "h1", "About"
    assert_select ".prose strong", "the author"
    assert_select ".prose", text: /title:/, count: 0
    assert_select "meta[name=description][content=?]", "This blog is written by the author."
  end

  private
    def with_content_root(root)
      original, Rails.configuration.x.content_root = Rails.configuration.x.content_root, root
      yield
    ensure
      Rails.configuration.x.content_root = original
    end
end
