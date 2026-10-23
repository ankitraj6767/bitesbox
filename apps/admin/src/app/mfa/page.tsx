import type { Metadata } from 'next';
import { MfaExperience } from './mfa-experience';

export const metadata: Metadata = { title: 'Staff sign-in security' };

export default async function MfaPage({
    searchParams,
}: {
    searchParams: Promise<{ next?: string }>;
}) {
    const { next } = await searchParams;
    const safeNext = next?.startsWith('/') && !next.startsWith('//') ? next : '/overview';
    return <MfaExperience nextPath={safeNext} />;
}
