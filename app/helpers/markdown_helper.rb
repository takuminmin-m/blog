module MarkdownHelper
  require "redcarpet"
  require "redcarpet/render_strip"

  # Renders a Markdown body (front matter already removed, see MarkdownDocument).
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
      superscript: true
    }

    # filter_html strips any raw HTML from the Markdown, so the output is safe to mark as such.
    Redcarpet::Markdown.new(renderer, extensions).render(text).html_safe # rubocop:disable Rails/OutputSafety
  end
end
