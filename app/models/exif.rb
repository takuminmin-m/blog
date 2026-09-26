require "exifr/jpeg"

# What a photo's EXIF says about the shot, as Picture attributes: when it was taken, with which
# camera and lens, and the exposure. Nothing else is read, so the GPS position and serial numbers
# stay in the original file, which the site never serves (its variants are saved stripped).
class Exif
  ATTRIBUTES = %i[ taken_at camera lens focal_length f_number exposure_time iso ].freeze

  # Only JPEGs are read. A broken one is logged and has no details, so it can't stop a sync.
  def self.read(path)
    return new unless path.extname.downcase.in?(%w[ .jpg .jpeg ])

    new EXIFR::JPEG.new(path.to_s, load_thumbnails: false).to_hash
  rescue EXIFR::MalformedImage, EOFError => error
    Rails.logger.warn "No EXIF read from #{path}: #{error.message}"
    new
  end

  # +tags+ are EXIFR's, by name: { model: "X-T5", f_number: (7/5), ... }.
  def initialize(tags = {})
    @tags = tags
  end

  # Every attribute, nil for what the photo doesn't record, so assigning them clears stale ones.
  def attributes
    ATTRIBUTES.index_with { |name| public_send(name) }
  end

  # The camera's clock time as it read, labeled UTC so Picture stores it unconverted: EXIF often
  # has no time zone, and the clock is what the photographer saw where they were. (EXIFR builds
  # it as a local time, whose fields are the clock's.)
  def taken_at
    time = @tags[:date_time_original]
    Time.utc(time.year, time.month, time.day, time.hour, time.min, time.sec) if time.is_a?(Time)
  end

  def camera
    name @tags[:make], @tags[:model]
  end

  def lens
    name @tags[:lens_make], @tags[:lens_model]
  end

  # In millimeters.
  def focal_length
    positive(@tags[:focal_length])&.to_f
  end

  def f_number
    positive(@tags[:f_number])&.to_f
  end

  # In seconds.
  def exposure_time
    positive(@tags[:exposure_time])&.to_f
  end

  def iso
    positive(@tags[:iso_speed_ratings])&.to_i
  end

  private
    # Models often include the make, or a shorter form of it (the "NIKON CORPORATION" makes the
    # "NIKON Z 6_2"), so it's only added to those that don't: "FUJIFILM X-T5".
    def name(make, model)
      make, model = make.to_s.squish, model.to_s.squish
      return if model.empty?

      model.downcase.start_with?(make.split.first.to_s.downcase) ? model : "#{make} #{model}"
    end

    # EXIF values can be junk, such as a 0/0 rational (which EXIFR reads as NaN): nil for those.
    def positive(value)
      value = Array(value).first
      value if value.is_a?(Numeric) && value.finite? && value.positive?
    end
end
