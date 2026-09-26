require "test_helper"

class MarkdownHelperTest < ActionView::TestCase
  test "renders Markdown and strips raw HTML" do
    html = markdown("**bold** <script>alert(1)</script>")

    assert_includes html, "<strong>bold</strong>"
    assert_not_includes html, "<script>"
  end

  test "an images/ reference becomes the picture's watermarked article variant" do
    picture = Picture.create!(filename: "photo.png", artwork: false,
      image: { io: StringIO.new(file_fixture("content/articles/images/photo.png").binread), filename: "photo.png" })

    image = Nokogiri::HTML5.fragment(markdown("![A photo](images/photo.png)")).at("img")

    assert_equal url_for(picture.image.variant(:article)), image["src"]
    assert_equal "A photo", image["alt"]
    assert_equal "lazy", image["loading"]
  end

  test "images that aren't article pictures keep their src" do
    html = markdown("![Missing](images/missing.png) ![Elsewhere](https://example.com/a.png)")

    assert_equal [ "images/missing.png", "https://example.com/a.png" ], Nokogiri::HTML5.fragment(html).css("img").pluck("src")
  end
end
