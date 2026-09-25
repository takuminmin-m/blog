require "test_helper"

class PictureTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "article variants are preprocessed for every picture" do
    assert_enqueued_jobs 2, only: ActiveStorage::TransformJob do
      create_picture artwork: false
    end
  end

  test "gallery variants are preprocessed for artwork too" do
    assert_enqueued_jobs 4, only: ActiveStorage::TransformJob do
      create_picture artwork: true
    end
  end

  test "variants are resized and watermarked in the south-east corner" do
    require "vips" # needs libvips installed

    variant = create_picture(artwork: false).image.variant(:article_thumb).processed
    image = Vips::Image.new_from_buffer(variant.download, "")

    assert_equal [ 400, 300 ], [ image.width, image.height ]
    assert_equal [ 255, 0, 0 ], image.getpoint(image.width - 1, image.height - 1).first(3), "overlay pixel"
    assert_equal [ 255, 255, 255 ], image.getpoint(0, 0).first(3), "photo pixel"
  end

  private
    def create_picture(artwork:)
      photo = file_fixture("content/articles/images/photo.png")
      Picture.create!(filename: photo.basename.to_s, artwork: artwork,
        image: { io: StringIO.new(photo.binread), filename: photo.basename.to_s })
    end
end
