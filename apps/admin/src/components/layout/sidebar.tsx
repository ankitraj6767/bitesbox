'use client';

import * as React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { UtensilsCrossed, X } from 'lucide-react';
import { cn } from '@/lib/utils';
import { visibleNavigation } from '@/lib/navigation';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';

export interface SidebarCounts {
    live_orders?: number;
    pending_refunds?: number;
    open_tickets?: number;
}

export function Sidebar({
    permissions,
    counts,
    branchName,
    open,
    onClose,
}: {
    permissions: string[];
    counts: SidebarCounts;
    branchName: string;
    open: boolean;
    onClose: () => void;
}) {
    const pathname = usePathname();
    const groups = React.useMemo(() => visibleNavigation(permissions), [permissions]);

    // Close the drawer whenever the route changes on mobile.
    React.useEffect(() => {
        onClose();
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [pathname]);

    return (
        <>
            {/* Mobile scrim */}
            <div
                aria-hidden
                onClick={onClose}
                className={cn(
                    'fixed inset-0 z-40 bg-ink/30 backdrop-blur-[2px] transition-opacity lg:hidden',
                    open ? 'opacity-100' : 'pointer-events-none opacity-0',
                )}
            />

            <aside
                aria-label="Main navigation"
                className={cn(
                    'fixed inset-y-0 left-0 z-50 flex w-[262px] flex-col border-r border-hairline bg-surface transition-transform lg:static lg:translate-x-0',
                    open ? 'translate-x-0' : '-translate-x-full',
                )}
            >
                <div className="flex h-14 shrink-0 items-center justify-between gap-2 border-b border-hairline px-4">
                    <Link href="/overview" className="flex min-w-0 items-center gap-2.5">
                        <span className="flex size-8 shrink-0 items-center justify-center rounded-lg bg-brand-600 text-white">
                            <UtensilsCrossed className="size-4" aria-hidden />
                        </span>
                        <span className="min-w-0">
                            <span className="block truncate font-display text-[15px] leading-tight font-semibold tracking-tight text-ink">
                                Bites Box
                            </span>
                            <span className="block truncate text-[11.5px] leading-tight text-ink-muted">
                                {branchName}
                            </span>
                        </span>
                    </Link>

                    <Button variant="ghost" size="iconSm" className="lg:hidden" onClick={onClose} aria-label="Close navigation">
                        <X aria-hidden />
                    </Button>
                </div>

                <nav className="scroll-slim flex-1 overflow-y-auto px-3 py-4">
                    {groups.map((group) => (
                        <div key={group.label} className="mb-5 last:mb-0">
                            <p className="px-2.5 pb-1.5 text-[10.5px] font-semibold tracking-[0.08em] text-ink-muted/80 uppercase">
                                {group.label}
                            </p>
                            <ul className="space-y-0.5">
                                {group.items.map((item) => {
                                    const active =
                                        pathname === item.href || pathname.startsWith(`${item.href}/`);
                                    const count = item.badgeKey ? counts[item.badgeKey] : undefined;

                                    return (
                                        <li key={item.href}>
                                            <Link
                                                href={item.href}
                                                aria-current={active ? 'page' : undefined}
                                                className={cn(
                                                    'group flex items-center gap-2.5 rounded-[var(--radius-control)] px-2.5 py-2 text-[13.5px] font-medium transition-colors',
                                                    active
                                                        ? 'bg-brand-50 text-brand-700'
                                                        : 'text-ink-muted hover:bg-surface-muted hover:text-ink',
                                                )}
                                            >
                                                <item.icon
                                                    className={cn(
                                                        'size-4 shrink-0',
                                                        active ? 'text-brand-600' : 'text-ink-muted group-hover:text-ink',
                                                    )}
                                                />
                                                <span className="min-w-0 flex-1 truncate">{item.label}</span>
                                                {count && count > 0 ? (
                                                    <Badge tone={active ? 'brand' : 'neutral'} className="px-1.5 py-0 tnum">
                                                        {count > 99 ? '99+' : count}
                                                    </Badge>
                                                ) : null}
                                            </Link>
                                        </li>
                                    );
                                })}
                            </ul>
                        </div>
                    ))}
                </nav>

                <div className="shrink-0 border-t border-hairline px-4 py-3">
                    <p className="text-[11px] leading-relaxed text-ink-muted">
                        Bites Box Operations
                        <span className="mx-1.5 text-hairline">·</span>
                        v1.0.0
                    </p>
                </div>
            </aside>
        </>
    );
}
