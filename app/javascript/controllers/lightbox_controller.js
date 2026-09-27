import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// The gallery's lightbox: a modal <dialog> with a slide per artwork on the page, in a strip that
// scroll-snaps so swipes and trackpads move between photos natively; the buttons and arrow keys
// scroll it too. Past either end of the page it goes on through the links ending the strip,
// whose #lightbox-first or #lightbox-last reopens it on the next or previous page (see connect).
// A thumbnail opens it at its photo instead of following its link, which still works without
// JavaScript or in a new tab. Escape and the Close button close the dialog natively.
//
// While it's open, the address bar shows the photo's own page, the one its thumbnail links to,
// so the URL copied from it or reloaded is the photo's. The gallery page's URL comes back before
// leaving it by a Turbo visit and on closing, which keeps it in the history for going back to.
export default class extends Controller {
  static targets = [ "dialog", "link", "strip", "slide", "counter", "previous", "next", "info", "share", "previousPage", "nextPage" ]
  static values = { offset: Number, total: Number }

  connect() {
    this.shareTarget.hidden = !navigator.share && !navigator.clipboard

    const index = { "#lightbox-first": 0, "#lightbox-last": this.slideTargets.length - 1 }[location.hash]
    // Wait for the page itself rather than Turbo's preview of it from its cache.
    if (index === undefined || document.documentElement.hasAttribute("data-turbo-preview")) return

    history.replaceState(history.state, "", location.pathname + location.search)
    this.#open(index)
  }

  open(event) {
    // Leave modified clicks alone, e.g. for opening the image in a new tab.
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return

    event.preventDefault()
    this.#open(event.params.index)
  }

  previous(event) {
    this.#step(event, -1)
  }

  next(event) {
    this.#step(event, 1)
  }

  // Follows the strip as it scrolls, by a swipe or by #scrollToCurrent. Coming to rest on a link
  // at either end goes on to its page.
  update() {
    if (!this.dialogTarget.open) return

    const position = this.stripTarget.scrollLeft / this.stripTarget.clientWidth
    const index = Math.round(position) - this.#leadingSlides

    if (this.slideTargets[index]) {
      if (index !== this.current) this.#show(index)
    } else if (Math.abs(position - Math.round(position)) < 0.01) {
      Turbo.visit(index < 0 ? this.previousPageTarget.href : this.nextPageTarget.href)
    }
  }

  toggleInfo() {
    if (this.infoTarget.ariaDisabled === "true") return

    this.infoTarget.ariaPressed = this.dialogTarget.toggleAttribute("data-info")
  }

  // The share sheet where there is one, like on phones, or else the photo's link to paste.
  async share() {
    const link = this.linkTargets[this.current]

    if (navigator.share) {
      try {
        await navigator.share({ title: link.querySelector("img").alt, url: link.href })
      } catch (error) {
        if (error.name !== "AbortError") throw error
      }
    } else {
      await navigator.clipboard.writeText(link.href)
      this.shareTarget.textContent = "Copied"
      setTimeout(() => this.shareTarget.textContent = "Share", 2000)
    }
  }

  // On closing, and before a Turbo visit while the lightbox is open. By the dialog's close
  // event, a task after closing, the browser may already be on another page's URL, which this
  // leaves alone.
  restoreLocation() {
    if (location.href === this.photoLocation) history.replaceState(history.state, "", this.galleryLocation)
  }

  // Only clicks on the element itself, not on the photo or the controls inside it.
  closeOnBackdrop(event) {
    if (event.target === event.currentTarget) this.close()
  }

  close() {
    this.dialogTarget.close()
  }

  // The dialog gives focus back to the thumbnail it was opened from; this moves it to the last
  // photo shown instead, which also scrolls the gallery to it.
  focusThumbnail() {
    this.linkTargets[this.current]?.focus()
  }

  #open(index) {
    this.galleryLocation = location.href
    this.#show(index)
    this.dialogTarget.showModal()
    this.#scrollToCurrent()
  }

  #step(event, offset) {
    if (!this.dialogTarget.open) return

    event.preventDefault()
    const index = this.current + offset

    if (this.slideTargets[index]) {
      this.#show(index)
      this.#scrollToCurrent()
    } else if (index < 0 && this.hasPreviousPageTarget) {
      Turbo.visit(this.previousPageTarget.href)
    } else if (index > 0 && this.hasNextPageTarget) {
      Turbo.visit(this.nextPageTarget.href)
    }
  }

  // The link to the previous page comes before the photos.
  get #leadingSlides() {
    return this.hasPreviousPageTarget ? 1 : 0
  }

  #scrollToCurrent() {
    this.stripTarget.scrollTo({ left: (this.current + this.#leadingSlides) * this.stripTarget.clientWidth, behavior: "instant" })
  }

  #show(index) {
    this.current = index
    this.counterTarget.textContent = `${this.offsetValue + index + 1} / ${this.totalValue}`
    this.previousTarget.ariaDisabled = index === 0 && !this.hasPreviousPageTarget
    this.nextTarget.ariaDisabled = index === this.slideTargets.length - 1 && !this.hasNextPageTarget
    this.infoTarget.ariaDisabled = !this.slideTargets[index].querySelector("figcaption")

    this.photoLocation = this.linkTargets[index].href
    history.replaceState(history.state, "", this.photoLocation)

    // Load the neighbors too, so they're ready to move on to.
    for (const slide of this.slideTargets.slice(Math.max(index - 1, 0), index + 2)) {
      slide.querySelector("img").loading = "eager"
    }
  }
}
