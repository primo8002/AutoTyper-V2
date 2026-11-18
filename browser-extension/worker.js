import { validateSession, operations, graphemes } from "./engine.mjs";
import { captureEditor, editorStillFocused } from "./target.mjs";

const runningStates = new Set(["connecting", "countdown", "typing", "paused", "stopping"]);
let active = null;
let lastStatus = { state: "ready", message: "Click inside the destination editor, then open AutoTyper from that tab.", progress: 0, total: 0 };
let writeQueue = Promise.resolve();
const ready = (async () => {
  const saved = (await chrome.storage.session.get("status")).status;
  if (saved) lastStatus = saved;
  if (saved && runningStates.has(saved.state)) {
    // A restarted worker must never replay text whose delivery is uncertain.
    try { await chrome.debugger.detach({ tabId: saved.tabId }); } catch { /* already gone */ }
    lastStatus = { ...saved, state: "stopped", message: "Session interrupted. Inspect the destination before starting a new run." };
    await publish();
  }
})();

function publish(job = active) {
  if (job) lastStatus = { state: job.state, message: job.message, tabId: job.tabId, title: job.title,
    progress: job.progress, total: job.total, countdown: job.countdown };
  const snapshot = { ...lastStatus };
  writeQueue = writeQueue.catch(() => {}).then(async () => {
    await chrome.storage.session.set({ status: snapshot });
    const text = snapshot.state === "countdown" ? String(snapshot.countdown) : snapshot.state === "typing" ? "▶" : snapshot.state === "paused" ? "Ⅱ" : "";
    await chrome.action.setBadgeText({ text });
    await chrome.action.setBadgeBackgroundColor({ color: "#8fe8c2" });
  });
  return writeQueue;
}

function check(job) {
  if (job.cancelled) throw new Error("Session stopped.");
}

async function wait(job, ms) {
  let remaining = ms;
  while (remaining > 0 || job.state === "paused") {
    check(job);
    const paused = job.state === "paused";
    const slice = Math.min(50, Math.max(1, remaining));
    const before = Date.now();
    await new Promise(resolve => setTimeout(resolve, slice));
    check(job);
    if (Date.now() - before > 5000) {
      job.resumeState = job.state === "countdown" ? "countdown" : "typing";
      job.state = "paused";
      job.message = "Long interruption detected. Check the destination and Resume when ready.";
      await publish(job);
    } else if (!paused) remaining -= slice;
  }
  check(job);
}

async function command(job, name, params = {}) {
  check(job);
  return chrome.debugger.sendCommand({ tabId: job.tabId }, name, params);
}

async function editorCheck(job) {
  const result = await command(job, "Runtime.callFunctionOn", {
    objectId: job.editorId, functionDeclaration: editorStillFocused.toString(), returnByValue: true
  });
  if (result.exceptionDetails || result.result?.value !== true) {
    throw new Error("The editor lost its cursor or was replaced. Check the document before starting again.");
  }
}

async function sendKey(job, key, code, keyCode, text) {
  await command(job, "Input.dispatchKeyEvent", { type: "keyDown", key, code,
    windowsVirtualKeyCode: keyCode, ...(text ? { text, unmodifiedText: text } : {}) });
  // Release even if Stop arrived while keyDown was in flight. Never leave a key held.
  await chrome.debugger.sendCommand({ tabId: job.tabId }, "Input.dispatchKeyEvent", {
    type: "keyUp", key, code, windowsVirtualKeyCode: keyCode
  });
}

async function execute(job, settings) {
  try {
    await chrome.debugger.attach({ tabId: job.tabId }, "1.3");
    job.attached = true;
    check(job);
    await command(job, "Page.enable");
    await command(job, "Emulation.setFocusEmulationEnabled", { enabled: true });
    const editor = await command(job, "Runtime.evaluate", {
      expression: `(${captureEditor.toString()})()`, objectGroup: "autotyper", returnByValue: false
    });
    if (editor.exceptionDetails || !editor.result?.objectId) {
      throw new Error("No editable cursor found. Click a text field or Google Docs body (with no text selected), then try again. Password, read-only and cross-origin iframe fields are unsupported.");
    }
    job.editorId = editor.result.objectId;
    job.state = "countdown";
    for (let seconds = 5; seconds > 0; seconds--) {
      job.countdown = seconds;
      job.message = `Typing starts in ${seconds} seconds in “${job.title}”. You can switch tabs now.`;
      await publish(job);
      await wait(job, 1000);
    }
    job.state = "typing";
    job.message = "Typing into the locked tab. Keep that document open; you can work elsewhere.";
    await publish(job);
    for (const op of operations(settings)) {
      await wait(job, 0);
      if (op.kind === "wait") await wait(job, op.ms);
      else if (op.kind === "progress") {
        job.progress = op.value;
        await publish(job);
      } else {
        await editorCheck(job);
        if (op.kind === "backspace") await sendKey(job, "Backspace", "Backspace", 8);
        else if (op.text === "\n" && job.isGoogleDoc) await sendKey(job, "Enter", "Enter", 13, "\r");
        else await command(job, "Input.insertText", { text: op.text });
      }
    }
    job.state = "complete";
    job.message = `Delivered ${job.total} characters to “${job.title}”. Check the document and its save status.`;
  } catch (error) {
    job.state = job.cancelled ? "stopped" : "error";
    job.message = job.stopReason || error.message;
  } finally {
    if (job.attached) {
      try { await chrome.debugger.sendCommand({ tabId: job.tabId }, "Emulation.setFocusEmulationEnabled", { enabled: false }); } catch { /* closed */ }
      try { await chrome.debugger.sendCommand({ tabId: job.tabId }, "Runtime.releaseObjectGroup", { objectGroup: "autotyper" }); } catch { /* closed */ }
      try { await chrome.debugger.detach({ tabId: job.tabId }); } catch { /* already detached */ }
    }
    // Remain busy until cleanup completes, so an older run cannot detach a newer one.
    await publish(job);
    if (active === job) active = null;
  }
}

