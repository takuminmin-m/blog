import { Controller } from "@hotwired/stimulus"

// The gallery's lightbox: a modal <dialog> with a slide per artwork, in a strip that scroll-snaps
// so swipes and trackpads move between photos natively; the buttons and arrow keys scroll it too.
// A thumbnail opens it at its photo instead of following its link, which still works without
// JavaScript or in a new tab. Escape and the Close button close the dialog natively.
export default class extends Controller {
  static targets = [ "dialog", "link", "strip", "slide", "counter", "previous", "next", "info" ]

  open(event) {
    // Leave modified clicks alone, e.g. for opening the image in a new tab.
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return

    event.preventDefault()
    this.#show(event.params.index)
    this.dialogTarget.showModal()
    this.#scrollToCurrent()
  }

  previous(event) {
    this.#step(event, -1)
  }

  next(event) {
    this.#step(event, 1)
  }

  // Follows the strip as it scrolls, by a swipe or by #scrollToCurrent.
  update() {
    const index = Math.round(this.stripTarget.scrollLeft / this.stripTarget.clientWidth)
    if (this.dialogTarget.open && index !== this.current) this.#show(index)
  }

  toggleInfo() {
    if (this.infoTarget.ariaDisabled === "true") return

    this.infoTarget.ariaPressed = this.dialogTarget.toggleAttribute("data-info")
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

  #step(event, offset) {
    const index = this.current + offset
    if (!this.dialogTarget.open || !this.slideTargets[index]) return

    event.preventDefault()
    this.#show(index)
    this.#scrollToCurrent()
  }

  #scrollToCurrent() {
    this.stripTarget.scrollTo({ left: this.current * this.stripTarget.clientWidth, behavior: "instant" })
  }

  #show(index) {
    this.current = index
    this.counterTarget.textContent = `${index + 1} / ${this.slideTargets.length}`
    this.previousTarget.ariaDisabled = index === 0
    this.nextTarget.ariaDisabled = index === this.slideTargets.length - 1
    this.infoTarget.ariaDisabled = !this.slideTargets[index].querySelector("figcaption")

    // Load the neighbors too, so they're ready to move on to.
    for (const slide of this.slideTargets.slice(Math.max(index - 1, 0), index + 2)) {
      slide.querySelector("img").loading = "eager"
    }
  }
}
