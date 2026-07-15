import { createFileRoute } from "@tanstack/react-router";
import { MfaEnrollView } from "@/components/mfa/MfaEnrollView";

export const Route = createFileRoute("/_authenticated/mfa/enroll")({
  component: () => (
    <div className="p-6">
      <MfaEnrollView />
    </div>
  ),
});