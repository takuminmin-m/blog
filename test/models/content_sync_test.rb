require "test_helper"

class ContentSyncTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

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

  test "sync_articles deletes articles whose files are gone and tags no article uses" do
    Article.create!(filename: "deleted-post", title: "Deleted post", article_tags: [ ArticleTag.create!(name: "drafts") ])

    ContentSync.new.sync_articles

    assert_not Article.exists?(filename: "deleted-post")
    assert_not ArticleTag.exists?(name: "drafts")
  end

  test "a renamed article can keep its title" do
    articles(:hello_world).update!(filename: "hello-world-draft")

    ContentSync.new.sync_articles

    assert_equal "Hello, world", Article.find_by!(filename: "hello-world").title
    assert_not Article.exists?(filename: "hello-world-draft")
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

  test "unchanged images are left alone" do
    ContentSync.new.sync
    blob = Picture.find_by!(filename: "photo.png").image.blob

    assert_no_enqueued_jobs only: ActiveStorage::TransformJob do
      ContentSync.new.sync
    end
    assert_equal blob, Picture.find_by!(filename: "photo.png").image.blob
  end

  test "changed images are attached again" do
    with_content_copy do |root|
      ContentSync.new(root).sync
      root.join("articles/images/photo.png").binwrite(root.join("overlay.png").binread)

      assert_enqueued_jobs 2, only: ActiveStorage::TransformJob do
        ContentSync.new(root).sync
      end
    end
  end

  test "images moved into the gallery become artwork" do
    with_content_copy do |root|
      ContentSync.new(root).sync
      root.join("articles/images/photo.png").rename(root.join("gallery/photo.png"))

      ContentSync.new(root).sync

      assert Picture.find_by!(filename: "photo.png").artwork?
    end
  end

  test "pictures whose files are gone are deleted" do
    with_content_copy do |root|
      ContentSync.new(root).sync
      root.join("gallery/artwork.png").delete

      ContentSync.new(root).sync

      assert_not Picture.exists?(filename: "artwork.png")
      assert Picture.exists?(filename: "photo.png")
    end
  end

  test "a checkout without an articles directory is refused instead of emptying the database" do
    Dir.mktmpdir do |dir|
      assert_raises(ContentSync::MissingCheckout) { ContentSync.new(Pathname(dir)).sync }
    end

    assert Article.exists?(filename: "hello-world")
  end

  test "syncing again doesn't duplicate rows" do
    ContentSync.new.sync

    assert_no_difference [ "Article.count", "ArticleTag.count", "ArticleToTagRelation.count", "Picture.count" ] do
      ContentSync.new.sync
    end
  end

  private
    # A scratch copy of the fixture content for tests that change files.
    def with_content_copy
      Dir.mktmpdir do |dir|
        FileUtils.cp_r(Rails.configuration.x.content_root.children, dir)
        yield Pathname(dir)
      end
    end
end
