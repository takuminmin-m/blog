require "test_helper"

class WatermarkTest < ActiveSupport::TestCase
  setup do
    @dir = Pathname(Dir.mktmpdir)
    @source = @dir.join("content/overlay.png")
    @source.dirname.mkpath
    @source.binwrite("first")
  end

  teardown do
    FileUtils.rm_rf(@dir)
  end

  test "the path is a copy of the watermark named by its digest" do
    path = watermark_path

    assert_kind_of String, path # Active Job can't serialize a Pathname
    assert_match %r{/overlay-\h{16}\.png\z}, path
    assert_equal "first", File.binread(path)
    assert_equal path, watermark_path, "the same watermark, the same path"
  end

  test "a changed watermark gets a new path, and so its variants get new URLs" do
    first = watermark_path
    @source.binwrite("second")

    assert_not_equal first, watermark_path
    assert_equal "second", File.binread(watermark_path)
    assert_equal "first", File.binread(first), "variants still being processed can read the old one"
  end

  test "without a watermark, the path is the content path" do
    @source.delete

    assert_equal @source.to_s, watermark_path
  end

  test "variants take the watermark's copy, not the content path" do
    assert_equal Watermark.path, Picture::OVERLAY
    assert_not_equal Rails.configuration.x.content_root.join("overlay.png").to_s, Picture::OVERLAY
  end

  private
    def watermark_path
      Watermark.path(@source, dir: @dir.join("watermarks"))
    end
end
