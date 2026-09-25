class Picture < ApplicationRecord
  # A String, not a Pathname: preprocessed variants hand their transformations to
  # ActiveStorage::TransformJob, and Active Job can't serialize a Pathname.
  OVERLAY = Rails.configuration.x.content_root.join("overlay.png").to_s

  validates :filename, presence: true, uniqueness: true
  validates :artwork, inclusion: [ true, false ]

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
