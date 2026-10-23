"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { useMutation } from "@tanstack/react-query";
import { toast } from "sonner";
import { Banknote } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/ui/overlays";
import { createSupabaseBrowserClient } from "@/lib/supabase/client";
import { errorMessage } from "@/lib/errors";
import { money } from "@/lib/utils";

interface CodSettlementResult {
  settled_amount: number;
  order_count: number;
}

/** Records a physical cash handover through the permission-checked database RPC. */
export function CodSettlementAction({
  riderId,
  riderName,
  orderId,
  orderNumber,
  amount,
}: {
  riderId: string;
  riderName: string;
  orderId: string;
  orderNumber: string;
  amount: number;
}) {
  const router = useRouter();
  const [confirming, setConfirming] = React.useState(false);

  const settlement = useMutation({
    mutationFn: async () => {
      const supabase = createSupabaseBrowserClient();
      const { data, error } = await supabase.rpc("settle_cod", {
        p_delivery_partner_id: riderId,
        p_order_ids: [orderId],
        p_note: `Cash handover received at outlet for ${orderNumber}`,
      });
      if (error) throw error;
      const result = data as unknown as Partial<CodSettlementResult> | null;
      if (
        !result ||
        typeof result.settled_amount !== "number" ||
        typeof result.order_count !== "number"
      ) {
        throw new Error(
          "The cash handover could not be confirmed. Refresh and check the settlement list.",
        );
      }
      return result as CodSettlementResult;
    },
    onSuccess: (result) => {
      setConfirming(false);
      if (result.order_count === 0) {
        toast.info(
          "This COD collection was already settled. The payment list has been refreshed.",
        );
      } else {
        toast.success(
          `${money(result.settled_amount, true)} cash handover recorded for ${riderName}.`,
        );
      }
      router.refresh();
    },
    onError: (error) => toast.error(errorMessage(error)),
  });

  return (
    <>
      <Button
        size="sm"
        variant="secondary"
        onClick={() => setConfirming(true)}
        disabled={settlement.isPending}
        aria-label={`Record cash handover for order ${orderNumber}`}
      >
        <Banknote />
        Settle
      </Button>
      <ConfirmDialog
        open={confirming}
        onOpenChange={setConfirming}
        title="Confirm COD cash handover"
        description={
          <>
            Confirm that <strong>{money(amount, true)}</strong> for order{" "}
            <strong>{orderNumber}</strong> was physically handed to the outlet
            by <strong>{riderName}</strong>. This records the collection as
            settled, updates the rider’s cash balance and creates an audit
            entry. Do not confirm until the cash is received.
          </>
        }
        confirmText="SETTLE CASH"
        confirmLabel="Record handover"
        loading={settlement.isPending}
        onConfirm={() => settlement.mutate()}
      />
    </>
  );
}
