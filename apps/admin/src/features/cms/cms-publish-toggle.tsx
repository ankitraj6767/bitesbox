"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { useMutation } from "@tanstack/react-query";
import { toast } from "sonner";
import { Switch } from "@/components/ui/form-controls";
import { Tooltip } from "@/components/ui/overlays";
import { createSupabaseBrowserClient } from "@/lib/supabase/client";
import { errorMessage } from "@/lib/errors";

type PublishTable = "cms_documents" | "cms_faqs";

export function CmsPublishToggle({
  table,
  id,
  isPublished,
  label,
}: {
  table: PublishTable;
  id: string;
  isPublished: boolean;
  label: string;
}) {
  const router = useRouter();
  const [optimistic, setOptimistic] = React.useState(isPublished);

  React.useEffect(() => setOptimistic(isPublished), [isPublished]);

  const mutation = useMutation({
    mutationFn: async (next: boolean) => {
      const supabase = createSupabaseBrowserClient();
      const { error } = await supabase
        .from(table)
        .update({ is_published: next })
        .eq("id", id);
      if (error) throw error;
      return next;
    },
    onSuccess: (next) => {
      toast.success(next ? `${label} published` : `${label} unpublished`);
      router.refresh();
    },
    onError: (error) => {
      setOptimistic(isPublished);
      toast.error(errorMessage(error));
    },
  });

  return (
    <Tooltip content={optimistic ? `Unpublish ${label}` : `Publish ${label}`}>
      <Switch
        checked={optimistic}
        disabled={mutation.isPending}
        onCheckedChange={(next) => {
          setOptimistic(next);
          mutation.mutate(next);
        }}
        aria-label={`${optimistic ? "Unpublish" : "Publish"} ${label}`}
      />
    </Tooltip>
  );
}