async function start(input) {
  if (active) throw new Error("Stop the current session before starting another.");
  const settings = validateSession(input);
  if (!Number.isInteger(input.tabId)) throw new Error("Choose a destination tab.");
  // Reserve the run before any asynchronous work to reject simultaneous starts.
  const job = { tabId: input.tabId, state: "connecting", message: "Connecting to the selected tab…",
    progress: 0, total: graphemes(settings.text).length, cancelled: false, attached: false };
  active = job;
  try {
    const tab = await chrome.tabs.get(job.tabId);
    if (!/^https?:\/\//.test(tab.url ?? "") || tab.discarded || tab.status === "loading") {
      throw new Error("Choose a fully loaded HTTP(S) tab. Browser settings and discarded tabs cannot receive text.");
    }
    job.url = tab.url;
    job.title = tab.title || new URL(tab.url).hostname;
    job.isGoogleDoc = /^https:\/\/docs\.google\.com\/document\/d\//.test(tab.url);
    await publish(job);
    job.done = execute(job, settings);
    return { ...lastStatus };
  } catch (error) {
    active = null;
    throw error;
  }
}

function stop(reason = "Stopped. Review the destination before starting again; a pending typo may remain.") {
  if (!active || !runningStates.has(active.state)) return;
  active.cancelled = true;
  active.stopReason = reason;
  active.state = "stopping";
  active.message = "Stopping…";
  void publish(active);
}

async function handle(message) {
  await ready;
  switch (message?.type) {
    case "status": return { ...lastStatus };
    case "start": return start(message.session);
    case "pause":
      if (active?.state !== "typing") throw new Error("Only a typing session can be paused.");
      active.resumeState = "typing";
      active.state = "paused";
      active.message = "Paused. Keep the cursor in the same position before resuming.";
      await publish(active);
      return lastStatus;
    case "resume":
      if (active?.state !== "paused") throw new Error("There is no paused session.");
      active.state = active.resumeState || "typing";
      active.message = "Resumed in the locked tab.";
      await publish(active);
      return lastStatus;
    case "stop": stop(); return lastStatus;
    default: throw new Error("Unknown command.");
  }
}

chrome.runtime.onMessage.addListener((message, sender, respond) => {
  if (sender.id !== chrome.runtime.id || !sender.url?.startsWith(chrome.runtime.getURL("studio.html"))) return;
  handle(message).then(value => respond({ ok: true, value }), error => respond({ ok: false, error: error.message }));
  return true;
});
chrome.action.onClicked.addListener(tab => {
  void chrome.tabs.create({ url: chrome.runtime.getURL(`studio.html?target=${tab.id}`) });
});
chrome.commands.onCommand.addListener(name => { if (name === "stop-typing") stop(); });
chrome.tabs.onRemoved.addListener(tabId => { if (active?.tabId === tabId) stop("The destination tab was closed."); });
chrome.tabs.onUpdated.addListener((tabId, change) => {
  if (active?.tabId === tabId && (change.status === "loading" || change.discarded || (change.url && change.url !== active.url))) {
    stop("The destination navigated, reloaded, or was discarded. The session was stopped.");
  }
});
chrome.debugger.onDetach.addListener(source => {
  if (active?.tabId === source.tabId && runningStates.has(active.state)) stop("The browser connection ended. Check the destination before restarting.");
});
chrome.debugger.onEvent.addListener((source, method, params) => {
  if (active?.tabId === source.tabId && method === "Page.frameNavigated" && !params.frame?.parentId) {
    stop("The destination navigated. The session was stopped.");
  }
});
