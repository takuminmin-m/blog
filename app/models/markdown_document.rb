# A Markdown file with an optional YAML front matter block, split the way Jekyll does it
# (jekyll/lib/jekyll/convertible.rb read_yaml).
class MarkdownDocument
  FRONT_MATTER = /\A(---\s*\n.*?\n?)^((---|\.\.\.)\s*$\n?)/m

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
end
