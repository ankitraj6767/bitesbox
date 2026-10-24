export function tasteMatchOrderRefreshSubscription(
  userId: string,
  refresh: () => void,
) {
  return {
    channelName: `taste-match-updates:${userId}`,
    changes: [
      {
        event: "UPDATE" as const,
        schema: "public" as const,
        table: "orders" as const,
        filter: `user_id=eq.${userId}`,
      },
      {
        event: "*" as const,
        schema: "public" as const,
        table: "customer_favorites" as const,
        filter: `user_id=eq.${userId}`,
      },
      {
        event: "*" as const,
        schema: "public" as const,
        table: "customer_taste_profiles" as const,
        filter: `user_id=eq.${userId}`,
      },
    ] as const,
    onChange: refresh,
  };
}
