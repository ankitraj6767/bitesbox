import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const ignoreCommand = resolve(
  process.cwd(),
  "scripts/vercel-ignore-deploy.mjs",
);

describe("Vercel source-only deployment guard", () => {
  it("skips a commit explicitly marked source-only", () => {
    const result = spawnSync(process.execPath, [ignoreCommand], {
      env: {
        ...process.env,
        VERCEL_GIT_COMMIT_MESSAGE:
          "fix(admin): restore owner zone updates [source-only]",
      },
    });

    expect(result.status).toBe(0);
  });

  it("continues normal deployments when the marker is absent", () => {
    const result = spawnSync(process.execPath, [ignoreCommand], {
      env: {
        ...process.env,
        VERCEL_GIT_COMMIT_MESSAGE: "feat(admin): improve delivery operations",
      },
    });

    expect(result.status).toBe(1);
  });
});
