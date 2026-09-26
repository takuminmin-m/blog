require "application_system_test_case"

class ArtworksTest < ApplicationSystemTestCase
  setup do
    ContentSync.new.sync
    visit artworks_url
  end

  test "a thumbnail opens its photo in a lightbox, with the EXIF behind Info" do
    click_on "sunset"

    within "dialog[open]" do
      assert_selector "img[alt=sunset]"
      assert_no_text "Canon EOS R6"

      find("summary", text: "Info").click
      assert_text "Canon EOS R6"
      assert_text "1/250 s"

      click_on "Close"
    end
    assert_no_selector "dialog[open]"
    assert_current_path artworks_path
  end

  test "Escape closes the lightbox" do
    click_on "sunset"
    assert_selector "dialog[open]"

    send_keys :escape
    assert_no_selector "dialog[open]"
  end

  test "a click beside the photo closes the lightbox, and one on it doesn't" do
    click_on "sunset"

    find("dialog[open] img").click
    assert_selector "dialog[open]"

    # Click offsets are from the element's center: this is near its left edge, beside the photo.
    around_photo = find("dialog[open] [data-action~='click->lightbox#closeOnBackdrop']")
    around_photo.click(x: 10 - (around_photo.rect.width / 2), y: 0)
    assert_no_selector "dialog[open]"
  end
end
