/**
 * Tests unitaires RouteGuard — vérifie l'enforcement des permissions .voir
 * et le comportement de journalisation / redirection en cas de refus.
 *
 * Exécution : `bunx vitest run`
 */
import { describe, expect, it, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";

// --- mocks ---------------------------------------------------------------
const navigateMock = vi.fn();
const logDeniedMock = vi.fn();

let permsState = {
  isSuperAdmin: false,
  isLoading: false,
  has: (_k: string) => false,
};
let currentPath = "/clients";

vi.mock("@tanstack/react-router", () => ({
  useNavigate: () => navigateMock,
  useRouterState: ({ select }: { select: (s: unknown) => unknown }) =>
    select({ location: { pathname: currentPath } }),
}));

vi.mock("@/hooks/use-permissions", () => ({
  usePermissions: () => permsState,
}));

vi.mock("@/lib/rbac-api", () => ({
  logPermissionDenied: (...args: unknown[]) => logDeniedMock(...args),
}));

vi.mock("@/lib/route-permissions", () => ({
  getRoutePermission: (p: string) =>
    p === "/clients" ? "clients.voir" : p === "/profil" ? null : undefined,
  isSuperAdminOnlyRoute: (_p: string) => false,
}));

import { RouteGuard } from "../RouteGuard";

beforeEach(() => {
  navigateMock.mockClear();
  logDeniedMock.mockClear();
  permsState = { isSuperAdmin: false, isLoading: false, has: () => false };
  currentPath = "/clients";
});

describe("RouteGuard", () => {
  it("affiche les enfants quand la permission est accordée", () => {
    permsState = { isSuperAdmin: false, isLoading: false, has: (k) => k === "clients.voir" };
    render(
      <RouteGuard>
        <div>contenu clients</div>
      </RouteGuard>,
    );
    expect(screen.getByText("contenu clients")).toBeInTheDocument();
    expect(navigateMock).not.toHaveBeenCalled();
  });

  it("bypass complet pour un super_admin", () => {
    permsState = { isSuperAdmin: true, isLoading: false, has: () => false };
    render(
      <RouteGuard>
        <div>zone admin</div>
      </RouteGuard>,
    );
    expect(screen.getByText("zone admin")).toBeInTheDocument();
    expect(navigateMock).not.toHaveBeenCalled();
  });

  it("refuse une route non mappée (fallback strict) sauf super_admin", async () => {
    currentPath = "/route-inconnue";
    render(
      <RouteGuard>
        <div>ok</div>
      </RouteGuard>,
    );
    await waitFor(() => expect(navigateMock).toHaveBeenCalledTimes(1));
    expect(navigateMock).toHaveBeenCalledWith({
      to: "/acces-refuse",
      search: { perm: "", from: "/route-inconnue" },
      replace: true,
    });
    expect(screen.queryByText("ok")).not.toBeInTheDocument();
  });

  it("laisse passer une route explicitement publique authentifiée (perm null)", () => {
    currentPath = "/profil";
    render(
      <RouteGuard>
        <div>profil</div>
      </RouteGuard>,
    );
    expect(screen.getByText("profil")).toBeInTheDocument();
  });

  it("redirige vers /acces-refuse et log le refus si permission manquante", async () => {
    render(
      <RouteGuard>
        <div>secret</div>
      </RouteGuard>,
    );
    await waitFor(() => expect(navigateMock).toHaveBeenCalledTimes(1));
    expect(navigateMock).toHaveBeenCalledWith({
      to: "/acces-refuse",
      search: { perm: "clients.voir", from: "/clients" },
      replace: true,
    });
    expect(logDeniedMock).toHaveBeenCalledWith("clients.voir", { path: "/clients" });
    expect(screen.queryByText("secret")).not.toBeInTheDocument();
  });

  it("affiche un loader tant que les permissions chargent", () => {
    permsState = { isSuperAdmin: false, isLoading: true, has: () => false };
    const { container } = render(
      <RouteGuard>
        <div>enfant</div>
      </RouteGuard>,
    );
    expect(container.querySelector(".animate-spin")).toBeTruthy();
    expect(screen.queryByText("enfant")).not.toBeInTheDocument();
  });

  it("ne boucle pas en redirigeant depuis /acces-refuse", () => {
    currentPath = "/acces-refuse";
    render(
      <RouteGuard>
        <div>page 403</div>
      </RouteGuard>,
    );
    expect(navigateMock).not.toHaveBeenCalled();
  });
});
