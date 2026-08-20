'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { toast } from 'sonner';
import { Eye, EyeOff } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Field, Input } from '@/components/ui/form-controls';
import { InlineNotice } from '@/components/ui/states';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { errorMessage } from '@/lib/errors';

const schema = z.object({
    email: z.string().min(1, 'Enter your email address').email('That does not look like an email'),
    password: z.string().min(6, 'Passwords are at least 6 characters'),
});

type FormValues = z.infer<typeof schema>;

export function LoginForm({
    nextPath,
    initialError,
}: {
    nextPath?: string;
    initialError?: string;
}) {
    const router = useRouter();
    const [showPassword, setShowPassword] = React.useState(false);
    const [formError, setFormError] = React.useState<string | null>(initialError ?? null);

    const {
        register,
        handleSubmit,
        formState: { errors, isSubmitting },
    } = useForm<FormValues>({
        resolver: zodResolver(schema),
        defaultValues: { email: '', password: '' },
    });

    const onSubmit = async (values: FormValues) => {
        setFormError(null);
        const supabase = createSupabaseBrowserClient();

        const { data, error } = await supabase.auth.signInWithPassword({
            email: values.email.trim().toLowerCase(),
            password: values.password,
        });

        if (error) {
            // Deliberately generic: never reveal whether the address exists.
            setFormError(
                error.status === 400
                    ? 'Those credentials do not match an account.'
                    : errorMessage(error),
            );
            return;
        }

        // A signed-in customer must not land in the back office.
        const { data: session } = await supabase.rpc('my_session');
        const roles = (session as { roles?: Array<{ role: string }> } | null)?.roles ?? [];
        const backOffice = roles.some((grant) =>
            ['OWNER', 'ADMIN', 'MANAGER', 'OPERATIONS', 'FINANCE', 'SUPPORT', 'MARKETING'].includes(
                grant.role,
            ),
        );

        if (!backOffice) {
            await supabase.auth.signOut();
            setFormError('This account does not have access to the Bites Box admin console.');
            return;
        }

        toast.success(`Welcome back, ${data.user.user_metadata?.full_name ?? 'there'}`);

        const target = nextPath && nextPath.startsWith('/') ? nextPath : '/overview';
        router.replace(target);
        router.refresh();
    };

    return (
        <form onSubmit={handleSubmit(onSubmit)} className="mt-7 space-y-4" noValidate>
            {formError ? <InlineNotice tone="critical">{formError}</InlineNotice> : null}

            <Field label="Email address" htmlFor="email" required error={errors.email?.message}>
                <Input
                    id="email"
                    type="email"
                    autoComplete="email"
                    autoFocus
                    placeholder="manager@bitesbox.in"
                    aria-invalid={Boolean(errors.email)}
                    {...register('email')}
                />
            </Field>

            <Field label="Password" htmlFor="password" required error={errors.password?.message}>
                <div className="relative">
                    <Input
                        id="password"
                        type={showPassword ? 'text' : 'password'}
                        autoComplete="current-password"
                        placeholder="••••••••"
                        className="pr-10"
                        aria-invalid={Boolean(errors.password)}
                        {...register('password')}
                    />
                    <button
                        type="button"
                        onClick={() => setShowPassword((value) => !value)}
                        className="absolute top-1/2 right-2 -translate-y-1/2 rounded-md p-1.5 text-ink-muted transition-colors hover:bg-surface-muted hover:text-ink"
                        aria-label={showPassword ? 'Hide password' : 'Show password'}
                    >
                        {showPassword ? <EyeOff className="size-4" aria-hidden /> : <Eye className="size-4" aria-hidden />}
                    </button>
                </div>
            </Field>

            <Button type="submit" size="lg" className="w-full" loading={isSubmitting}>
                Sign in
            </Button>
        </form>
    );
}
