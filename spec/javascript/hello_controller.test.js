import { Application } from "@hotwired/stimulus"
import { expect, it, vi } from "vitest"
import HelloController from "../../app/javascript/controllers/hello_controller.js"

it("connects the hello controller to its element", async () => {
  document.body.innerHTML = '<div data-controller="hello"></div>'
  const element = document.querySelector('[data-controller="hello"]')
  const application = Application.start()

  try {
    application.register("hello", HelloController)
    await vi.waitFor(() => expect(element.textContent).toBe("Hello World!"))
  } finally {
    application.stop()
    document.body.innerHTML = ""
  }
})
