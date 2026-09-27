module ArtworksHelper
  # An artwork's name, from its filename: "2026-06-20-hydrangea".
  def artwork_title(picture)
    File.basename(picture.filename, ".*")
  end

  # A picture's EXIF details for its lightbox, as label => value, leaving out what the photo
  # doesn't record.
  def exif_details(picture)
    {
      # The camera's clock time, so the datetime has no offset.
      "Taken" => picture.taken_at&.then { |time| time_tag(time, time.strftime("%Y-%m-%d %H:%M"), datetime: time.strftime("%FT%T")) },
      "Camera" => picture.camera,
      "Lens" => picture.lens,
      "Focal length" => picture.focal_length&.then { |millimeters| "#{rounded(millimeters)} mm" },
      "Aperture" => picture.f_number&.then { |f_number| "f/#{rounded(f_number)}" },
      "Shutter speed" => picture.exposure_time&.then { |seconds| shutter_speed(seconds) },
      "ISO" => picture.iso&.to_s
    }.compact
  end

  # The EXIF details on one line of plain text, for describing the photo in a link preview:
  # "2026-09-01 18:30 · Canon EOS R6 · … · ISO 400". The values speak for themselves by their
  # units, all but the ISO speed's.
  def exif_summary(picture)
    exif_details(picture).map { |label, value| label == "ISO" ? "ISO #{value}" : strip_tags(value) }.join(" · ")
  end

  private
    # 1/250 s for the fractions of a second cameras show that way, 0.3 s or 30 s otherwise.
    # Close is enough, since some cameras store 1/60 as 0.0166.
    def shutter_speed(seconds)
      denominator = (1 / seconds).round

      if denominator > 1 && ((denominator * seconds) - 1).abs < 0.01
        "1/#{denominator} s"
      else
        "#{rounded(seconds)} s"
      end
    end

    # 2.8 or 50, not 50.0.
    def rounded(number)
      number_with_precision(number, precision: 1, strip_insignificant_zeros: true)
    end
end
