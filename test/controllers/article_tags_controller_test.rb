require "test_helper"

class ArticleTagsControllerTest < ActionDispatch::IntegrationTest
  test "index links to each tag by name" do
    get article_tags_url
    assert_response :success
    assert_select "title", "Tags | Blog"
    assert_equal [ article_tag_path("rails"), article_tag_path("ruby") ], css_select("main a").pluck("href")
    assert_select "main a", "#ruby"
  end

  test "show lists the tag's articles newest first" do
    get article_tag_url("rails")
    assert_response :success
    assert_select "title", "#rails | Blog"
    assert_equal [ article_path("second-post"), article_path("hello-world") ], css_select("main a[href^='/articles/']").pluck("href")
  end

  test "show responds 404 to an unknown tag" do
    get article_tag_url("no-such-tag")
    assert_response :not_found
  end
end
