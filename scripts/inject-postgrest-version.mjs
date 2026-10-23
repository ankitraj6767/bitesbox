import { readFileSync, writeFileSync } from "node:fs";

const [filePath] = process.argv.slice(2);

if (!filePath) {
  throw new Error(
    "Usage: node scripts/inject-postgrest-version.mjs <types-file>",
  );
}

const source = readFileSync(filePath, "utf8");

const databaseHeader = source.match(
  /export type Database = \{([\s\S]*?)\n  public: \{/,
);

if (!databaseHeader) {
  throw new Error(
    `${filePath} does not contain the expected public Database schema`,
  );
}

// Supabase CLI versions differ on whether they emit these explanatory
// comments. Keep generated types stable across the CLI versions used locally
// and in CI by removing them from the Database header.
const normalizedHeader = databaseHeader[0]
  .replace(
    /^  \/\/ Allows to automatically instantiate createClient with right options\n/m,
    "",
  )
  .replace(
    /^  \/\/ instead of createClient<Database, \{ PostgrestVersion: 'XX' \}>\(URL, KEY\)\n/m,
    "",
  );
const normalizedSource = source.replace(databaseHeader[0], normalizedHeader);

const normalizedDatabaseHeader = normalizedHeader.match(
  /export type Database = \{([\s\S]*?)\n  public: \{/,
);

if (!normalizedDatabaseHeader) {
  throw new Error(
    `${filePath} does not contain the expected public Database schema`,
  );
}

const internalPostgrestVersion = normalizedDatabaseHeader[1].match(
  /__InternalSupabase:\s*\{\s*PostgrestVersion:\s*"([^"]+)"/s,
);

if (internalPostgrestVersion) {
  if (internalPostgrestVersion[1] === "14.15") {
    if (normalizedSource !== source) {
      writeFileSync(filePath, normalizedSource);
    }
    process.exit(0);
  }
  throw new Error(`${filePath} has an unexpected __InternalSupabase version`);
}

const databaseType = "export type Database = {\n";

if (!normalizedSource.includes(databaseType)) {
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

writeFileSync(
  filePath,
  normalizedSource.replace(databaseType, `${postgrestVersion}\n`),
);
