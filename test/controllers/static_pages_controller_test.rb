require "test_helper"

class StaticPagesControllerTest < ActionDispatch::IntegrationTest
  test "index lists recent articles newest first under the site name" do
    get root_url
    assert_response :success
    assert_select "title", "takuminmin-m"
    assert_equal [ article_path("second-post"), article_path("hello-world") ], css_select("main a[href^='/articles/']").pluck("href")
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
end
