'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { Command } from 'cmdk';
import { useQuery } from '@tanstack/react-query';
import { ClipboardList, CornerDownLeft, Search, UsersRound } from 'lucide-react';
import { Dialog, DialogContent } from '@/components/ui/overlays';
import { visibleNavigation } from '@/lib/navigation';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { money, humanise } from '@/lib/utils';

/**
 * ⌘K palette. Navigates the console and jumps straight to an order by number or
 * a customer by name/phone. Search runs through PostgREST, so RLS still applies.
 */
export function CommandPalette({ permissions }: { permissions: string[] }) {
    const router = useRouter();
    const [open, setOpen] = React.useState(false);
    const [term, setTerm] = React.useState('');

    React.useEffect(() => {
        const onKeyDown = (event: KeyboardEvent) => {
            if (event.key === 'k' && (event.metaKey || event.ctrlKey)) {
                event.preventDefault();
                setOpen((value) => !value);
            }
        };

        document.addEventListener('keydown', onKeyDown);
        return () => document.removeEventListener('keydown', onKeyDown);
    }, []);

    const groups = React.useMemo(() => visibleNavigation(permissions), [permissions]);
    const canSeeOrders = permissions.includes('order.view');
    const canSeeCustomers = permissions.includes('customer.view');

    const search = term.trim();
    const enabled = open && search.length >= 2;

    const { data: orders = [] } = useQuery({
        queryKey: ['palette', 'orders', search],
        enabled: enabled && canSeeOrders,
        staleTime: 15_000,
        queryFn: async () => {
            const supabase = createSupabaseBrowserClient();
            const { data, error } = await supabase
                .from('orders')
                .select('id, order_number, status, grand_total, customer_name')
                .or(`order_number.ilike.%${search}%,customer_phone.ilike.%${search}%`)
                .order('created_at', { ascending: false })
                .limit(6);

            if (error) throw error;
            return data ?? [];
        },
    });

    const { data: customers = [] } = useQuery({
        queryKey: ['palette', 'customers', search],
        enabled: enabled && canSeeCustomers,
        staleTime: 15_000,
        queryFn: async () => {
            const supabase = createSupabaseBrowserClient();
            const { data, error } = await supabase
                .from('profiles')
                .select('id, full_name, phone, completed_orders')
                .or(`full_name.ilike.%${search}%,phone.ilike.%${search}%`)
                .is('deleted_at', null)
                .limit(6);

            if (error) throw error;
            return data ?? [];
        },
    });

    const go = (href: string) => {
        setOpen(false);
        setTerm('');
        router.push(href);
    };

    return (
        <>
            <button
                type="button"
                onClick={() => setOpen(true)}
                className="flex h-9 w-full max-w-xs items-center gap-2 rounded-[var(--radius-control)] border border-hairline bg-surface px-3 text-left text-[13px] text-ink-muted shadow-xs transition-colors hover:bg-surface-muted"
            >
                <Search className="size-4 shrink-0" aria-hidden />
                <span className="flex-1 truncate">Search orders, customers…</span>
                <kbd className="hidden shrink-0 rounded border border-hairline bg-surface-muted px-1.5 py-0.5 font-mono text-[10.5px] text-ink-muted sm:block">
                    ⌘K
                </kbd>
            </button>

            <Dialog open={open} onOpenChange={setOpen}>
                <DialogContent size="md" className="p-0">
                    <Command label="Command palette" shouldFilter={false} className="overflow-hidden">
                        <div className="flex items-center gap-2 border-b border-hairline px-4">
                            <Search className="size-4 shrink-0 text-ink-muted" aria-hidden />
                            <Command.Input
                                value={term}
                                onValueChange={setTerm}
                                autoFocus
                                placeholder="Jump to a screen, order number or customer…"
                                className="h-12 flex-1 bg-transparent text-sm text-ink outline-none placeholder:text-ink-muted/70"
                            />
                        </div>

                        <Command.List className="scroll-slim max-h-80 overflow-y-auto p-2">
                            <Command.Empty className="px-3 py-8 text-center text-[13px] text-ink-muted">
                                {search.length < 2 ? 'Type at least two characters.' : 'No matches found.'}
                            </Command.Empty>

                            {orders.length > 0 ? (
                                <Command.Group
                                    heading="Orders"
                                    className="[&_[cmdk-group-heading]]:px-2.5 [&_[cmdk-group-heading]]:py-1.5 [&_[cmdk-group-heading]]:text-[10.5px] [&_[cmdk-group-heading]]:font-semibold [&_[cmdk-group-heading]]:tracking-wider [&_[cmdk-group-heading]]:text-ink-muted [&_[cmdk-group-heading]]:uppercase"
                                >
                                    {orders.map((order) => (
                                        <Command.Item
                                            key={order.id}
                                            value={`order-${order.id}`}
                                            onSelect={() => go(`/orders/${order.id}`)}
                                            className="flex cursor-pointer items-center gap-2.5 rounded-md px-2.5 py-2 text-[13px] text-ink data-[selected=true]:bg-surface-muted"
                                        >
                                            <ClipboardList className="size-4 shrink-0 text-ink-muted" aria-hidden />
                                            <span className="min-w-0 flex-1">
                                                <span className="block truncate font-medium">{order.order_number}</span>
                                                <span className="block truncate text-[12px] text-ink-muted">
                                                    {order.customer_name ?? 'Customer'} · {humanise(order.status)}
                                                </span>
                                            </span>
                                            <span className="tnum shrink-0 text-[12.5px] text-ink-muted">
                                                {money(order.grand_total)}
                                            </span>
                                        </Command.Item>
                                    ))}
                                </Command.Group>
                            ) : null}

                            {customers.length > 0 ? (
                                <Command.Group
                                    heading="Customers"
                                    className="[&_[cmdk-group-heading]]:px-2.5 [&_[cmdk-group-heading]]:py-1.5 [&_[cmdk-group-heading]]:text-[10.5px] [&_[cmdk-group-heading]]:font-semibold [&_[cmdk-group-heading]]:tracking-wider [&_[cmdk-group-heading]]:text-ink-muted [&_[cmdk-group-heading]]:uppercase"
                                >
                                    {customers.map((customer) => (
                                        <Command.Item
                                            key={customer.id}
                                            value={`customer-${customer.id}`}
                                            onSelect={() => go(`/customers/${customer.id}`)}
                                            className="flex cursor-pointer items-center gap-2.5 rounded-md px-2.5 py-2 text-[13px] text-ink data-[selected=true]:bg-surface-muted"
                                        >
                                            <UsersRound className="size-4 shrink-0 text-ink-muted" aria-hidden />
                                            <span className="min-w-0 flex-1">
                                                <span className="block truncate font-medium">
                                                    {customer.full_name ?? 'Unnamed customer'}
                                                </span>
                                                <span className="block truncate text-[12px] text-ink-muted">
                                                    {customer.phone} · {customer.completed_orders} orders
                                                </span>
                                            </span>
                                        </Command.Item>
                                    ))}
                                </Command.Group>
                            ) : null}

                            {groups.map((group) => {
                                const items = group.items.filter((item) =>
                                    search.length < 2
                                        ? true
                                        : `${item.label} ${item.description}`.toLowerCase().includes(search.toLowerCase()),
                                );

                                if (items.length === 0) return null;

                                return (
                                    <Command.Group
                                        key={group.label}
                                        heading={group.label}
                                        className="[&_[cmdk-group-heading]]:px-2.5 [&_[cmdk-group-heading]]:py-1.5 [&_[cmdk-group-heading]]:text-[10.5px] [&_[cmdk-group-heading]]:font-semibold [&_[cmdk-group-heading]]:tracking-wider [&_[cmdk-group-heading]]:text-ink-muted [&_[cmdk-group-heading]]:uppercase"
                                    >
                                        {items.map((item) => (
                                            <Command.Item
                                                key={item.href}
                                                value={`nav-${item.href}`}
                                                onSelect={() => go(item.href)}
                                                className="flex cursor-pointer items-center gap-2.5 rounded-md px-2.5 py-2 text-[13px] text-ink data-[selected=true]:bg-surface-muted"
                                            >
                                                <item.icon className="size-4 shrink-0 text-ink-muted" />
                                                <span className="min-w-0 flex-1">
                                                    <span className="block truncate font-medium">{item.label}</span>
                                                    <span className="block truncate text-[12px] text-ink-muted">
                                                        {item.description}
                                                    </span>
                                                </span>
                                                <CornerDownLeft className="size-3.5 shrink-0 text-ink-muted/60" aria-hidden />
                                            </Command.Item>
                                        ))}
                                    </Command.Group>
                                );
                            })}
                        </Command.List>
                    </Command>
                </DialogContent>
            </Dialog>
        </>
    );
}
