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

  test "an empty gallery has no lightbox or page links" do
    get artworks_url

    assert_response :success
    assert_select "[data-controller=lightbox]", count: 0 # its keyboard actions would find no dialog
    assert_select "nav[aria-label=Pages]", count: 0
  end

  test "the gallery shows #{ArtworksController::PER_PAGE} artworks a page, with links to the others" do
    ContentSync.new.sync
    add_artworks ArtworksController::PER_PAGE - 1

    get artworks_url
    assert_select "ul img", ArtworksController::PER_PAGE
    assert_select "nav[aria-label=Pages]" do
      assert_select "[aria-current=page]", "1"
      assert_select "a[rel=next][href=?]", "/gallery?page=2", "Older ›"
      assert_select "a[rel=prev]", count: 0
    end

    get artworks_url(page: 2)
    assert_select "ul img", 1
    assert_select "ul img[alt=?]", "artwork" # the oldest
    assert_select "nav[aria-label=Pages] a[rel=prev][href=?]", "/gallery", "‹ Newer"
  end

  test "the lightbox numbers the photos across pages and ends with links to the neighboring pages" do
    ContentSync.new.sync
    add_artworks ArtworksController::PER_PAGE - 1

    get artworks_url
    assert_select "[data-controller=lightbox][data-lightbox-offset-value=?][data-lightbox-total-value=?]", "0", Picture.artworks.count.to_s
    assert_select "dialog a[data-lightbox-target=nextPage][href=?]", "/gallery?page=2#lightbox-first"
    assert_select "dialog a[data-lightbox-target=previousPage]", count: 0

    get artworks_url(page: 2)
    assert_select "[data-controller=lightbox][data-lightbox-offset-value=?]", ArtworksController::PER_PAGE.to_s
    assert_select "dialog a[data-lightbox-target=previousPage][href=?]", "/gallery#lightbox-last"
    assert_select "dialog a[data-lightbox-target=nextPage]", count: 0
  end

  test "pages outside the gallery aren't found" do
    ContentSync.new.sync

    [ 0, 2, "two" ].each do |page|
      get artworks_url(page: page)
      assert_response :not_found, "page #{page.inspect}"
    end
  end

  test "index leaves out article images" do
    ContentSync.new.sync

    get artworks_url
    assert_select "img[alt=?]", "photo", count: 0
  end

  private
    # Artworks sharing sunset.jpg's image, sorting between it and artwork.png: extra-00.jpg and on.
    def add_artworks(count)
      image = Picture.find_by!(filename: "sunset.jpg").image.blob
      count.times { |i| Picture.create!(filename: format("extra-%02d.jpg", i), artwork: true, image: image) }
    end
end
