require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  test "index links to each article" do
    get articles_url
    assert_response :success
    assert_select "a[href=?]", article_path("hello-world"), text: "Hello, world"
  end

  test "show renders the article's Markdown file with its tags" do
    get article_url("hello-world")
    assert_response :success
    assert_select "h1", "Hello, world"
    assert_select "a[href=?]", article_tag_path("ruby"), text: "ruby"
    assert_select "h2", "First post"
    assert_select "strong", "Markdown"
  end
end
