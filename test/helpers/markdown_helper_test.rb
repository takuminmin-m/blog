require "test_helper"

class MarkdownHelperTest < ActionView::TestCase
  test "renders Markdown and strips raw HTML" do
    html = markdown("**bold** <script>alert(1)</script>")

    assert_includes html, "<strong>bold</strong>"
    assert_not_includes html, "<script>"
  end
end
