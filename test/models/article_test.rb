require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  test "filename must not contain path separators" do
    [ "../secrets", "nested/post", "..\\secrets" ].each do |filename|
      article = Article.new(title: "Escape", filename: filename)
      assert_not article.valid?, "#{filename.inspect} should be invalid"
      assert_includes article.errors[:filename], "is invalid"
    end
  end

  test "body is the article's Markdown file without its front matter" do
    assert_equal "## First post\n\nWritten in **Markdown**.\n", articles(:hello_world).body
  end
end
