require "test_helper"

class ArtworksControllerTest < ActionDispatch::IntegrationTest
  # The link still works without JavaScript; with it, the thumbnail opens a lightbox instead.
  test "index shows gallery thumbnails linking to the artwork's page" do
    ContentSync.new.sync
    artwork = Picture.find_by!(filename: "artwork.png")

    get artworks_url
    assert_response :success

    assert_select "li##{dom_id(artwork)} a[href=?] img[alt=?]", "/gallery/artwork", "artwork" do |images|
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

  test "an artwork's page shows the larger variant with its EXIF, and previews it when shared" do
    ContentSync.new.sync
    sunset = Picture.find_by!(filename: "sunset.jpg")
    gallery_variant = sunset.image.variant(:gallery)

    get artwork_url("sunset")
    assert_response :success

    assert_select "title", "sunset | takuminmin-m"
    assert_select "h1", "sunset"
    assert_select "article img[alt=sunset][src=?]", polymorphic_path(gallery_variant)
    assert_select "article dd", "Canon EOS R6"
    assert_select "meta[property='og:url'][content=?]", "http://www.example.com/gallery/sunset"
    assert_select "meta[property='og:image'][content=?]", polymorphic_url(gallery_variant)
    assert_select "meta[name='twitter:card'][content=summary_large_image]"
    assert_select "meta[name=description][content=?]", "2026-09-01 18:30 · Canon EOS R6 · RF50mm F1.8 STM · 50 mm · f/2.8 · 1/250 s · ISO 400"
  end

  test "an artwork without EXIF has no description" do
    ContentSync.new.sync

    get artwork_url("artwork")
    assert_response :success
    assert_select "article dl", count: 0
    assert_select "meta[name=description]", count: 0
  end

  test "an artwork's page links back to the gallery page it's on" do
    ContentSync.new.sync
    add_artworks ArtworksController::PER_PAGE - 1

    get artwork_url("sunset")
    assert_select "a[href=?]", "/gallery##{dom_id(Picture.find_by!(filename: "sunset.jpg"))}", "‹ Gallery"

    get artwork_url("extra-00") # the first page's last
    assert_select "a[href=?]", "/gallery##{dom_id(Picture.find_by!(filename: "extra-00.jpg"))}"

    get artwork_url("artwork")
    assert_select "a[href=?]", "/gallery?page=2##{dom_id(Picture.find_by!(filename: "artwork.png"))}"
  end

  test "an artwork's name may hold dots" do
    ContentSync.new.sync
    Picture.create!(filename: "2026.09.01.JPG", artwork: true, image: Picture.find_by!(filename: "sunset.jpg").image.blob)

    get artwork_url("2026.09.01")
    assert_response :success
    assert_select "h1", "2026.09.01"
  end

  test "names that aren't an artwork's aren't found" do
    ContentSync.new.sync

    # photo.jpg is an article image, and a name is without the extension.
    %w[ nothing photo sunset.jpg ].each do |name|
      get artwork_url(name)
      assert_response :not_found, name
    end
  end

  private
    # Artworks sharing sunset.jpg's image, sorting between it and artwork.png: extra-00.jpg and on.
    def add_artworks(count)
      image = Picture.find_by!(filename: "sunset.jpg").image.blob
      count.times { |i| Picture.create!(filename: format("extra-%02d.jpg", i), artwork: true, image: image) }
    end
end
