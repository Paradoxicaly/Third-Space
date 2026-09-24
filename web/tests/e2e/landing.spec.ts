import { expect, test } from "@playwright/test";

const browserErrors: string[] = [];

test.beforeEach(async ({ page }) => {
  browserErrors.length = 0;
  page.on("pageerror", (error) => browserErrors.push(error.message));
  page.on("console", (message) => {
    if (message.type() === "error") browserErrors.push(message.text());
  });
});

test.afterEach(() => {
  expect(browserErrors, `Browser errors: ${browserErrors.join("\n")}`).toEqual([]);
});

test("renders the full motion landing experience and responds to intent selection", async ({
  page,
}, testInfo) => {
  await page.goto("/");

  await expect(
    page.getByRole("heading", {
      level: 1,
      name: /find your place between home and everything else/i,
    }),
  ).toBeVisible();
  await expect(page.locator('[data-motion-library="lenis"]')).toBeVisible();
  await expect(page.locator('[data-motion-library="vanta"] canvas')).toBeAttached({ timeout: 10_000 });
  await expect(page.locator('[data-react-bits="blur-text"]')).toBeVisible();
  await expect(page.locator('[data-react-bits="spotlight-card"]').first()).toBeVisible();
  await page.waitForTimeout(1_300);

  await page.getByRole("button", { name: "Create" }).click();
  await expect(page.getByRole("status")).toContainText("Showing places for Create");

  for (const selector of ["#how-it-works", "#places", ".manifesto", "#submit", ".facts"]) {
    await page.locator(selector).scrollIntoViewIfNeeded();
    await page.waitForTimeout(450);
  }
  await expect(page.getByRole("heading", { name: "Carson Library" })).toBeVisible();
  await expect(page.getByRole("heading", { name: /found somewhere that belongs on the map/i })).toBeVisible();

  await page.screenshot({
    path: testInfo.outputPath("living-city-desktop.png"),
    fullPage: true,
  });
});

test("fits the mobile viewport without horizontal overflow", async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  await expect(page.getByRole("heading", { level: 1 })).toBeVisible();

  const overflow = await page.evaluate(
    () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
  );
  expect(overflow).toBeLessThanOrEqual(1);

  await page.screenshot({
    path: testInfo.outputPath("living-city-mobile.png"),
    fullPage: true,
  });
});
