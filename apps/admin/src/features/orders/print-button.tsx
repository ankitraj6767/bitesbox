'use client';

import { Printer } from 'lucide-react';
import { Button } from '@/components/ui/button';

/**
 * Print / save as PDF. The browser's print dialogue is deliberate: it works
 * offline, needs no PDF dependency, and lets the operator pick a printer or a
 * file without us shipping a rendering service.
 */
export function PrintButton() {
    return (
        <Button variant="secondary" size="sm" data-print-hide onClick={() => window.print()}>
            <Printer />
            Print or save PDF
        </Button>
    );
}
