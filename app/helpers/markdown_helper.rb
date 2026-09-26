module MarkdownHelper
  require "redcarpet"

  # Articles reference their images as images/<filename>, relative to the Markdown file so
  # editors and GitHub preview them. On the site that becomes the Picture's watermarked
  # :article variant; the original has no watermark, so it's never linked. Any other image
  # keeps its src.
  class Renderer < Redcarpet::Render::HTML
    def initialize(view, options)
      super(options)
      @view = view
    end

    def image(link, title, alt_text)
      picture = Picture.find_by(filename: link.delete_prefix("images/"), artwork: false) if link.start_with?("images/")
      src = picture ? @view.url_for(picture.image.variant(:article)) : link

      @view.tag.img(src: src, alt: alt_text, title: title, loading: "lazy")
    end
  end

  # Renders a Markdown body (front matter already removed, see MarkdownDocument).
  def markdown(text)
    render_options = {
      filter_html: true,
      hard_wrap: true,
      link_attributes: { rel: "nofollow", target: "_blank" },
      space_after_headers: true,
      fenced_code_blocks: true
    }

    renderer = Renderer.new(self, render_options)

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
