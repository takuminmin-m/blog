require "test_helper"

# Only the Active Storage routes that serve variants are drawn (config/routes.rb). Its blob routes
# would serve the original, with no watermark and all its EXIF (GPS position included), for the
# signed blob ID that every variant URL carries.
class ActiveStorageRoutesTest < ActionDispatch::IntegrationTest
  # A variant's URL changes with its image, so caches such as Cloudflare's can keep it forever.
  test "pages serve variants by proxy, cacheable by anyone forever" do
    src = thumbnail_src
    assert_match %r{/representations/proxy/}, src

    get src
    assert_response :success
    assert_not_equal file_fixture("content/gallery/artwork.png").binread, response.body, "served the original"
    assert_equal "max-age=3155695200, public, immutable", response.headers["Cache-Control"]
    assert_nil response.headers["Set-Cookie"], "Cloudflare doesn't cache a response that sets a cookie"
  end

  test "variants are also served by redirect to the disk service" do
    src = thumbnail_src
    get src
    variant = response.body

    get src.sub("/representations/proxy/", "/representations/redirect/")
    follow_redirect!
    assert_response :success
    assert_equal variant, response.body
  end

  test "an original can't be fetched with the signed blob ID from its variant's URL" do
    signed_blob_id = assert_match(%r{/representations/proxy/(?<id>[^/]+)/}, thumbnail_src)[:id]

    %w[ blobs/redirect blobs/proxy blobs ].each do |route|
      get "#{ActiveStorage.routes_prefix}/#{route}/#{signed_blob_id}/artwork.png"
      assert_response :not_found, route
    end
  end

  test "nothing can be uploaded" do
    post "#{ActiveStorage.routes_prefix}/direct_uploads", as: :json, params: {
      blob: { filename: "upload.txt", byte_size: 5, checksum: Digest::MD5.base64digest("hello"), content_type: "text/plain" }
    }
    assert_response :not_found
  end

  private
    # A variant URL, as a page renders it: the gallery's artwork thumbnail.
    def thumbnail_src
      ContentSync.new.sync
      get artworks_url
      css_select("img[alt=artwork]").first["src"]
    end
end
