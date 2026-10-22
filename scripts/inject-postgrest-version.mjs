import { readFileSync, writeFileSync } from "node:fs";

const [filePath] = process.argv.slice(2);

if (!filePath) {
  throw new Error(
    "Usage: node scripts/inject-postgrest-version.mjs <types-file>",
  );
}

const source = readFileSync(filePath, "utf8");

const existingPostgrestVersion =
  /export type Database = \{\s*__InternalSupabase:\s*\{\s*PostgrestVersion: "14\.15";?\s*\};/s;
const databaseHeader = source.match(
  /export type Database = \{([\s\S]*?)\n  public: \{/,
);

if (existingPostgrestVersion.test(source)) {
  process.exit(0);
}

if (!databaseHeader) {
  throw new Error(
    `${filePath} does not contain the expected public Database schema`,
  );
}

if (databaseHeader[1].includes("__InternalSupabase")) {
  throw new Error(`${filePath} has an unexpected __InternalSupabase version`);
}

const databaseType = "export type Database = {\n";

if (!source.includes(databaseType)) {
  throw new Error(
    `${filePath} does not contain the expected Database type declaration`,
  );
}

const postgrestVersion = [
  "export type Database = {",
  // Keep the PostgREST 14 capability type used by the app's Supabase client.
  "  __InternalSupabase: {",
  '    PostgrestVersion: "14.15";',
  "  };",
].join("\n");

writeFileSync(filePath, source.replace(databaseType, `${postgrestVersion}\n`));
