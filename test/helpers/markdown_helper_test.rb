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

  test "a collapse option folds a code block into a details with its line count" do
    details = Nokogiri::HTML5.fragment(markdown("```js:collapse\nlet a = 1\nlet b = 2\n```\n")).at("details")

    assert_equal "Show code (2 lines)", details.at("summary").text
    assert_equal "let", details.at("pre.highlight.javascript code span.kd").text
  end

  test "code blocks without a collapse option are not folded" do
    assert_not_includes markdown("```js\nlet a = 1\n```\n"), "<details"
  end

  test "renders pipe tables" do
    table = Nokogiri::HTML5.fragment(markdown("| A | B |\n| --- | --- |\n| 1 | 2 |\n")).at("table")

    assert_equal [ "A", "B" ], table.css("th").map(&:text)
    assert_equal [ "1", "2" ], table.css("td").map(&:text)
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
