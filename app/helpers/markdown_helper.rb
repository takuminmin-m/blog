module MarkdownHelper
  require "redcarpet"
    require "redcarpet/render_strip"

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

      Redcarpet::Markdown.new(renderer, extensions).render(text).html_safe
    end
end
