# The watermark composited onto every Picture variant, content/overlay.png, by the path of a copy
# named by its digest.
#
# A variant's URL comes from its transformations, which name the watermark by path. With the
# content path, a changed watermark would keep its variants' URLs, and caches that keep variants
# forever (Cloudflare's, see config/application.rb) would go on serving the old one. The copy's
# path changes with its bytes, and so do the URLs.
module Watermark
  DIR = Rails.root.join("tmp/watermarks")

  # A String, not a Pathname: preprocessed variants hand their transformations to
  # ActiveStorage::TransformJob, and Active Job can't serialize a Pathname.
  def self.path(source = Rails.configuration.x.content_root.join("overlay.png"), dir: DIR)
    # Variants fail without it either way, but the app still boots without a content checkout.
    return source.to_s unless source.file?

    data = source.binread
    copy = dir.join("overlay-#{Digest::SHA256.hexdigest(data).first(16)}#{source.extname}")

    unless copy.file?
      # Written aside and renamed into place, so another process never reads a partial copy.
      dir.mkpath
      partial = dir.join("#{copy.basename}.#{Process.pid}.partial")
      partial.binwrite(data)
      partial.rename(copy)
    end

    copy.to_s
  end
end
