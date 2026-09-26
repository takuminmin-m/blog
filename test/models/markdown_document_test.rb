require "test_helper"

class MarkdownDocumentTest < ActiveSupport::TestCase
  test "splits YAML front matter from the body" do
    document = MarkdownDocument.new("---\ntitle: Hello\ntags:\n  - ruby\n---\nBody\n")

    assert_equal({ "title" => "Hello", "tags" => [ "ruby" ] }, document.front_matter)
    assert_equal "Body\n", document.body
  end

  test "front matter can end with ..." do
    document = MarkdownDocument.new("---\ntitle: Hello\n...\nBody\n")

    assert_equal({ "title" => "Hello" }, document.front_matter)
    assert_equal "Body\n", document.body
  end

  test "front matter dates load as dates" do
    document = MarkdownDocument.new("---\ndate: 2026-09-26\n---\nBody\n")

    assert_equal Date.new(2026, 9, 26), document.front_matter["date"]
  end

  test "text without front matter is all body" do
    document = MarkdownDocument.new("Just text\n")

    assert_equal({}, document.front_matter)
    assert_equal "Just text\n", document.body
  end
end
