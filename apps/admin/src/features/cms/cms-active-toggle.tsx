"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { useMutation } from "@tanstack/react-query";
import { toast } from "sonner";
import { Switch } from "@/components/ui/form-controls";
import { Tooltip } from "@/components/ui/overlays";
import { createSupabaseBrowserClient } from "@/lib/supabase/client";
import { errorMessage } from "@/lib/errors";

type ActiveTable = "cms_sections" | "cms_banners";

export function CmsActiveToggle({
  table,
  id,
  isActive,
  label,
}: {
  table: ActiveTable;
  id: string;
  isActive: boolean;
  label: string;
}) {
  const router = useRouter();
  const [optimistic, setOptimistic] = React.useState(isActive);

  React.useEffect(() => setOptimistic(isActive), [isActive]);

  const mutation = useMutation({
    mutationFn: async (next: boolean) => {
      const supabase = createSupabaseBrowserClient();
      const { error } = await supabase
        .from(table)
        .update({ is_active: next })
        .eq("id", id);
      if (error) throw error;
      return next;
    },
    onSuccess: (next) => {
      toast.success(next ? `${label} is live` : `${label} hidden`);
      router.refresh();
    },
    onError: (error) => {
      setOptimistic(isActive);
      toast.error(errorMessage(error));
    },
  });

  return (
    <Tooltip content={optimistic ? `Hide ${label}` : `Show ${label}`}>
      <Switch
        checked={optimistic}
        disabled={mutation.isPending}
        onCheckedChange={(next) => {
          setOptimistic(next);
          mutation.mutate(next);
        }}
        aria-label={`${optimistic ? "Hide" : "Show"} ${label}`}
      />
    </Tooltip>
  );
}
