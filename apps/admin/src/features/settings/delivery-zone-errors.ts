export function messageForDeliveryZoneDatabaseError(
  code: string | undefined,
): string {
  switch (code) {
    case "23505":
      return "A delivery zone with this name already exists for the selected outlet.";
    case "42501":
      return "The database could not complete the authorization check for this change. Refresh and try again; if it continues, contact support.";
    case "23514":
      return "Some delivery zone values are outside the allowed range. Review the form and try again.";
    default:
      return "The delivery zone could not be saved. Please try again.";
  }
}
