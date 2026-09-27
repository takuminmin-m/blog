# One page of a relation's records, for index pages that link their pages as ?page=N. A page
# number outside 1..pages, or that isn't a number, raises ActiveRecord::RecordNotFound, so it's
# a 404 like any unknown key.
class Pagination
  attr_reader :page, :per_page

  def initialize(relation, page:, per_page:)
    @relation, @per_page = relation, per_page
    @page = page.blank? ? 1 : Integer(page.to_s, 10, exception: false)
    raise ActiveRecord::RecordNotFound, "No page #{page.inspect}" unless @page&.between?(1, pages)
  end

  def records
    @relation.offset(offset).limit(per_page)
  end

  # How many records come before this page's.
  def offset
    (page - 1) * per_page
  end

  # The records on all pages.
  def total
    @total ||= @relation.count
  end

  # At least one, so there's a page to show even with no records.
  def pages
    [ total.fdiv(per_page).ceil, 1 ].max
  end

  def previous_page
    page - 1 if page > 1
  end

  def next_page
    page + 1 if page < pages
  end

  # The page numbers to link, with :gap for each run left out: 1, :gap, 4, 5, 6, 7, 8, :gap, 12.
  def series
    numbers = [ 1, *((page - 2)..(page + 2)), pages ].select { |number| number.between?(1, pages) }.uniq.sort

    numbers.each_cons(2).flat_map do |number, following|
      case following - number
      when 1 then [ number ]
      when 2 then [ number, number + 1 ] # a gap of one page would hide no more than its number
      else [ number, :gap ]
      end
    end + [ numbers.last ]
  end
end
