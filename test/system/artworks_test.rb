require "application_system_test_case"

# The fixture gallery, newest first: sunset.jpg (with camera EXIF), then artwork.png (without).
class ArtworksTest < ApplicationSystemTestCase
  setup do
    ContentSync.new.sync
    visit artworks_url
  end

  test "a thumbnail opens its photo in a lightbox, with the EXIF behind Info" do
    click_on "sunset"

    within "dialog[open]" do
      assert_text "1 / 2"
      assert_no_text "Canon EOS R6"

      click_on "Info"
      assert_text "Canon EOS R6"
      assert_text "1/250 s"

      click_on "Close"
    end
    assert_no_selector "dialog[open]"
    assert_current_path artworks_path
  end

  test "the arrows and arrow keys move between the photos, up to either end" do
    click_on "sunset"

    within "dialog[open]" do
      next_button.click
      assert_text "2 / 2"
      assert_selector "button[aria-disabled=true]", text: "Info" # artwork.png has no EXIF

      next_button.click
      assert_text "2 / 2"

      send_keys :left
      assert_text "1 / 2"
      send_keys :left
      assert_text "1 / 2"

      send_keys :right
      assert_text "2 / 2"
    end
    assert_equal "artwork", shown_photo
  end

  test "swiping the strip moves to the photo it lands on" do
    click_on "sunset"

    # A swipe scrolls the strip natively; the lightbox follows its scroll position.
    execute_script "const strip = document.querySelector('[data-lightbox-target=strip]'); strip.scrollLeft = strip.clientWidth"
    within("dialog[open]") { assert_text "2 / 2" }
    assert_equal "artwork", shown_photo
  end

  test "closing the lightbox focuses the thumbnail of the photo last shown" do
    click_on "sunset"
    next_button.click
    within("dialog[open]") { assert_text "2 / 2" }

    send_keys :escape
    assert_no_selector "dialog[open]"
    assert_selector "a:focus img[alt=artwork]" # focused on the dialog's close event, a task later
  end

  test "past either end of a page, the lightbox carries on into the neighboring page" do
    per_page = ArtworksController::PER_PAGE
    add_artworks per_page - 1
    visit artworks_url
    click_on "extra-00" # the first page's last

    within("dialog[open]") { assert_text "#{per_page} / #{per_page + 1}" }
    next_button.click
    assert_current_path artworks_path(page: 2)
    within("dialog[open]") { assert_text "#{per_page + 1} / #{per_page + 1}" }
    assert_equal "artwork", shown_photo

    find("dialog[open] button[aria-label='Previous photo']").click
    assert_current_path artworks_path
    within("dialog[open]") { assert_text "#{per_page} / #{per_page + 1}" }
    assert_equal "extra-00", shown_photo
  end

  test "swiping past a page's last photo carries on into the next page" do
    per_page = ArtworksController::PER_PAGE
    add_artworks per_page - 1
    visit artworks_url
    click_on "extra-00"

    # Onto the link that ends the strip.
    execute_script "const strip = document.querySelector('[data-lightbox-target=strip]'); strip.scrollLeft = strip.scrollWidth"
    assert_current_path artworks_path(page: 2)
    within("dialog[open]") { assert_text "#{per_page + 1} / #{per_page + 1}" }
  end

  test "a click beside the photo closes the lightbox, and one on it doesn't" do
    click_on "sunset"

    photo = find("dialog[open] img[alt=sunset]")
    photo.click
    assert_selector "dialog[open]"

    # Click offsets are from the element's center: this is near the left edge of the space the
    # photo is centered in.
    around_photo = photo.find(:xpath, "..")
    around_photo.click(x: 10 - (around_photo.rect.width / 2), y: 0)
    assert_no_selector "dialog[open]"
  end

  private
    def next_button
      find("dialog[open] button[aria-label='Next photo']")
    end

    # The photo on the slide the strip has scrolled to.
    def shown_photo
      evaluate_script <<~JS
        (() => {
          const strip = document.querySelector("[data-lightbox-target=strip]")
          const left = strip.getBoundingClientRect().left
          return [ ...strip.querySelectorAll("figure") ].find(slide => Math.abs(slide.getBoundingClientRect().left - left) < 1)?.querySelector("img").alt
        })()
      JS
    end

    # Artworks sharing sunset.jpg's image, sorting between it and artwork.png: extra-00.jpg and on.
    def add_artworks(count)
      image = Picture.find_by!(filename: "sunset.jpg").image.blob
      count.times { |i| Picture.create!(filename: format("extra-%02d.jpg", i), artwork: true, image: image) }
    end
end
