import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { toast } from "sonner";
import { ShieldCheck, ShieldOff, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { formatDate } from "@/lib/format";
import {
  certifyDocumentFn,
  revokeCertificationFn,
  listCertificationsFn,
} from "@/lib/certification/certification.functions";

/** Section « Certification numérique » d'un document commercial (facture, proforma…). */
export function CertificationCard({ reference }: { reference: string }) {
  const qc = useQueryClient();
  const list = useServerFn(listCertificationsFn);
  const certify = useServerFn(certifyDocumentFn);
  const revoke = useServerFn(revokeCertificationFn);
  const [motif, setMotif] = useState("");

  const { data: certifications = [], isLoading } = useQuery({
    queryKey: ["certifications", reference],
    queryFn: () => list({ data: { reference } }),
  });

  const active = certifications.find((c) => c.statut === "ACTIVE") ?? certifications[0] ?? null;

  const certifyMut = useMutation({
    mutationFn: () => certify({ data: { reference } }),
    onSuccess: () => {
      toast.success("Document certifié numériquement");
      void qc.invalidateQueries({ queryKey: ["certifications", reference] });
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const revokeMut = useMutation({
    mutationFn: () =>
      revoke({ data: { certificationId: active?.certification_id ?? "", reason: motif } }),
    onSuccess: () => {
      setMotif("");
      toast.success("Certification révoquée");
      void qc.invalidateQueries({ queryKey: ["certifications", reference] });
    },
    onError: (e: Error) => toast.error(e.message),
  });

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center justify-between gap-2">
          <span className="flex items-center gap-2">
            <ShieldCheck className="h-5 w-5 text-primary" />
            Certification numérique
          </span>
          {active ? (
            <Badge variant={active.statut === "ACTIVE" ? "default" : "destructive"}>
              {active.statut === "ACTIVE" ? "CERTIFIÉ" : active.statut}
            </Badge>
          ) : (
            <Badge variant="outline">NON CERTIFIÉ</Badge>
          )}
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {isLoading ? (
          <p className="text-sm text-muted-foreground flex items-center gap-2">
            <Loader2 className="h-4 w-4 animate-spin" /> Chargement…
          </p>
        ) : active ? (
          <div className="space-y-1 text-sm">
            <div className="text-muted-foreground">
              Version {active.version}
              {active.certified_at ? ` • Émise le ${formatDate(active.certified_at)}` : ""}
            </div>
            <div className="font-mono text-[11px] break-all text-muted-foreground">
              {active.canonical_hash}
            </div>
            {active.revoked_at && (
              <p className="text-orange-600">
                Révoquée le {formatDate(active.revoked_at)} — {active.revocation_reason ?? "—"}
              </p>
            )}
          </div>
        ) : (
          <p className="text-sm text-muted-foreground">
            Ce document n'a pas encore de signature numérique. La page publique de vérification
            l'affichera comme « non certifié ».
          </p>
        )}

        <div className="flex flex-wrap items-center gap-2">
          <Button
            size="sm"
            onClick={() => certifyMut.mutate()}
            disabled={certifyMut.isPending}
          >
            {certifyMut.isPending && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
            {active && active.statut === "ACTIVE" ? "Re-certifier" : "Certifier ce document"}
          </Button>
          <Button asChild size="sm" variant="outline">
            <a href={`/verify/${encodeURIComponent(reference)}`} target="_blank" rel="noreferrer">
              Vérifier publiquement
            </a>
          </Button>
        </div>

        {active && active.statut === "ACTIVE" && (
          <div className="flex flex-wrap items-center gap-2 border-t pt-3">
            <Input
              value={motif}
              onChange={(e) => setMotif(e.target.value)}
              placeholder="Motif de révocation"
              className="max-w-xs"
            />
            <Button
              size="sm"
              variant="destructive"
              disabled={!motif.trim() || revokeMut.isPending}
              onClick={() => revokeMut.mutate()}
            >
              <ShieldOff className="mr-2 h-4 w-4" />
              Révoquer
            </Button>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
