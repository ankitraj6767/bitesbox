/**
 * RPC proxy.
 *
 * Several operations are already fully guarded inside Postgres (permission checks,
 * state-machine validation, rate limits). Exposing them as Edge Functions still
 * buys three things over a direct RPC call:
 *
 *   · one uniform error contract across the whole API
 *   · request validation and coercion before the database is touched
 *   · structured request logging with a request id the support team can trace
 *
 * The caller's own JWT is used, so RLS and app.has_permission() still decide what
 * is allowed. These functions hold no privilege of their own.
 */

import { jsonResponse, readJson, serveFunction } from "./http.ts";
import { requireCaller, rpc, userClient } from "./supabase.ts";
import { logger } from "./logger.ts";

export interface ProxyOptions {
    /** Function name in the `public` schema. */
    rpcName: string;
    /** Maps the validated request body onto RPC arguments. */
    mapArgs: (body: Record<string, unknown>, req: Request) => Record<string, unknown>;
    /** Allow unauthenticated access (guest menu browsing). */
    allowAnonymous?: boolean;
    /** HTTP status for a successful call. */
    successStatus?: number;
    /** Extra fields to include in the log line. */
    logFields?: (body: Record<string, unknown>) => Record<string, unknown>;
}

export function serveRpcProxy(functionName: string, options: ProxyOptions): void {
    serveFunction(functionName, async ({ req, requestId, origin }) => {
        const body = await readJson<Record<string, unknown>>(req);

        let actorId: string | null = null;
        if (!options.allowAnonymous) {
            const caller = await requireCaller(req);
            actorId = caller.userId;
        }

        const client = userClient(req);
        const args = options.mapArgs(body, req);

        const data = await rpc<unknown>(client, options.rpcName, args);

        logger.info("proxy.ok", {
            fn: functionName,
            request_id: requestId,
            rpc: options.rpcName,
            actor: actorId,
            ...(options.logFields?.(body) ?? {}),
        });

        return jsonResponse(data, {
            status: options.successStatus ?? 200,
            origin,
            requestId,
        });
    });
}
