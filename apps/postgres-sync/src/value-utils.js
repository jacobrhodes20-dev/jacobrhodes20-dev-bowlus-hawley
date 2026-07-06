export function toArray(value) {
  if (value === null || value === undefined) return [];
  return Array.isArray(value) ? value : [value];
}

export function firstValue(value) {
  const values = toArray(value);
  return values.length ? values[0] : null;
}

export function firstLinkedId(value) {
  const first = firstValue(value);
  if (!first) return "";
  if (typeof first === "string") return first.trim();
  if (typeof first === "object") return String(first.id || first.value || first.name || "").trim();
  return String(first).trim();
}

export function displayValue(value) {
  const first = firstValue(value);
  if (first === null || first === undefined) return "";
  if (typeof first === "string") return first.trim();
  if (typeof first === "number" || typeof first === "boolean") return String(first);
  if (typeof first === "object") return String(first.name || first.email || first.value || first.id || "").trim();
  return String(first).trim();
}

export function pickField(fields, names) {
  for (const name of names) {
    if (Object.prototype.hasOwnProperty.call(fields, name)) return fields[name];
  }
  return undefined;
}

export function toNumber(value) {
  const raw = firstValue(value);
  if (raw === null || raw === undefined || raw === "") return null;
  if (typeof raw === "object") return toNumber(raw.value ?? raw.name ?? raw.id);
  const number = Number(raw);
  return Number.isFinite(number) ? number : null;
}

export function durationSecondsToHours(value) {
  const number = toNumber(value);
  if (number === null) return null;
  return Math.round((number / 3600) * 100) / 100;
}

export function durationSecondsToMinutes(value) {
  const number = toNumber(value);
  if (number === null) return null;
  return Math.round(number / 60);
}

export function toDateString(value) {
  const raw = firstValue(value);
  if (!raw) return null;
  if (typeof raw === "object") return toDateString(raw.value ?? raw.name);
  const text = String(raw).trim();
  if (!text) return null;
  return text.slice(0, 10);
}
