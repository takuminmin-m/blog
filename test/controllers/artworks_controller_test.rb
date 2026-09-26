require "test_helper"

class ArtworksControllerTest < ActionDispatch::IntegrationTest
  test "index shows gallery thumbnails linking to the full watermarked variant" do
    ContentSync.new.sync
    artwork = Picture.find_by!(filename: "artwork.png")

    get artworks_url
    assert_response :success

    assert_select "a[href=?] img[alt=?]", polymorphic_path(artwork.image.variant(:gallery)), "artwork" do |images|
      assert_equal polymorphic_path(artwork.image.variant(:gallery_thumb)), images.first["src"]
    end
  end

  test "index leaves out article images" do
    ContentSync.new.sync

    get artworks_url
    assert_select "img[alt=?]", "photo", count: 0
  end
end
