import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useMemo, useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";

import { supabase } from "@/integrations/supabase/client";
import { listEmployes, type Employe } from "@/lib/rh-api";
import { listParametres, listRubriques } from "@/lib/paie/parametres-api";
import { runEngine } from "@/lib/paie/engine";
import { bulletinFileName } from "@/lib/pdf/bulletinPaieCI";
import { Skeleton } from "@/components/ui/skeleton";
import { RhPageHeader } from "@/components/rh/RhPageHeader";
import { useSaveHotkey } from "@/hooks/use-save-hotkey";
import { buildBulletinPdfBlob, defaultPeriode, type CustomField } from "@/lib/paie-nouveau-helpers";
import { usePdfProgress } from "@/hooks/use-pdf-progress";
import { InfosCard } from "@/components/paie/nouveau/InfosCard";
import { RecapCard } from "@/components/paie/nouveau/RecapCard";
import { RubriquesCard } from "@/components/paie/nouveau/RubriquesCard";
import { CustomFieldsCard } from "@/components/paie/nouveau/CustomFieldsCard";
import { PageLayoutCard } from "@/components/paie/nouveau/PageLayoutCard";
import { ActionsBar } from "@/components/paie/nouveau/ActionsBar";
import { PreviewDialog } from "@/components/paie/nouveau/PreviewDialog";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/paie/nouveau")({
  component: NouveauBulletinPage,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});

function NouveauBulletinPage() {
  const navigate = useNavigate();
  const qc = useQueryClient();

  const [employeId, setEmployeId] = useState<string>("");
  const [periode, setPeriode] = useState<string>(defaultPeriode());
  const [salaireBase, setSalaireBase] = useState<number>(0);
  const [primes, setPrimes] = useState<number>(0);
  const [heuresSup, setHeuresSup] = useState<number>(0);
  const [observations, setObservations] = useState<string>("");
  const [customFields, setCustomFields] = useState<CustomField[]>([]);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  const [pageMargin, setPageMargin] = useState<number>(10);
  const [baseFontSize, setBaseFontSize] = useState<number>(8.5);

  const { pdfProgress, runWithProgress, cancelPdf } = usePdfProgress();

  const { data: employes } = useQuery({
    queryKey: ["employes-list"],
    queryFn: () => listEmployes(),
  });
  const { data: parametres, isLoading: lp } = useQuery({
    queryKey: ["paie_parametres"],
    queryFn: listParametres,
  });
  const { data: rubriques, isLoading: lr } = useQuery({
    queryKey: ["paie_rubriques"],
    queryFn: listRubriques,
  });

  const employe: Employe | undefined = useMemo(
    () => employes?.find((e) => e.employe_id === employeId),
    [employes, employeId],
  );

  const onSelectEmploye = (id: string) => {
    setEmployeId(id);
    const emp = employes?.find((e) => e.employe_id === id);
    if (emp && !salaireBase) setSalaireBase(Number(emp.salaire) || 0);
  };

  const result = useMemo(() => {
    if (!parametres || !rubriques) return null;
    return runEngine({ salaireBase, primes, heuresSup }, parametres, rubriques);
  }, [salaireBase, primes, heuresSup, parametres, rubriques]);

  const save = useMutation({
    mutationFn: async () => {
      if (!employe) throw new Error("Sélectionnez un employé");
      if (!result) throw new Error("Moteur non prêt");
      const { assertPermission } = await import("@/lib/rbac-api");
      await assertPermission("paie.creer_bulletin");
      const { data, error } = await supabase
        .from("bulletins_paie")
        .insert({
          employe_id: employe.employe_id,
          employe_nom: employe.nom_complet,
          periode,
          salaire_brut: result.salaireBrut,
          retenues: result.totalRetenues,
          salaire_net: result.salaireNet,
          statut: "genere",
        })
        .select()
        .single();
      if (error) throw error;
      return data;
    },
    onSuccess: (data) => {
      qc.invalidateQueries({ queryKey: ["bulletins_paie"] });
      toast.success("Bulletin enregistré");
      navigate({ to: "/paie/$bulletinId", params: { bulletinId: data.bulletin_id } });
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const build = async (): Promise<Blob | null> => {
    if (!employe || !result) return null;
    return buildBulletinPdfBlob({
      employe,
      result,
      periode,
      observations,
      customFields,
      pageMargin,
      baseFontSize,
    });
  };

  const openPreview = () => {
    void runWithProgress("preview", build, (blob) => {
      if (previewUrl) URL.revokeObjectURL(previewUrl);
      setPreviewUrl(URL.createObjectURL(blob));
    });
  };

  const closePreview = () => {
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    setPreviewUrl(null);
  };

  useSaveHotkey(() => save.mutate(), {
    enabled: !save.isPending && !!employe && !!result,
  });

  const downloadPdf = () => {
    if (!employe) return;
    void runWithProgress("download", build, (blob) => {
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = bulletinFileName(`BP-${periode}`, employe.nom_complet);
      a.click();
      URL.revokeObjectURL(url);
    });
  };

  if (lp || lr) return <Skeleton className="h-96 w-full" />;

  return (
    <div className="space-y-4 pb-24">
      <RhPageHeader
        backTo="/paie"
        title="Nouveau bulletin de paie"
        subtitle="Moteur CI — CNPS / CMU / ITS / CN"
        crumbs={[{ label: "Paie", to: "/paie" }, { label: "Nouveau" }]}
      />

      <div className="grid gap-4 lg:grid-cols-2">
        <InfosCard
          employes={employes}
          employeId={employeId}
          onSelectEmploye={onSelectEmploye}
          periode={periode}
          setPeriode={setPeriode}
          salaireBase={salaireBase}
          setSalaireBase={setSalaireBase}
          primes={primes}
          setPrimes={setPrimes}
          heuresSup={heuresSup}
          setHeuresSup={setHeuresSup}
        />
        <RecapCard result={result} />
      </div>

      <RubriquesCard result={result} />
      <CustomFieldsCard
        customFields={customFields}
        setCustomFields={setCustomFields}
        observations={observations}
        setObservations={setObservations}
      />
      <PageLayoutCard
        pageMargin={pageMargin}
        setPageMargin={setPageMargin}
        baseFontSize={baseFontSize}
        setBaseFontSize={setBaseFontSize}
      />
      <ActionsBar
        pdfProgress={pdfProgress}
        onCancelPdf={cancelPdf}
        onCancel={() => navigate({ to: "/paie" })}
        onPreview={openPreview}
        onDownload={downloadPdf}
        onSave={() => save.mutate()}
        canAct={!!employe && !!result}
        saving={save.isPending}
      />
      <PreviewDialog
        previewUrl={previewUrl}
        employeName={employe?.nom_complet}
        onClose={closePreview}
        onDownload={downloadPdf}
      />
    </div>
  );
}
