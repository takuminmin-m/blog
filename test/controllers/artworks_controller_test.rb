require "test_helper"

class ArtworksControllerTest < ActionDispatch::IntegrationTest
  # The link still works without JavaScript; with it, the thumbnail opens a lightbox instead.
  test "index shows gallery thumbnails linking to the full watermarked variant" do
    ContentSync.new.sync
    artwork = Picture.find_by!(filename: "artwork.png")

    get artworks_url
    assert_response :success

    assert_select "a[href=?] img[alt=?]", polymorphic_path(artwork.image.variant(:gallery)), "artwork" do |images|
      assert_equal polymorphic_path(artwork.image.variant(:gallery_thumb)), images.first["src"]
    end
  end

  test "each thumbnail's lightbox shows the larger variant and the photo's EXIF" do
    ContentSync.new.sync
    sunset = Picture.find_by!(filename: "sunset.jpg")

    get artworks_url

    assert_select "dialog[aria-label=?]", "sunset" do
      assert_select "img[src=?]", polymorphic_path(sunset.image.variant(:gallery))
      assert_select "details summary", "Info"
      assert_select "dl" do |dl|
        details = dl.first.css("dt").map(&:text).zip(dl.first.css("dd").map(&:text)).to_h

        assert_equal({ "Taken" => "2026-09-01 18:30", "Camera" => "Canon EOS R6", "Lens" => "RF50mm F1.8 STM", "Focal length" => "50 mm",
          "Aperture" => "f/2.8", "Shutter speed" => "1/250 s", "ISO" => "400" }, details)
      end
    end
  end

  test "a lightbox has no Info toggle for a photo without EXIF" do
    ContentSync.new.sync

    get artworks_url

    assert_select "dialog[aria-label=?]", "artwork" do
      assert_select "img"
      assert_select "details", count: 0
    end
  end

  test "index leaves out article images" do
    ContentSync.new.sync

    get artworks_url
    assert_select "img[alt=?]", "photo", count: 0
  end
end
