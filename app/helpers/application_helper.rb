module ApplicationHelper
  include MarkdownHelper

  def site_name
    Rails.configuration.x.site_name
  end

  # "Page | Site" when the page provides a :title, the site name alone otherwise.
  def page_title
    [ content_for(:title), site_name ].compact_blank.join(" | ")
  end

  # The current page's URL at a Pagination page, without ?page= for the first.
  def pagination_path(page, **options)
    url_for(page: (page if page > 1), **options)
  end

  # Marks the link to the section being viewed with aria-current, which the nav styles.
  def nav_link_to(name, path)
    current = request.path == path || request.path.start_with?("#{path}/")
    link_to name, path, aria: { current: ("page" if current) },
      class: "hover:text-gray-900 aria-[current=page]:font-medium aria-[current=page]:text-gray-900"
  end
end
