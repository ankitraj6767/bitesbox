'use client';

import * as React from 'react';
import Link from 'next/link';
import { LogOut, Menu, UserRound } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuTrigger,
} from '@/components/ui/overlays';
import { CommandPalette } from './command-palette';
import { BranchStatusControl } from './branch-status-control';
import { initials, humanise } from '@/lib/utils';
import type { BranchOrderingState, Session } from '@bitesbox/shared-types';

export function Topbar({
    session,
    branch,
    onOpenNav,
}: {
    session: Session;
    branch: BranchOrderingState | null;
    onOpenNav: () => void;
}) {
    const profile = session.profile;
    const permissions = session.permissions ?? [];
    const canManageBranch = permissions.includes('branch.manage');

    return (
        <header className="sticky top-0 z-30 flex h-14 shrink-0 items-center gap-3 border-b border-hairline bg-canvas/85 px-4 backdrop-blur-md lg:px-6">
            <Button
                variant="ghost"
                size="iconSm"
                className="lg:hidden"
                onClick={onOpenNav}
                aria-label="Open navigation"
            >
                <Menu aria-hidden />
            </Button>

            <div className="flex-1">
                <CommandPalette permissions={permissions} />
            </div>

            {branch && canManageBranch ? <BranchStatusControl branch={branch} /> : null}

            <DropdownMenu>
                <DropdownMenuTrigger asChild>
                    <button
                        type="button"
                        className="flex items-center gap-2 rounded-full border border-hairline bg-surface py-1 pr-2.5 pl-1 shadow-xs transition-colors hover:bg-surface-muted"
                        aria-label="Account menu"
                    >
                        <span className="flex size-7 items-center justify-center rounded-full bg-brand-600 text-[11.5px] font-semibold text-white">
                            {initials(profile?.full_name ?? profile?.phone)}
                        </span>
                        <span className="hidden text-left sm:block">
                            <span className="block max-w-32 truncate text-[13px] leading-tight font-medium text-ink">
                                {profile?.full_name ?? 'Staff'}
                            </span>
                            <span className="block text-[11px] leading-tight text-ink-muted">
                                {humanise(session.primary_role ?? '')}
                            </span>
                        </span>
                    </button>
                </DropdownMenuTrigger>

                <DropdownMenuContent className="w-60">
                    <DropdownMenuLabel>Signed in</DropdownMenuLabel>
                    <div className="px-2.5 pb-2">
                        <p className="truncate text-[13px] font-medium text-ink">
                            {profile?.full_name ?? 'Staff account'}
                        </p>
                        <p className="truncate text-[12px] text-ink-muted">{profile?.email ?? profile?.phone}</p>
                        <p className="mt-1.5 text-[11.5px] text-ink-muted">
                            {(session.roles ?? []).map((grant) => humanise(grant.role)).join(' · ')}
                        </p>
                    </div>

                    <DropdownMenuSeparator />

                    <DropdownMenuItem asChild>
                        <Link href="/settings/profile">
                            <UserRound />
                            My profile
                        </Link>
                    </DropdownMenuItem>

                    <DropdownMenuSeparator />

                    <DropdownMenuItem asChild destructive>
                        {/* POST so a prefetch can never sign the operator out. */}
                        <form action="/auth/signout" method="post" className="w-full">
                            <button type="submit" className="flex w-full items-center gap-2">
                                <LogOut />
                                Sign out
                            </button>
                        </form>
                    </DropdownMenuItem>
                </DropdownMenuContent>
            </DropdownMenu>
        </header>
    );
}
