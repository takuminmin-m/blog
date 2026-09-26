require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  test "filename must not contain path separators" do
    [ "../secrets", "nested/post", "..\\secrets" ].each do |filename|
      article = Article.new(title: "Escape", filename: filename)
      assert_not article.valid?, "#{filename.inspect} should be invalid"
      assert_includes article.errors[:filename], "is invalid"
    end
  end

  test "published_on is required, reported under the front matter's name" do
    article = articles(:hello_world)
    article.published_on = nil

    assert_not article.valid?
    assert_includes article.errors.full_messages, "Date can't be blank"
  end

  test "body is the article's Markdown file without its front matter" do
    assert_equal "## First post\n\nWritten in **Markdown**.\n\n![A white photo](images/photo.png)\n", articles(:hello_world).body
  end
end
