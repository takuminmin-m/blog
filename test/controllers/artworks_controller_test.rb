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

  test "the lightbox has a slide per artwork, in gallery order, with the larger variant and the photo's EXIF" do
    ContentSync.new.sync
    sunset = Picture.find_by!(filename: "sunset.jpg")

    get artworks_url

    thumbnails = css_select("a[data-lightbox-index-param]").map { |link| [ link["data-lightbox-index-param"], link.at("img")["alt"] ] }
    assert_equal [ [ "0", "sunset" ], [ "1", "artwork" ] ], thumbnails

    sunset_slide, artwork_slide = css_select("dialog figure")
    assert_equal polymorphic_path(sunset.image.variant(:gallery)), sunset_slide.at("img")["src"]
    assert_equal({ "Taken" => "2026-09-01 18:30", "Camera" => "Canon EOS R6", "Lens" => "RF50mm F1.8 STM", "Focal length" => "50 mm",
      "Aperture" => "f/2.8", "Shutter speed" => "1/250 s", "ISO" => "400" },
      sunset_slide.css("figcaption dt").map(&:text).zip(sunset_slide.css("figcaption dd").map(&:text)).to_h)

    assert_equal "artwork", artwork_slide.at("img")["alt"]
    assert_nil artwork_slide.at("figcaption"), "a photo without EXIF has no caption"
  end

  test "an empty gallery has no lightbox" do
    get artworks_url

    assert_select "dialog", count: 0
  end

  test "index leaves out article images" do
    ContentSync.new.sync

    get artworks_url
    assert_select "img[alt=?]", "photo", count: 0
  end
end
