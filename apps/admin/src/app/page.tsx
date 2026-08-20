import { redirect } from 'next/navigation';
import { getSession } from '@/lib/session';

/** The console has no marketing surface — send people where they can work. */
export default async function RootPage() {
    const session = await getSession();
    redirect(session.authenticated ? '/overview' : '/login');
}
