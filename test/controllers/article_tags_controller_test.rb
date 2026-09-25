require "test_helper"

class ArticleTagsControllerTest < ActionDispatch::IntegrationTest
  test "index links to each tag" do
    get article_tags_url
    assert_response :success
    assert_select "a[href=?]", article_tag_path("ruby"), text: "ruby"
    assert_select "a[href=?]", article_tag_path("rails"), text: "rails"
  end

  test "show links to the tag's articles" do
    get article_tag_url("ruby")
    assert_response :success
    assert_select "a[href=?]", article_path("hello-world"), text: "Hello, world"
  end
end
