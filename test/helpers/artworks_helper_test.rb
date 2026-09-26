require "test_helper"

class ArtworksHelperTest < ActionView::TestCase
  test "EXIF details are labeled and formatted the way cameras show them" do
    picture = Picture.new(taken_at: Time.utc(2026, 9, 1, 18, 30, 15), camera: "Canon EOS R6", lens: "RF50mm F1.8 STM",
      focal_length: 50.0, f_number: 2.8, exposure_time: 0.004, iso: 400)

    assert_equal({
      "Taken" => %(<time datetime="2026-09-01T18:30:15">2026-09-01 18:30</time>),
      "Camera" => "Canon EOS R6",
      "Lens" => "RF50mm F1.8 STM",
      "Focal length" => "50 mm",
      "Aperture" => "f/2.8",
      "Shutter speed" => "1/250 s",
      "ISO" => "400"
    }, exif_details(picture))
  end

  test "details the photo doesn't record are left out" do
    assert_empty exif_details(Picture.new)
    assert_equal [ "Aperture" ], exif_details(Picture.new(f_number: 4.0)).keys
  end

  test "numbers get at most one decimal" do
    assert_equal "f/4", exif_details(Picture.new(f_number: 4.0))["Aperture"]
    assert_equal "f/1.8", exif_details(Picture.new(f_number: 1.78))["Aperture"]
    assert_equal "4.3 mm", exif_details(Picture.new(focal_length: 4.25))["Focal length"]
  end

  test "shutter speeds are fractions of a second where cameras show them so" do
    {
      1.0 / 8000 => "1/8000 s",
      0.0166 => "1/60 s", # how some cameras store 1/60
      0.5 => "1/2 s",
      0.3 => "0.3 s",
      0.8 => "0.8 s",
      1.0 => "1 s",
      2.5 => "2.5 s",
      30.0 => "30 s"
    }.each do |seconds, shutter_speed|
      assert_equal shutter_speed, exif_details(Picture.new(exposure_time: seconds))["Shutter speed"], "#{seconds} seconds"
    end
  end
end
