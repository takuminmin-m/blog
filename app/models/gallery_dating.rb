# Names gallery images by the day they were taken, as the gallery's naming wants
# (<YYYY-MM-DD>-<name>), so photos can go in under the camera's names: P1200205.jpeg becomes
# 2026-09-21-P1200205.jpeg. The gallery lists filenames descending, so that puts them newest
# first, and the camera's numbers keep a day's photos in order.
#
# It renames files in the checkout, so it's for the machine that holds the originals, before
# they're synced and copied anywhere; a sync never renames, since a server's checkout can be
# read-only, and a renamed copy would diverge from its original.
class GalleryDating
  DATED = /\A\d{4}-\d{2}-\d{2}-/

  Renamed = Data.define(:from, :to) do
    def to_s = "#{from.basename} -> #{to.basename}"
  end

  Skipped = Data.define(:path, :reason) do
    def to_s = "#{path.basename}: #{reason}"
  end

  def initialize(root = Rails.configuration.x.content_root)
    @dir = root.join("gallery")
  end

  # Renames every image whose name doesn't start with a date, and returns what happened to each.
  def date
    ContentSync.images(@dir).sort.reject { |path| path.basename.to_s.match?(DATED) }.map do |path|
      date_image path
    end
  end

  private
    def date_image(path)
      # The camera's clock time, stored as read (see Exif#taken_at), so its date is the clock's.
      taken_at = Exif.read(path).taken_at
      return Skipped.new(path, "no shooting date in its EXIF") unless taken_at

      dated = path.dirname.join("#{taken_at.strftime("%F")}-#{path.basename}")
      # A rename would replace it without a word.
      return Skipped.new(path, "#{dated.basename} already exists") if dated.exist?

      path.rename(dated)
      Renamed.new(path, dated)
    end
end
