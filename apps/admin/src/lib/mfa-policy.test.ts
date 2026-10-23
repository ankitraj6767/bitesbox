import { describe, expect, it } from 'vitest';
import { hasBackOfficeRole, safeAdminNextPath, staffNeedsMfa } from './mfa-policy';

describe('staff MFA routing policy', () => {
    it('requires signed AAL2 for every back-office role', () => {
        for (const role of ['OWNER', 'ADMIN', 'MANAGER', 'OPERATIONS', 'FINANCE', 'SUPPORT', 'MARKETING']) {
            expect(staffNeedsMfa([role], 'aal1')).toBe(true);
            expect(staffNeedsMfa([role], null)).toBe(true);
            expect(staffNeedsMfa([role], 'aal2')).toBe(false);
        }
    });

    it('does not require staff MFA for customers or unknown roles', () => {
        expect(hasBackOfficeRole(['CUSTOMER'])).toBe(false);
        expect(staffNeedsMfa(['CUSTOMER'], 'aal1')).toBe(false);
        expect(staffNeedsMfa([], undefined)).toBe(false);
    });

    it('accepts only same-origin relative destinations', () => {
        expect(safeAdminNextPath('/refunds')).toBe('/refunds');
        expect(safeAdminNextPath('//attacker.example')).toBeNull();
        expect(safeAdminNextPath('https://attacker.example')).toBeNull();
        expect(safeAdminNextPath(null)).toBeNull();
    });
});
