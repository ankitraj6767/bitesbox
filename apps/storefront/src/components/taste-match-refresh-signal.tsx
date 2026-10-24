"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { tasteMatchOrderRefreshSubscription } from "@/lib/taste-match-refresh";

export function TasteMatchRefreshSignal({ userId }: { userId: string | null }) {
  const router = useRouter();

  React.useEffect(() => {
    if (!userId) return;
    const client = createSupabaseBrowserClient();
    const subscription = tasteMatchOrderRefreshSubscription(userId, () =>
      router.refresh(),
    );
    const channel = client
      .channel(subscription.channelName)
      .on("postgres_changes", subscription.changes[0], subscription.onChange)
      .on("postgres_changes", subscription.changes[1], subscription.onChange)
      .on("postgres_changes", subscription.changes[2], subscription.onChange)
      .subscribe();
    return () => {
      void client.removeChannel(channel);
    };
  }, [router, userId]);

  return null;
}
