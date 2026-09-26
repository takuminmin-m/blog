require "test_helper"

class ExifTest < ActiveSupport::TestCase
  # The fixture's EXIF was written with libvips, which saves an image's exif-ifd* fields.
  test "reads the shooting details of a JPEG" do
    exif = Exif.read(file_fixture("content/gallery/sunset.jpg"))

    assert_equal({
      taken_at: Time.utc(2026, 9, 1, 18, 30, 15),
      camera: "Canon EOS R6",
      lens: "RF50mm F1.8 STM",
      focal_length: 50.0,
      f_number: 2.8,
      exposure_time: 0.004,
      iso: 400
    }, exif.attributes)
  end

  test "the time taken is the camera's clock time, whatever its time zone" do
    exif = Exif.new(date_time_original: Time.new(2026, 9, 1, 18, 30, 15, "+09:00"))

    assert_equal Time.utc(2026, 9, 1, 18, 30, 15), exif.taken_at
  end

  test "the make is added to camera and lens models without it" do
    assert_equal "Canon EOS R6", Exif.new(make: "Canon", model: "Canon EOS R6").camera
    assert_equal "NIKON Z 6_2", Exif.new(make: "NIKON CORPORATION", model: "NIKON Z 6_2").camera
    assert_equal "FUJIFILM X-T5", Exif.new(make: "FUJIFILM ", model: " X-T5").camera
    assert_equal "XF33mmF1.4 R LM WR", Exif.new(lens_model: "XF33mmF1.4 R LM WR").lens
    assert_nil Exif.new(lens_make: "FUJIFILM").lens
  end

  test "junk values are left out" do
    exif = Exif.new(date_time_original: "    :  :     :  :  ", f_number: Float::NAN, exposure_time: Float::INFINITY, iso_speed_ratings: 0)

    assert_equal Exif::ATTRIBUTES.index_with(nil), exif.attributes
  end

  test "images without EXIF have no details" do
    assert_equal Exif::ATTRIBUTES.index_with(nil), Exif.read(file_fixture("content/gallery/artwork.png")).attributes
  end

  test "a broken JPEG has no details instead of failing" do
    truncated = file_fixture("content/gallery/sunset.jpg").binread.first(300) # in the middle of its EXIF

    [ "not a JPEG", truncated ].each do |bytes|
      Tempfile.create([ "broken", ".jpg" ], binmode: true) do |file|
        file.write(bytes)
        file.close

        assert_equal Exif::ATTRIBUTES.index_with(nil), Exif.read(Pathname(file.path)).attributes
      end
    end
  end
end
