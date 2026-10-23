import type { Event, EventHint } from "@sentry/nextjs";

const redactText = (value: string) =>
  value
    .replace(/\bBearer\s+[A-Za-z0-9._~+/-]+=*/gi, "Bearer [redacted]")
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, "[email]")
    .replace(/(?:\+?\d[\d\s().-]{7,}\d)/g, "[phone]")
    .replace(
      /data:image\/[a-zA-Z0-9.+-]+;base64,[A-Za-z0-9+/=]+/g,
      "[image redacted]",
    )
    .replace(/https?:\/\/[^\s?]+\?[^\s)]+/gi, "[url with query redacted]")
    .replace(/[A-Za-z0-9_-]{80,}/g, "[long value redacted]")
    .slice(0, 2000);

function safePath(path: string): string {
  return path
    .split("/")
    .map((segment) =>
      /^[0-9a-f-]{24,}$/i.test(segment) || /^\d{6,}$/.test(segment)
        ? "[id]"
        : segment,
    )
    .join("/");
}

export function scrubSentryEvent<T extends Event>(
  event: T,
  _hint?: EventHint,
): T | null {
  event.user = undefined;
  if (event.request) {
    const rawUrl = event.request.url;
    if (rawUrl) {
      try {
        const parsed = new URL(rawUrl);
        event.request.url = `${parsed.origin}${safePath(parsed.pathname)}`;
      } catch {
        event.request.url = "[url redacted]";
      }
    }
    event.request.headers = undefined;
    event.request.cookies = undefined;
    event.request.data = undefined;
    event.request.query_string = undefined;
  }
  if (event.exception?.values) {
    event.exception.values = event.exception.values.map((item) => ({
      ...item,
      value: item.value ? redactText(item.value) : item.value,
    }));
  }
  if (event.message) event.message = redactText(event.message);
  if (event.breadcrumbs) {
    event.breadcrumbs = event.breadcrumbs.map((breadcrumb) => ({
      ...breadcrumb,
      message: breadcrumb.message
        ? redactText(breadcrumb.message)
        : breadcrumb.message,
      data: undefined,
    }));
  }
  if (event.tags) {
    event.tags = Object.fromEntries(
      Object.entries(event.tags)
        .filter(
          ([key]) =>
            !/(email|phone|address|token|secret|authorization|customer|rider)/i.test(
              key,
            ),
        )
        .map(([key, value]) => [
          key,
          typeof value === "string" ? redactText(value) : value,
        ]),
    );
  }
  event.extra = undefined;
  return event;
}
