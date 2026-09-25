require "test_helper"

class StaticPagesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_url
    assert_response :success
  end

  test "about renders static_pages/about.md without its front matter" do
    get about_url
    assert_response :success
    assert_select ".content strong", "the author"
    assert_select ".content", text: /title:/, count: 0
  end
end
