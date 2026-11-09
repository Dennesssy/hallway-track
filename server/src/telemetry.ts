// Hook owned by the observability milestone (M4). Intentionally a no-op until then.
export function initTelemetry(): void {
  // no-op
}

/** Current trace id for the active request, or null when tracing is off. */
export function currentTraceId(): string | null {
  return null;
}
