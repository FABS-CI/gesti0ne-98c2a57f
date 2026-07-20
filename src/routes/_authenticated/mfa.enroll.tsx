import { createFileRoute } from "@tanstack/react-router";
import { MfaEnrollView } from "@/components/mfa/MfaEnrollView";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/mfa/enroll")({
  component: () => (
    <div className="p-6">
      <MfaEnrollView />
    </div>
  ),
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});