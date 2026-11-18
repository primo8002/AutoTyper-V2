// Pure operation generator. The browser transport never receives the whole draft.
export const defaults = { wpm: 60, mistakes: true, mistakeRate: 2, naturalPauses: true };

export function validateSession(input) {
  if (!input || typeof input.text !== "string" || !input.text.trim()) throw new Error("Add some text first.");
  if (input.text.length > 100_000) throw new Error("Use at most 100,000 characters per session.");
  const wpm = Number(input.wpm ?? defaults.wpm);
  const mistakeRate = Number(input.mistakeRate ?? defaults.mistakeRate);
  if (!Number.isFinite(wpm) || wpm < 15 || wpm > 150) throw new Error("Speed must be 15–150 WPM.");
  if (!Number.isFinite(mistakeRate) || mistakeRate < 0 || mistakeRate > 6) throw new Error("Mistake frequency must be 0–6%.");
  return { text: input.text.replace(/\r\n?/g, "\n"), wpm, mistakeRate,
    mistakes: input.mistakes ?? defaults.mistakes, naturalPauses: input.naturalPauses ?? defaults.naturalPauses };
}

const neighbors = {
  a: "sqw", b: "vgn", c: "xvd", d: "sfer", e: "wrsd", f: "dgrt", g: "fhty",
  h: "gjyu", i: "uokj", j: "huki", k: "jlio", l: "kop", m: "njk", n: "bhjm",
  o: "ipkl", p: "ol", q: "wa", r: "etdf", s: "awed", t: "ryfg", u: "yihj",
  v: "cfgb", w: "qeas", x: "zcs", y: "tugh", z: "asx"
};
export function graphemes(text) {
  return Array.from(new Intl.Segmenter(undefined, { granularity: "grapheme" }).segment(text), item => item.segment);
}

export function* operations(input, random = Math.random) {
  const settings = validateSession(input);
  const chars = graphemes(settings.text);
  const between = (low, high) => low + random() * (high - low);
  const integer = (low, high) => Math.floor(between(low, high + 1));
  let burst = 1;
  let remaining = 0;
  let breakAt = integer(35, 80);
  const delay = () => ({ kind: "wait", ms: 12_000 / settings.wpm * burst * between(0.7, 1.3) });

  for (let i = 0; i < chars.length;) {
    if (--remaining <= 0) { burst = between(0.8, 1.2); remaining = integer(4, 18); }
    const char = chars[i];
    if (settings.mistakes && /^[a-z]$/i.test(char) && random() * 100 < settings.mistakeRate) {
      const choices = neighbors[char.toLowerCase()];
      let wrong = choices[integer(0, choices.length - 1)];
      if (char === char.toUpperCase()) wrong = wrong.toUpperCase();
      yield { kind: "text", text: wrong };
      let ahead = 0;
      const maxAhead = integer(0, 2);
      // Delayed corrections only cross ASCII letters: one Backspace per character is reliable.
      while (ahead < maxAhead && /^[a-z]$/i.test(chars[i + ahead + 1] ?? "")) {
        yield delay();
        yield { kind: "text", text: chars[i + ++ahead] };
      }
      yield { kind: "wait", ms: between(100, 430) };
      for (let n = 0; n <= ahead; n++) {
        yield { kind: "backspace" };
        yield { kind: "wait", ms: between(45, 110) };
      }
      for (let n = 0; n <= ahead; n++) {
        yield { kind: "text", text: chars[i + n] };
        yield { kind: "wait", ms: between(40, 110) };
      }
      i += ahead + 1;
    } else {
      yield { kind: "text", text: char };
      i++;
    }
    yield { kind: "progress", value: i, total: chars.length };
    if (i < chars.length) {
      yield delay();
      if (settings.naturalPauses) {
        const last = chars[i - 1];
        if (/[.!?\n]/.test(last)) yield { kind: "wait", ms: between(250, 800) };
        else if (/[,;:]/.test(last)) yield { kind: "wait", ms: between(100, 330) };
        if (i >= breakAt) {
          yield { kind: "wait", ms: between(300, 1000) };
          breakAt = i + integer(35, 80);
        }
      }
    }
  }
}
