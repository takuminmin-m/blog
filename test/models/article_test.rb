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

  test "newer and older are the neighbors in newest_first order" do
    assert_equal articles(:second_post), articles(:hello_world).newer
    assert_nil articles(:hello_world).older
    assert_equal articles(:hello_world), articles(:second_post).older
    assert_nil articles(:second_post).newer
  end

  test "newer and older break ties on the same date by id, like newest_first" do
    same_day = Article.create!(filename: "same-day", title: "Same day", published_on: articles(:hello_world).published_on)

    assert_equal [ articles(:second_post), same_day, articles(:hello_world) ], Article.newest_first.to_a
    assert_equal same_day, articles(:hello_world).newer
    assert_equal articles(:hello_world), same_day.older
    assert_equal articles(:second_post), same_day.newer
  end
end
