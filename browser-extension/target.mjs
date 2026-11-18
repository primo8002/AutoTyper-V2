// These functions execute inside the selected page, without interpolating draft text.
export function captureEditor() {
  let element = document.activeElement;
  for (let depth = 0; depth < 12; depth++) {
    if (element?.shadowRoot?.activeElement) { element = element.shadowRoot.activeElement; continue; }
    if (element?.tagName === "IFRAME") {
      try { element = element.contentDocument?.activeElement; } catch { return null; }
      continue;
    }
    break;
  }
  if (!element || element.disabled || element.readOnly || element.getAttribute("aria-readonly") === "true") return null;
  const inputAllowed = element.tagName === "INPUT" && ["text", "search", "url", "tel", "email"].includes(element.type);
  if (!(inputAllowed || element.tagName === "TEXTAREA" || element.isContentEditable)) return null;
  if (/(?:password|one-time-code|cc-)/i.test(element.autocomplete || "")) return null;
  // Input uses the current selection. Never replace a pre-existing selected passage implicitly.
  if (element.selectionStart != null && element.selectionStart !== element.selectionEnd) return null;
  const selection = element.ownerDocument.getSelection();
  if (element.isContentEditable && selection && !selection.isCollapsed) return null;
  return element;
}

export function editorStillFocused() {
  if (!this.isConnected || this.disabled || this.readOnly || this.getAttribute("aria-readonly") === "true") return false;
  let element = document.activeElement;
  for (let depth = 0; depth < 12; depth++) {
    if (element?.shadowRoot?.activeElement) { element = element.shadowRoot.activeElement; continue; }
    if (element?.tagName === "IFRAME") {
      try { element = element.contentDocument?.activeElement; } catch { return false; }
      continue;
    }
    break;
  }
  return element === this;
}
