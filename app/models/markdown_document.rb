require "redcarpet/render_strip"

# A Markdown file with an optional YAML front matter block, split the way Jekyll does it
# (jekyll/lib/jekyll/convertible.rb read_yaml).
class MarkdownDocument
  FRONT_MATTER = /\A(---\s*\n.*?\n?)^((---|\.\.\.)\s*$\n?)/m

  # Renders only the prose: link text without its URL, and no images or code blocks. (Empty
  # strings, not nil: Redcarpet treats nil as unhandled and prints the Markdown source.)
  class PlainText < Redcarpet::Render::StripDown
    def link(_link, _title, content)
      content
    end

    def image(_link, _title, _alt_text)
      ""
    end

    def block_code(_code, _language)
      ""
    end
  end

  attr_reader :front_matter, :body

  def self.read(path)
    new(File.read(path))
  end

  def initialize(text)
    if (match = FRONT_MATTER.match(text))
      @front_matter = YAML.safe_load(match[1], permitted_classes: [ Date, Time ]) || {}
      @body = match.post_match
    else
      @front_matter = {}
      @body = text
    end
  end

  # The body's prose on a single line, e.g. to summarize it.
  def plain_text
    Redcarpet::Markdown.new(PlainText, fenced_code_blocks: true).render(body).squish
  end
end
