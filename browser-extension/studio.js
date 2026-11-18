import { defaults, validateSession, graphemes } from "./engine.mjs";
const $ = id => document.getElementById(id);
let status = { state: "ready" };
const controls = ["target", "refresh", "text", "wpm", "mistakes", "mistake-rate", "pauses", "import", "clear"];
const isBusy = () => ["connecting", "countdown", "typing", "paused", "stopping"].includes(status.state);

async function send(type, session) {
  const response = await chrome.runtime.sendMessage({ type, session });
  if (!response?.ok) throw new Error(response?.error || "The extension is unavailable. Reload it and try again.");
  return response.value;
}
function showError(error) { $("error").textContent = error.message; $("error").hidden = false; }
function session() {
  return { text: $("text").value, wpm: Number($("wpm").value), mistakes: $("mistakes").checked,
    mistakeRate: Number($("mistake-rate").value), naturalPauses: $("pauses").checked, tabId: Number($("target").value) };
}
function updateLabels() {
  const draft = session();
  const count = graphemes(draft.text).length;
  $("count").textContent = `${count.toLocaleString()} characters`;
  $("wpm-value").textContent = `${draft.wpm} WPM`;
  $("rate-value").textContent = `${draft.mistakeRate.toFixed(1)}%`;
  $("frequency").hidden = !draft.mistakes;
  const seconds = Math.ceil(count * 12 / draft.wpm);
  $("estimate").textContent = count ? `≈ ${Math.floor(seconds / 60)}m ${seconds % 60}s, plus countdown, pauses and corrections.` : "Add text to estimate the duration.";
  $("start").disabled = isBusy() || !draft.text.trim() || !$("target").value;
}
function fill(input) {
  $("text").value = input.text || "";
  $("wpm").value = input.wpm ?? defaults.wpm;
  $("mistakes").checked = input.mistakes ?? defaults.mistakes;
  $("mistake-rate").value = input.mistakeRate ?? defaults.mistakeRate;
  $("pauses").checked = input.naturalPauses ?? defaults.naturalPauses;
  updateLabels();
}
function render(next) {
  status = next;
  $("state").textContent = next.state.toUpperCase();
  $("message").textContent = next.message;
  $("destination").textContent = next.title ? `Destination: ${next.title}` : "";
  $("progress").max = next.total || 1;
  $("progress").value = next.progress || 0;
  $("progress-label").textContent = next.total ? `${next.progress} / ${next.total}` : "";
  controls.forEach(id => { $(id).disabled = isBusy(); });
  $("pause").disabled = !["typing", "paused"].includes(next.state);
  $("pause").textContent = next.state === "paused" ? "Resume" : "Pause";
  $("stop").disabled = !isBusy() || next.state === "stopping";
  $("start").textContent = next.state === "countdown" ? `Starting in ${next.countdown}…` : "▶ Start in 5 seconds";
  updateLabels();
}
async function refresh(preferred) {
  const previous = preferred || Number($("target").value);
  const tabs = (await chrome.tabs.query({})).filter(tab => /^https?:\/\//.test(tab.url || "") && !tab.discarded);
  $("target").replaceChildren(new Option("Choose a destination tab…", ""));
  for (const tab of tabs) {
    const option = new Option(`${tab.title || "Untitled"} · ${new URL(tab.url).hostname}`, String(tab.id));
    $("target").append(option);
  }
  if (tabs.some(tab => tab.id === previous)) $("target").value = String(previous);
  updateLabels();
}
let saveTimer;
function saveDraft() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => { void chrome.storage.session.set({ draft: session() }).catch(showError); }, 150);
}
for (const id of ["text", "target", "wpm", "mistakes", "mistake-rate", "pauses"]) {
  $(id).addEventListener("input", () => { updateLabels(); saveDraft(); });
}
$("refresh").addEventListener("click", () => refresh().catch(showError));
$("start").addEventListener("click", async () => {
  $("error").hidden = true;
  $("start").disabled = true;
  try { const draft = session(); validateSession(draft); render(await send("start", draft)); }
  catch (error) { showError(error); updateLabels(); }
});
$("pause").addEventListener("click", async () => {
  try { render(await send(status.state === "paused" ? "resume" : "pause")); } catch (error) { showError(error); }
});
$("stop").addEventListener("click", async () => {
  try { render(await send("stop")); } catch (error) { showError(error); }
});
$("clear").addEventListener("click", async () => {
  $("text").value = "";
  clearTimeout(saveTimer);
  await chrome.storage.session.remove("draft");
  updateLabels();
});
$("import").addEventListener("click", () => $("file").click());
$("file").addEventListener("change", async event => {
  try {
    const file = event.target.files[0];
    if (!file) return;
    if (file.size > 1_000_000) throw new Error("This session file is too large.");
    const imported = validateSession(JSON.parse(await file.text()));
    fill(imported);
    saveDraft();
  } catch (error) { showError(error); }
  finally { event.target.value = ""; }
});
chrome.storage.onChanged.addListener((changes, area) => {
  if (area === "session" && changes.status?.newValue) render(changes.status.newValue);
});
try {
  fill((await chrome.storage.session.get("draft")).draft || defaults);
  await refresh(Number(new URL(location.href).searchParams.get("target")));
  render(await send("status"));
  const stop = (await chrome.commands.getAll()).find(command => command.name === "stop-typing");
  $("shortcut").textContent = stop?.shortcut || "Set in chrome://extensions/shortcuts";
} catch (error) { showError(error); }
