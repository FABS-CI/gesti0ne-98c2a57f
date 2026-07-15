import { Loader2 } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";

export function FecProgressCard({ progress, step }: { progress: number; step: string }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base flex items-center gap-2">
          <Loader2 className="h-4 w-4 animate-spin" /> Génération du ZIP en cours
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-2">
        <Progress value={progress} />
        <p className="text-xs text-muted-foreground">
          {step || "Initialisation…"} — {progress}%
        </p>
      </CardContent>
    </Card>
  );
}
