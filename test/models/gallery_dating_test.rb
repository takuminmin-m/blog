require "test_helper"

class GalleryDatingTest < ActiveSupport::TestCase
  test "images named without a date get the day they were taken in front" do
    with_content_copy do |root|
      results = GalleryDating.new(root).date

      assert root.join("gallery/2026-09-01-sunset.jpg").file?
      assert_not root.join("gallery/sunset.jpg").exist?
      assert_includes results.map(&:to_s), "sunset.jpg -> 2026-09-01-sunset.jpg"
    end
  end

  test "images already named with a date are left alone" do
    with_content_copy do |root|
      root.join("gallery/sunset.jpg").rename(root.join("gallery/2020-01-01-sunset.jpg"))

      results = GalleryDating.new(root).date

      assert root.join("gallery/2020-01-01-sunset.jpg").file?
      assert_equal [ "artwork.png: no shooting date in its EXIF" ], results.map(&:to_s)
    end
  end

  test "images without a shooting date keep their names" do
    with_content_copy do |root|
      results = GalleryDating.new(root).date

      assert root.join("gallery/artwork.png").file?
      assert_includes results.map(&:to_s), "artwork.png: no shooting date in its EXIF"
    end
  end

  test "an image with the dated name already is never replaced" do
    with_content_copy do |root|
      taken = root.join("gallery/2026-09-01-sunset.jpg")
      taken.binwrite("another photo")

      results = GalleryDating.new(root).date

      assert root.join("gallery/sunset.jpg").file?
      assert_equal "another photo", taken.binread
      assert_includes results.map(&:to_s), "sunset.jpg: 2026-09-01-sunset.jpg already exists"
    end
  end
end
