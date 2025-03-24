class Picture < ApplicationRecord
  OVERLAY = Rails.root.join("content/overlay.png")

  validates :filename, presence: true, uniqueness: true
  validates :artwork, inclusion: [true, false]

  has_one_attached :image do |attachable|
    options = {
      saver: { strip: true },
      composite: { overlay: OVERLAY, gravity: "south_east" },
      preprocessed: true
    }

    attachable.variant :article_thumb, resize_to_fit: [400, 400], **options
    attachable.variant :article, resize_to_limit: [1000, 1000], **options

    with_options if: :artwork? do
      attachable.variant :gallery_thumb, resize_to_fit: [600, 600], **options
      attachable.variant :gallery, resize_to_limit: [1920, 1080], **options
    end
  end
end
