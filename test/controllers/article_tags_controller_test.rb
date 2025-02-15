require "test_helper"

class ArticleTagControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get article_tag_show_url
    assert_response :success
  end
end
