import { Controller } from "@hotwired/stimulus"

// Opens a gallery thumbnail's larger variant in a modal <dialog> instead of following its link,
// which still works without JavaScript or in a new tab. Escape and the Close button close the
// dialog natively; this adds clicks on the space around the photo.
export default class extends Controller {
  static targets = [ "dialog" ]

  open(event) {
    // Leave modified clicks alone, e.g. for opening the image in a new tab.
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return

    event.preventDefault()
    this.dialogTarget.showModal()
  }

  // Only clicks on the element itself, not on the photo or the controls inside it.
  closeOnBackdrop(event) {
    if (event.target === event.currentTarget) this.close()
  }

  close() {
    this.dialogTarget.close()
  }
}
