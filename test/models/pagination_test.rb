require "test_helper"

class PaginationTest < ActiveSupport::TestCase
  test "each page has its share of the records" do
    first, last = [ 1, 3 ].map { |page| Pagination.new(pictures(5), page: page, per_page: 2) }

    assert_equal %w[ photo-00.jpg photo-01.jpg ], first.records.map(&:filename)
    assert_equal %w[ photo-04.jpg ], last.records.map(&:filename)
    assert_equal [ 0, 4 ], [ first.offset, last.offset ]
    assert_equal [ 5, 3 ], [ last.total, last.pages ]
  end

  test "neighboring pages" do
    relation = pictures(5)
    neighbors = [ 1, 2, 3 ].map { |page| Pagination.new(relation, page: page, per_page: 2).then { |pagination| [ pagination.previous_page, pagination.next_page ] } }

    assert_equal [ [ nil, 2 ], [ 1, 3 ], [ 2, nil ] ], neighbors
  end

  test "the page number comes from a param, and a missing one is the first page" do
    relation = pictures(5)
    pages = [ "2", nil, "" ].map { |page| Pagination.new(relation, page: page, per_page: 2).page }

    assert_equal [ 2, 1, 1 ], pages
  end

  test "pages that don't exist aren't found" do
    relation = pictures(5)

    [ "0", "4", "-1", "two", "0x2", [ "1" ] ].each do |page|
      assert_raises(ActiveRecord::RecordNotFound, page.inspect) { Pagination.new(relation, page: page, per_page: 2) }
    end
  end

  test "no records still make one page" do
    pagination = Pagination.new(Picture.none, page: nil, per_page: 2)

    assert_equal [ 1, 0, [ 1 ] ], [ pagination.pages, pagination.total, pagination.series ]
  end

  test "the series links both ends and the pages around this one, with gaps between" do
    relation = pictures(12)
    series = ->(page, pages) { Pagination.new(relation, page: page, per_page: 12 / pages).series }

    assert_equal [ 1, :gap, 4, 5, 6, 7, 8, :gap, 12 ], series.(6, 12)
    assert_equal [ 1, 2, 3, :gap, 12 ], series.(1, 12)
    assert_equal [ 1, :gap, 10, 11, 12 ], series.(12, 12)
    assert_equal [ 1, 2, 3 ], series.(2, 3)
    assert_equal [ 1, 2, 3, 4, 5, 6, 7, 8 ], Pagination.new(pictures(8), page: 5, per_page: 1).series, "a gap of one page shows that page"
  end

  private
    # Records in a known order; pictures don't need an image for this.
    def pictures(count)
      Picture.delete_all
      count.times { |i| Picture.create!(filename: format("photo-%02d.jpg", i), artwork: true) }
      Picture.order(:filename)
    end
end
