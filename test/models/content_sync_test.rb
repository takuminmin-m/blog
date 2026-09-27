require "test_helper"

class ContentSyncTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "sync_articles creates and updates articles from their front matter" do
    articles(:second_post).destroy
    articles(:hello_world).update!(title: "Stale title", published_on: "2020-01-01", article_tags: [ article_tags(:ruby) ])

    assert_difference "Article.count", 1 do
      ContentSync.new.sync_articles
    end

    hello_world = articles(:hello_world).reload
    assert_equal "Hello, world", hello_world.title
    assert_equal Date.new(2026, 9, 1), hello_world.published_on
    assert_equal %w[ rails ruby ], hello_world.article_tags.pluck(:name).sort

    second_post = Article.find_by!(filename: "second-post")
    assert_equal "Second post", second_post.title
    assert_equal Date.new(2026, 9, 15), second_post.published_on
    assert_equal %w[ rails ], second_post.article_tags.pluck(:name)
  end

  test "an invalid article stops the sync, names its file, and changes nothing" do
    with_content_copy do |root|
      second_post = root.join("articles/second-post.md")
      second_post.write(second_post.read.sub(/^date: .*\n/, ""))
      articles(:hello_world).update!(title: "Stale title")

      error = assert_raises(ContentSync::InvalidArticle) { ContentSync.new(root).sync_articles }

      assert_equal "articles/second-post.md: Date can't be blank", error.message
      assert_equal "Stale title", articles(:hello_world).reload.title
    end
  end

  test "sync_articles deletes articles whose files are gone and tags no article uses" do
    Article.create!(filename: "deleted-post", title: "Deleted post", published_on: Date.current,
      article_tags: [ ArticleTag.create!(name: "drafts") ])

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

  test "pictures get the details from their EXIF" do
    ContentSync.new.sync_gallery

    sunset = Picture.find_by!(filename: "sunset.jpg")
    assert_equal Time.utc(2026, 9, 1, 18, 30, 15), sunset.taken_at
    assert_equal [ "Canon EOS R6", "RF50mm F1.8 STM", 50.0, 2.8, 0.004, 400 ],
      sunset.values_at(:camera, :lens, :focal_length, :f_number, :exposure_time, :iso)
    assert_nil Picture.find_by!(filename: "artwork.png").camera
  end

  test "EXIF details are read again without attaching unchanged images again" do
    ContentSync.new.sync
    Picture.find_by!(filename: "sunset.jpg").update!(camera: nil, taken_at: nil)

    assert_no_enqueued_jobs only: ActiveStorage::TransformJob do
      ContentSync.new.sync
    end
    sunset = Picture.find_by!(filename: "sunset.jpg")
    assert_equal "Canon EOS R6", sunset.camera
    assert_equal Time.utc(2026, 9, 1, 18, 30, 15), sunset.taken_at
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
end
