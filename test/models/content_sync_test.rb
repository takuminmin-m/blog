require "test_helper"

class ContentSyncTest < ActiveSupport::TestCase
  test "sync_articles creates and updates articles from their front matter" do
    articles(:hello_world).update!(title: "Stale title", article_tags: [ article_tags(:ruby) ])

    assert_difference "Article.count", 1 do
      ContentSync.new.sync_articles
    end

    hello_world = articles(:hello_world).reload
    assert_equal "Hello, world", hello_world.title
    assert_equal %w[ rails ruby ], hello_world.article_tags.pluck(:name).sort

    second_post = Article.find_by!(filename: "second-post")
    assert_equal "Second post", second_post.title
    assert_equal %w[ rails ], second_post.article_tags.pluck(:name)
  end

  test "sync_articles attaches article images as pictures that aren't artwork" do
    ContentSync.new.sync_articles

    picture = Picture.find_by!(filename: "photo.png")
    assert_not picture.artwork?
    assert picture.image.attached?
  end

  test "sync_gallery attaches gallery images as artwork" do
    ContentSync.new.sync_gallery

    picture = Picture.find_by!(filename: "artwork.png")
    assert picture.artwork?
    assert picture.image.attached?
  end

  test "syncing again doesn't duplicate rows" do
    ContentSync.new.sync

    assert_no_difference [ "Article.count", "ArticleTag.count", "ArticleToTagRelation.count", "Picture.count" ] do
      ContentSync.new.sync
    end
  end
end
