const commitMessage = process.env.VERCEL_GIT_COMMIT_MESSAGE ?? "";
const isSourceOnlyChange = commitMessage
  .split(/\s+/)
  .includes("[source-only]");

if (isSourceOnlyChange) {
  console.log("Skipping Vercel build for a source-only main update.");
  process.exit(0);
}

console.log("No source-only marker found; continue with the Vercel build.");
process.exit(1);
