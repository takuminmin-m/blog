module MarkdownHelper
  require "redcarpet"
  require "redcarpet/render_strip"

  YAML_FRONT_MATTER_REGEXP = %r!\A(---\s*\n.*?\n?)^((---|\.\.\.)\s*$\n?)!m

  def markdown(text)
    render_options = {
      filter_html: true,
      hard_wrap: true,
      link_attributes: { rel: "nofollow", target: "_blank" },
      space_after_headers: true,
      fenced_code_blocks: true
    }

    renderer = Redcarpet::Render::HTML.new(render_options)

    extensions = {
      autolink: true,
      no_intra_emphasis: true,
      fenced_code_blocks: true,
      lax_spacing: true,
      strikethrough: true,
      superscript: true,
    }

    _, body = divide_yaml_and_body(text)
    Redcarpet::Markdown.new(renderer, extensions).render(body).html_safe
  end

  def read_yaml_frontmatter(text)
    params, _ = divide_yaml_and_body(text)
    params
  end

  private
  # refer to jekyll
  # jekyll/lib/jekyll/convertible.rb read_yaml
  def divide_yaml_and_body(text)
    if text =~ YAML_FRONT_MATTER_REGEXP
      body = Regexp.last_match.post_match
      params = YAML.safe_load(Regexp.last_match(1))
    end

    return params, body
  end
end
