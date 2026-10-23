import * as Sentry from "@sentry/nextjs";
import { scrubSentryEvent } from "./src/lib/telemetry/scrub";

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  environment: process.env.NEXT_PUBLIC_APP_ENV ?? process.env.NODE_ENV,
  release: process.env.NEXT_PUBLIC_APP_RELEASE,
  sendDefaultPii: false,
  tracesSampleRate: 0,
  beforeSend: scrubSentryEvent,
  beforeBreadcrumb(breadcrumb) {
    return { ...breadcrumb, data: undefined };
  },
});
