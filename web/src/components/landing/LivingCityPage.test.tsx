import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";

import { LivingCityPage } from "@/components/landing/LivingCityPage";

const intents = ["Focus", "Meet", "Unwind", "Move", "Create"];

describe("LivingCityPage", () => {
  it("introduces Third Spaces and gives every visitor a clear discovery path", () => {
    render(<LivingCityPage />);

    expect(
      screen.getByRole("heading", {
        level: 1,
        name: /find your place between home and everything else/i,
      }),
    ).toBeInTheDocument();

    expect(
      screen.getByText(/discover places to focus, meet, move, create, and breathe/i),
    ).toBeInTheDocument();

    for (const intent of intents) {
      expect(screen.getByRole("button", { name: intent })).toBeInTheDocument();
    }

    expect(screen.getByRole("link", { name: /explore around carson/i })).toHaveAttribute(
      "href",
      "#places",
    );
    expect(screen.getByRole("link", { name: /submit a place/i })).toHaveAttribute(
      "href",
      "#submit",
    );
  });

  it("updates the discovery prompt when an intent is selected", async () => {
    const user = userEvent.setup();
    render(<LivingCityPage />);

    await user.click(screen.getByRole("button", { name: "Create" }));

    expect(screen.getByRole("status")).toHaveTextContent("Showing places for Create");
    expect(screen.getByRole("button", { name: "Create" })).toHaveAttribute(
      "aria-pressed",
      "true",
    );
  });

  it("shows Carson-area prototype listings with useful third-space context", () => {
    render(<LivingCityPage />);

    const placesRegion = screen.getByRole("region", { name: /places around carson/i });
    expect(placesRegion).toBeInTheDocument();
    expect(within(placesRegion).getByRole("heading", { name: "Carson Library" })).toBeInTheDocument();
    expect(
      within(placesRegion).getByRole("heading", { name: "Dominguez Rancho Adobe Museum" }),
    ).toBeInTheDocument();
    expect(within(placesRegion).getByRole("heading", { name: "Calas Park" })).toBeInTheDocument();
    expect(screen.getAllByText(/verified/i).length).toBeGreaterThan(0);
  });
});
