require "test_helper"

class MarkdownHelperTest < ActionView::TestCase
  test "renders Markdown and strips raw HTML" do
    html = markdown("**bold** <script>alert(1)</script>")

    assert_includes html, "<strong>bold</strong>"
    assert_not_includes html, "<script>"
  end

  test "fenced code blocks are highlighted for their language" do
    code = Nokogiri::HTML5.fragment(markdown("```ruby\ndef greet\nend\n```\n")).at("pre.highlight.ruby code")

    assert code, "expected a highlighted Ruby block"
    assert_equal "def", code.at("span.k").text
  end

  test "code blocks without a known language stay plain text, escaped" do
    html = markdown("```\n<script>alert(1)</script>\n```\n")

    assert_includes html, %(<pre class="highlight plaintext">)
    assert_includes html, "&lt;script&gt;"
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
