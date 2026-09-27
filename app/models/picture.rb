class Picture < ApplicationRecord
  # Read once, when the app loads, so a changed watermark takes a restart.
  OVERLAY = Watermark.path

  # The camera's clock time from EXIF (see Exif#taken_at), which Time.zone mustn't shift.
  self.skip_time_zone_conversion_for_attributes = [ :taken_at ]

  validates :filename, presence: true, uniqueness: true
  validates :artwork, inclusion: [ true, false ]

  scope :artworks, -> { where(artwork: true) }
  # Newest first for date-prefixed or camera-numbered filenames.
  scope :newest_first, -> { order(filename: :desc) }
  # By the name in a gallery URL, its filename without the extension (ArtworksHelper#artwork_title).
  scope :named, ->(name) { where(filename: ContentSync::EXTENSIONS.map { |extension| "#{name}.#{extension}" }) }

  has_one_attached :image do |attachable|
    options = {
      saver: { strip: true },
      # image_processing's composite takes the overlay positionally; a Hash would be splatted
      # into keyword arguments and raise ArgumentError.
      composite: [ OVERLAY, { gravity: "south_east" } ]
    }

    attachable.variant :article_thumb, resize_to_fit: [ 400, 400 ], preprocessed: true, **options
    attachable.variant :article, resize_to_limit: [ 1000, 1000 ], preprocessed: true, **options
    attachable.variant :gallery_thumb, resize_to_fit: [ 600, 600 ], preprocessed: :artwork?, **options
    attachable.variant :gallery, resize_to_limit: [ 1920, 1080 ], preprocessed: :artwork?, **options
  end
end
