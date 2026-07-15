export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      _restore_applied: {
        Row: {
          applied_at: string | null
          version: string
        }
        Insert: {
          applied_at?: string | null
          version: string
        }
        Update: {
          applied_at?: string | null
          version?: string
        }
        Relationships: []
      }
      absences: {
        Row: {
          absence_id: string
          created_at: string
          date_debut: string
          date_fin: string | null
          employe_id: string | null
          employe_nom: string | null
          motif: string | null
          statut: string
          type_absence: string
          updated_at: string
        }
        Insert: {
          absence_id?: string
          created_at?: string
          date_debut?: string
          date_fin?: string | null
          employe_id?: string | null
          employe_nom?: string | null
          motif?: string | null
          statut?: string
          type_absence?: string
          updated_at?: string
        }
        Update: {
          absence_id?: string
          created_at?: string
          date_debut?: string
          date_fin?: string | null
          employe_id?: string | null
          employe_nom?: string | null
          motif?: string | null
          statut?: string
          type_absence?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "absences_employe_id_fkey"
            columns: ["employe_id"]
            isOneToOne: false
            referencedRelation: "employes"
            referencedColumns: ["employe_id"]
          },
        ]
      }
      achat_lignes: {
        Row: {
          achat_id: string
          created_at: string
          designation: string
          ligne_id: string
          prix_unitaire: number
          produit_id: string | null
          quantite: number
          reference_produit: string | null
          total_ligne: number
        }
        Insert: {
          achat_id: string
          created_at?: string
          designation: string
          ligne_id?: string
          prix_unitaire?: number
          produit_id?: string | null
          quantite: number
          reference_produit?: string | null
          total_ligne?: number
        }
        Update: {
          achat_id?: string
          created_at?: string
          designation?: string
          ligne_id?: string
          prix_unitaire?: number
          produit_id?: string | null
          quantite?: number
          reference_produit?: string | null
          total_ligne?: number
        }
        Relationships: [
          {
            foreignKeyName: "achat_lignes_achat_id_fkey"
            columns: ["achat_id"]
            isOneToOne: false
            referencedRelation: "achats"
            referencedColumns: ["achat_id"]
          },
          {
            foreignKeyName: "achat_lignes_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "produits"
            referencedColumns: ["produit_id"]
          },
          {
            foreignKeyName: "achat_lignes_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "v_produits"
            referencedColumns: ["produit_id"]
          },
        ]
      }
      achats: {
        Row: {
          achat_id: string
          created_at: string
          created_by: string | null
          created_by_nom: string | null
          date_achat: string
          exercice_id: string
          fournisseur_id: string | null
          libelle: string
          montant: number
          notes: string | null
          reference: string
          reference_fournisseur: string | null
          statut: string
          updated_at: string
        }
        Insert: {
          achat_id?: string
          created_at?: string
          created_by?: string | null
          created_by_nom?: string | null
          date_achat?: string
          exercice_id?: string
          fournisseur_id?: string | null
          libelle: string
          montant?: number
          notes?: string | null
          reference?: string
          reference_fournisseur?: string | null
          statut?: string
          updated_at?: string
        }
        Update: {
          achat_id?: string
          created_at?: string
          created_by?: string | null
          created_by_nom?: string | null
          date_achat?: string
          exercice_id?: string
          fournisseur_id?: string | null
          libelle?: string
          montant?: number
          notes?: string | null
          reference?: string
          reference_fournisseur?: string | null
          statut?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "achats_exercice_id_fkey"
            columns: ["exercice_id"]
            isOneToOne: false
            referencedRelation: "exercices"
            referencedColumns: ["exercice_id"]
          },
          {
            foreignKeyName: "achats_fournisseur_id_fkey"
            columns: ["fournisseur_id"]
            isOneToOne: false
            referencedRelation: "fournisseurs"
            referencedColumns: ["fournisseur_id"]
          },
        ]
      }
      audit_events: {
        Row: {
          action: Database["public"]["Enums"]["audit_action"]
          browser: string | null
          changes: Json | null
          city: string | null
          country: string | null
          criticite: Database["public"]["Enums"]["audit_criticite"]
          device: string | null
          duration_ms: number | null
          error_message: string | null
          http_method: string | null
          id: string
          ip_address: unknown
          metadata: Json | null
          module: string | null
          new_values: Json | null
          occurred_at: string
          old_values: Json | null
          os: string | null
          record_id: string | null
          record_ref: string | null
          request_id: string | null
          seq: number
          session_id: string | null
          status: string
          table_name: string | null
          url: string | null
          user_agent: string | null
          user_email: string | null
          user_id: string | null
        }
        Insert: {
          action: Database["public"]["Enums"]["audit_action"]
          browser?: string | null
          changes?: Json | null
          city?: string | null
          country?: string | null
          criticite?: Database["public"]["Enums"]["audit_criticite"]
          device?: string | null
          duration_ms?: number | null
          error_message?: string | null
          http_method?: string | null
          id?: string
          ip_address?: unknown
          metadata?: Json | null
          module?: string | null
          new_values?: Json | null
          occurred_at?: string
          old_values?: Json | null
          os?: string | null
          record_id?: string | null
          record_ref?: string | null
          request_id?: string | null
          seq?: number
          session_id?: string | null
          status?: string
          table_name?: string | null
          url?: string | null
          user_agent?: string | null
          user_email?: string | null
          user_id?: string | null
        }
        Update: {
          action?: Database["public"]["Enums"]["audit_action"]
          browser?: string | null
          changes?: Json | null
          city?: string | null
          country?: string | null
          criticite?: Database["public"]["Enums"]["audit_criticite"]
          device?: string | null
          duration_ms?: number | null
          error_message?: string | null
          http_method?: string | null
          id?: string
          ip_address?: unknown
          metadata?: Json | null
          module?: string | null
          new_values?: Json | null
          occurred_at?: string
          old_values?: Json | null
          os?: string | null
          record_id?: string | null
          record_ref?: string | null
          request_id?: string | null
          seq?: number
          session_id?: string | null
          status?: string
          table_name?: string | null
          url?: string | null
          user_agent?: string | null
          user_email?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      audit_events_archive: {
        Row: {
          action: Database["public"]["Enums"]["audit_action"]
          browser: string | null
          changes: Json | null
          city: string | null
          country: string | null
          criticite: Database["public"]["Enums"]["audit_criticite"]
          device: string | null
          duration_ms: number | null
          error_message: string | null
          http_method: string | null
          id: string
          ip_address: unknown
          metadata: Json | null
          module: string | null
          new_values: Json | null
          occurred_at: string
          old_values: Json | null
          os: string | null
          record_id: string | null
          record_ref: string | null
          request_id: string | null
          seq: number
          session_id: string | null
          status: string
          table_name: string | null
          url: string | null
          user_agent: string | null
          user_email: string | null
          user_id: string | null
        }
        Insert: {
          action: Database["public"]["Enums"]["audit_action"]
          browser?: string | null
          changes?: Json | null
          city?: string | null
          country?: string | null
          criticite?: Database["public"]["Enums"]["audit_criticite"]
          device?: string | null
          duration_ms?: number | null
          error_message?: string | null
          http_method?: string | null
          id?: string
          ip_address?: unknown
          metadata?: Json | null
          module?: string | null
          new_values?: Json | null
          occurred_at?: string
          old_values?: Json | null
          os?: string | null
          record_id?: string | null
          record_ref?: string | null
          request_id?: string | null
          seq?: number
          session_id?: string | null
          status?: string
          table_name?: string | null
          url?: string | null
          user_agent?: string | null
          user_email?: string | null
          user_id?: string | null
        }
        Update: {
          action?: Database["public"]["Enums"]["audit_action"]
          browser?: string | null
          changes?: Json | null
          city?: string | null
          country?: string | null
          criticite?: Database["public"]["Enums"]["audit_criticite"]
          device?: string | null
          duration_ms?: number | null
          error_message?: string | null
          http_method?: string | null
          id?: string
          ip_address?: unknown
          metadata?: Json | null
          module?: string | null
          new_values?: Json | null
          occurred_at?: string
          old_values?: Json | null
          os?: string | null
          record_id?: string | null
          record_ref?: string | null
          request_id?: string | null
          seq?: number
          session_id?: string | null
          status?: string
          table_name?: string | null
          url?: string | null
          user_agent?: string | null
          user_email?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      audit_logs: {
        Row: {
          action: string
          created_at: string
          id: string
          new_values: Json | null
          old_values: Json | null
          record_id: string | null
          table_name: string
          user_email: string | null
          user_id: string | null
        }
        Insert: {
          action: string
          created_at?: string
          id?: string
          new_values?: Json | null
          old_values?: Json | null
          record_id?: string | null
          table_name: string
          user_email?: string | null
          user_id?: string | null
        }
        Update: {
          action?: string
          created_at?: string
          id?: string
          new_values?: Json | null
          old_values?: Json | null
          record_id?: string | null
          table_name?: string
          user_email?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      avoirs: {
        Row: {
          avoir_id: string
          br_id: string | null
          client_id: string | null
          client_nom: string | null
          created_at: string
          created_by: string | null
          date_emission: string
          date_reglement: string | null
          exercice_id: string | null
          facture_id: string | null
          facture_imputee_id: string | null
          mode_reglement: string | null
          montant: number
          notes: string | null
          paiement_id: string | null
          reference: string
          retour_id: string | null
          statut: string
          updated_at: string
        }
        Insert: {
          avoir_id?: string
          br_id?: string | null
          client_id?: string | null
          client_nom?: string | null
          created_at?: string
          created_by?: string | null
          date_emission?: string
          date_reglement?: string | null
          exercice_id?: string | null
          facture_id?: string | null
          facture_imputee_id?: string | null
          mode_reglement?: string | null
          montant?: number
          notes?: string | null
          paiement_id?: string | null
          reference?: string
          retour_id?: string | null
          statut?: string
          updated_at?: string
        }
        Update: {
          avoir_id?: string
          br_id?: string | null
          client_id?: string | null
          client_nom?: string | null
          created_at?: string
          created_by?: string | null
          date_emission?: string
          date_reglement?: string | null
          exercice_id?: string | null
          facture_id?: string | null
          facture_imputee_id?: string | null
          mode_reglement?: string | null
          montant?: number
          notes?: string | null
          paiement_id?: string | null
          reference?: string
          retour_id?: string | null
          statut?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "avoirs_br_id_fkey"
            columns: ["br_id"]
            isOneToOne: false
            referencedRelation: "bons_retour"
            referencedColumns: ["br_id"]
          },
          {
            foreignKeyName: "avoirs_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "avoirs_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "v_client_achats"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "avoirs_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "v_client_stats"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "avoirs_exercice_id_fkey"
            columns: ["exercice_id"]
            isOneToOne: false
            referencedRelation: "exercices"
            referencedColumns: ["exercice_id"]
          },
          {
            foreignKeyName: "avoirs_facture_id_fkey"
            columns: ["facture_id"]
            isOneToOne: false
            referencedRelation: "factures"
            referencedColumns: ["facture_id"]
          },
          {
            foreignKeyName: "avoirs_facture_imputee_id_fkey"
            columns: ["facture_imputee_id"]
            isOneToOne: false
            referencedRelation: "factures"
            referencedColumns: ["facture_id"]
          },
          {
            foreignKeyName: "avoirs_paiement_id_fkey"
            columns: ["paiement_id"]
            isOneToOne: false
            referencedRelation: "paiements"
            referencedColumns: ["paiement_id"]
          },
          {
            foreignKeyName: "avoirs_retour_id_fkey"
            columns: ["retour_id"]
            isOneToOne: false
            referencedRelation: "retours"
            referencedColumns: ["retour_id"]
          },
        ]
      }
      backup_schedules: {
        Row: {
          active: boolean
          created_at: string
          created_by: string | null
          destination: string
          frequence: string
          last_run_at: string | null
          next_run_at: string | null
          nom: string
          retention_count: number
          schedule_id: string
          type_sauvegarde: string
          updated_at: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          created_by?: string | null
          destination?: string
          frequence: string
          last_run_at?: string | null
          next_run_at?: string | null
          nom: string
          retention_count?: number
          schedule_id?: string
          type_sauvegarde: string
          updated_at?: string
        }
        Update: {
          active?: boolean
          created_at?: string
          created_by?: string | null
          destination?: string
          frequence?: string
          last_run_at?: string | null
          next_run_at?: string | null
          nom?: string
          retention_count?: number
          schedule_id?: string
          type_sauvegarde?: string
          updated_at?: string
        }
        Relationships: []
      }
      backups: {
        Row: {
          backup_id: string
          chiffree: boolean
          created_at: string
          destination: string
          destination_ref: string | null
          destination_url: string | null
          duree_ms: number | null
          fichier_nom: string | null
          finished_at: string | null
          message: string | null
          nb_enregistrements: number | null
          nb_tables: number | null
          scope: Json | null
          sha256: string | null
          signature: string | null
          started_at: string
          statut: string
          taille_octets: number | null
          type: string
          user_email: string | null
          user_id: string | null
          verifie: boolean
          verifie_at: string | null
          verifie_methode: string | null
        }
        Insert: {
          backup_id?: string
          chiffree?: boolean
          created_at?: string
          destination?: string
          destination_ref?: string | null
          destination_url?: string | null
          duree_ms?: number | null
          fichier_nom?: string | null
          finished_at?: string | null
          message?: string | null
          nb_enregistrements?: number | null
          nb_tables?: number | null
          scope?: Json | null
          sha256?: string | null
          signature?: string | null
          started_at?: string
          statut?: string
          taille_octets?: number | null
          type: string
          user_email?: string | null
          user_id?: string | null
          verifie?: boolean
          verifie_at?: string | null
          verifie_methode?: string | null
        }
        Update: {
          backup_id?: string
          chiffree?: boolean
          created_at?: string
          destination?: string
          destination_ref?: string | null
          destination_url?: string | null
          duree_ms?: number | null
          fichier_nom?: string | null
          finished_at?: string | null
          message?: string | null
          nb_enregistrements?: number | null
          nb_tables?: number | null
          scope?: Json | null
          sha256?: string | null
          signature?: string | null
          started_at?: string
          statut?: string
          taille_octets?: number | null
          type?: string
          user_email?: string | null
          user_id?: string | null
          verifie?: boolean
          verifie_at?: string | null
          verifie_methode?: string | null
        }
        Relationships: []
      }
      bons_livraison: {
        Row: {
          adresse_livraison: string | null
          annulation_motif: string | null
          annule_at: string | null
          annule_par: string | null
          annule_par_nom: string | null
          bl_id: string
          client_id: string | null
          commande_id: string | null
          created_at: string
          date_emission: string
          date_livraison: string | null
          exercice_id: string
          montant_total: number
          notes: string | null
          reference: string
          signataire: string | null
          statut: string
          transporteur: string | null
          updated_at: string
        }
        Insert: {
          adresse_livraison?: string | null
          annulation_motif?: string | null
          annule_at?: string | null
          annule_par?: string | null
          annule_par_nom?: string | null
          bl_id?: string
          client_id?: string | null
          commande_id?: string | null
          created_at?: string
          date_emission?: string
          date_livraison?: string | null
          exercice_id?: string
          montant_total?: number
          notes?: string | null
          reference?: string
          signataire?: string | null
          statut?: string
          transporteur?: string | null
          updated_at?: string
        }
        Update: {
          adresse_livraison?: string | null
          annulation_motif?: string | null
          annule_at?: string | null
          annule_par?: string | null
          annule_par_nom?: string | null
          bl_id?: string
          client_id?: string | null
          commande_id?: string | null
          created_at?: string
          date_emission?: string
          date_livraison?: string | null
          exercice_id?: string
          montant_total?: number
          notes?: string | null
          reference?: string
          signataire?: string | null
          statut?: string
          transporteur?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bons_livraison_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "bons_livraison_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "v_client_achats"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "bons_livraison_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "v_client_stats"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "bons_livraison_commande_id_fkey"
            columns: ["commande_id"]
            isOneToOne: false
            referencedRelation: "commandes"
            referencedColumns: ["commande_id"]
          },
          {
            foreignKeyName: "bons_livraison_commande_id_fkey"
            columns: ["commande_id"]
            isOneToOne: false
            referencedRelation: "v_client_achats"
            referencedColumns: ["commande_id"]
          },
          {
            foreignKeyName: "bons_livraison_exercice_id_fkey"
            columns: ["exercice_id"]
            isOneToOne: false
            referencedRelation: "exercices"
            referencedColumns: ["exercice_id"]
          },
        ]
      }
      bons_retour: {
        Row: {
          br_id: string
          client_id: string | null
          created_at: string
          date_retour: string
          exercice_id: string
          facture_id: string | null
          montant: number
          motif: string | null
          notes: string | null
          reference: string
          statut: string
          updated_at: string
        }
        Insert: {
          br_id?: string
          client_id?: string | null
          created_at?: string
          date_retour?: string
          exercice_id?: string
          facture_id?: string | null
          montant?: number
          motif?: string | null
          notes?: string | null
          reference?: string
          statut?: string
          updated_at?: string
        }
        Update: {
          br_id?: string
          client_id?: string | null
          created_at?: string
          date_retour?: string
          exercice_id?: string
          facture_id?: string | null
          montant?: number
          motif?: string | null
          notes?: string | null
          reference?: string
          statut?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bons_retour_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "bons_retour_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "v_client_achats"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "bons_retour_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "v_client_stats"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "bons_retour_exercice_id_fkey"
            columns: ["exercice_id"]
            isOneToOne: false
            referencedRelation: "exercices"
            referencedColumns: ["exercice_id"]
          },
          {
            foreignKeyName: "bons_retour_facture_id_fkey"
            columns: ["facture_id"]
            isOneToOne: false
            referencedRelation: "factures"
            referencedColumns: ["facture_id"]
          },
        ]
      }
      bulletins_paie: {
        Row: {
          bulletin_id: string
          created_at: string
          employe_id: string | null
          employe_nom: string | null
          exercice_id: string
          periode: string
          retenues: number
          salaire_brut: number
          salaire_net: number
          statut: string
          updated_at: string
        }
        Insert: {
          bulletin_id?: string
          created_at?: string
          employe_id?: string | null
          employe_nom?: string | null
          exercice_id?: string
          periode: string
          retenues?: number
          salaire_brut?: number
          salaire_net?: number
          statut?: string
          updated_at?: string
        }
        Update: {
          bulletin_id?: string
          created_at?: string
          employe_id?: string | null
          employe_nom?: string | null
          exercice_id?: string
          periode?: string
          retenues?: number
          salaire_brut?: number
          salaire_net?: number
          statut?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bulletins_paie_employe_id_fkey"
            columns: ["employe_id"]
            isOneToOne: false
            referencedRelation: "employes"
            referencedColumns: ["employe_id"]
          },
          {
            foreignKeyName: "bulletins_paie_exercice_id_fkey"
            columns: ["exercice_id"]
            isOneToOne: false
            referencedRelation: "exercices"
            referencedColumns: ["exercice_id"]
          },
        ]
      }
      categories_produits: {
        Row: {
          actif: boolean
          categorie_id: string
          created_at: string
          description: string | null
          nom: string
          parent_id: string | null
          updated_at: string
        }
        Insert: {
          actif?: boolean
          categorie_id?: string
          created_at?: string
          description?: string | null
          nom: string
          parent_id?: string | null
          updated_at?: string
        }
        Update: {
          actif?: boolean
          categorie_id?: string
          created_at?: string
          description?: string | null
          nom?: string
          parent_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "categories_produits_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "categories_produits"
            referencedColumns: ["categorie_id"]
          },
        ]
      }
      client_fidelite_mouvements: {
        Row: {
          client_id: string
          created_at: string
          created_by: string | null
          date_expiration: string | null
          date_mouvement: string
          facture_id: string | null
          motif: string | null
          mouvement_id: string
          paiement_id: string | null
          points: number
          type: string
        }
        Insert: {
          client_id: string
          created_at?: string
          created_by?: string | null
          date_expiration?: string | null
          date_mouvement?: string
          facture_id?: string | null
          motif?: string | null
          mouvement_id?: string
          paiement_id?: string | null
          points: number
          type: string
        }
        Update: {
          client_id?: string
          created_at?: string
          created_by?: string | null
          date_expiration?: string | null
          date_mouvement?: string
          facture_id?: string | null
          motif?: string | null
          mouvement_id?: string
          paiement_id?: string | null
          points?: number
          type?: string
        }
        Relationships: [
          {
            foreignKeyName: "client_fidelite_mouvements_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "client_fidelite_mouvements_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "v_client_achats"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "client_fidelite_mouvements_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "v_client_stats"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "client_fidelite_mouvements_facture_id_fkey"
            columns: ["facture_id"]
            isOneToOne: false
            referencedRelation: "factures"
            referencedColumns: ["facture_id"]
          },
          {
            foreignKeyName: "client_fidelite_mouvements_paiement_id_fkey"
            columns: ["paiement_id"]
            isOneToOne: false
            referencedRelation: "paiements"
            referencedColumns: ["paiement_id"]
          },
        ]
      }
      clients: {
        Row: {
          actif: boolean
          adresse: string | null
          bp: string | null
          categorie: string | null
          client_id: string
          commune: string | null
          contact_principal: string | null
          created_at: string
          delai_paiement: number | null
          email: string | null
          mode_paiement: string | null
          motif_blocage: string | null
          nif: string | null
          nom: string
          notes: string | null
          pays: string | null
          plafond_credit: number
          quartier: string | null
          reference: string
          regime_fiscal: string | null
          remise_habituelle: number | null
          representant: string | null
          secteur_activite: string | null
          solde: number
          solde_points: number
          statut: string | null
          telephone: string | null
          telephone2: string | null
          type_client: string
          updated_at: string
          ville: string | null
        }
        Insert: {
          actif?: boolean
          adresse?: string | null
          bp?: string | null
          categorie?: string | null
          client_id?: string
          commune?: string | null
          contact_principal?: string | null
          created_at?: string
          delai_paiement?: number | null
          email?: string | null
          mode_paiement?: string | null
          motif_blocage?: string | null
          nif?: string | null
          nom: string
          notes?: string | null
          pays?: string | null
          plafond_credit?: number
          quartier?: string | null
          reference?: string
          regime_fiscal?: string | null
          remise_habituelle?: number | null
          representant?: string | null
          secteur_activite?: string | null
          solde?: number
          solde_points?: number
          statut?: string | null
          telephone?: string | null
          telephone2?: string | null
          type_client?: string
          updated_at?: string
          ville?: string | null
        }
        Update: {
          actif?: boolean
          adresse?: string | null
          bp?: string | null
          categorie?: string | null
          client_id?: string
          commune?: string | null
          contact_principal?: string | null
          created_at?: string
          delai_paiement?: number | null
          email?: string | null
          mode_paiement?: string | null
          motif_blocage?: string | null
          nif?: string | null
          nom?: string
          notes?: string | null
          pays?: string | null
          plafond_credit?: number
          quartier?: string | null
          reference?: string
          regime_fiscal?: string | null
          remise_habituelle?: number | null
          representant?: string | null
          secteur_activite?: string | null
          solde?: number
          solde_points?: number
          statut?: string | null
          telephone?: string | null
          telephone2?: string | null
          type_client?: string
          updated_at?: string
          ville?: string | null
        }
        Relationships: []
      }
      colis: {
        Row: {
          bl_id: string | null
          colis_id: string
          commande_id: string | null
          commune: string | null
          contenu: string | null
          created_at: string
          date_arrivee_client: string | null
          date_arrivee_estimee: string | null
          date_arrivee_ville: string | null
          date_colisage: string | null
          date_depart: string | null
          date_depot_gare: string | null
          date_envoi: string
          date_livraison_reelle: string | null
          date_remise_client: string | null
          date_remise_livreur: string | null
          destinataire: string | null
          gare_depart: string | null
          gare_responsable: string | null
          gare_telephone: string | null
          livreur_nom: string | null
          livreur_telephone: string | null
          mode_acheminement: string | null
          nb_cartons: number | null
          notes: string | null
          numero_carton: number | null
          observations: string | null
          poids: number
          quartier: string | null
          reference: string
          responsable_id: string | null
          responsable_nom: string | null
          statut: string
          statut_logistique: string
          tournee_id: string | null
          transporteur: string | null
          updated_at: string
          vehicule: string | null
          ville_destination: string | null
          ville_livraison: string | null
        }
        Insert: {
          bl_id?: string | null
          colis_id?: string
          commande_id?: string | null
          commune?: string | null
          contenu?: string | null
          created_at?: string
          date_arrivee_client?: string | null
          date_arrivee_estimee?: string | null
          date_arrivee_ville?: string | null
          date_colisage?: string | null
          date_depart?: string | null
          date_depot_gare?: string | null
          date_envoi?: string
          date_livraison_reelle?: string | null
          date_remise_client?: string | null
          date_remise_livreur?: string | null
          destinataire?: string | null
          gare_depart?: string | null
          gare_responsable?: string | null
          gare_telephone?: string | null
          livreur_nom?: string | null
          livreur_telephone?: string | null
          mode_acheminement?: string | null
          nb_cartons?: number | null
          notes?: string | null
          numero_carton?: number | null
          observations?: string | null
          poids?: number
          quartier?: string | null
          reference?: string
          responsable_id?: string | null
          responsable_nom?: string | null
          statut?: string
          statut_logistique?: string
          tournee_id?: string | null
          transporteur?: string | null
          updated_at?: string
          vehicule?: string | null
          ville_destination?: string | null
          ville_livraison?: string | null
        }
        Update: {
          bl_id?: string | null
          colis_id?: string
          commande_id?: string | null
          commune?: string | null
          contenu?: string | null
          created_at?: string
          date_arrivee_client?: string | null
          date_arrivee_estimee?: string | null
          date_arrivee_ville?: string | null
          date_colisage?: string | null
          date_depart?: string | null
          date_depot_gare?: string | null
          date_envoi?: string
          date_livraison_reelle?: string | null
          date_remise_client?: string | null
          date_remise_livreur?: string | null
          destinataire?: string | null
          gare_depart?: string | null
          gare_responsable?: string | null
          gare_telephone?: string | null
          livreur_nom?: string | null
          livreur_telephone?: string | null
          mode_acheminement?: string | null
          nb_cartons?: number | null
          notes?: string | null
          numero_carton?: number | null
          observations?: string | null
          poids?: number
          quartier?: string | null
          reference?: string
          responsable_id?: string | null
          responsable_nom?: string | null
          statut?: string
          statut_logistique?: string
          tournee_id?: string | null
          transporteur?: string | null
          updated_at?: string
          vehicule?: string | null
          ville_destination?: string | null
          ville_livraison?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "colis_bl_id_fkey"
            columns: ["bl_id"]
            isOneToOne: false
            referencedRelation: "bons_livraison"
            referencedColumns: ["bl_id"]
          },
          {
            foreignKeyName: "colis_commande_id_fkey"
            columns: ["commande_id"]
            isOneToOne: false
            referencedRelation: "commandes"
            referencedColumns: ["commande_id"]
          },
          {
            foreignKeyName: "colis_commande_id_fkey"
            columns: ["commande_id"]
            isOneToOne: false
            referencedRelation: "v_client_achats"
            referencedColumns: ["commande_id"]
          },
          {
            foreignKeyName: "colis_tournee_id_fkey"
            columns: ["tournee_id"]
            isOneToOne: false
            referencedRelation: "tournees"
            referencedColumns: ["tournee_id"]
          },
        ]
      }
      colis_lignes: {
        Row: {
          colis_id: string
          created_at: string
          designation: string
          id: string
          ordre: number
          poids: number | null
          produit_id: string | null
          quantite: number
          reference_produit: string | null
          updated_at: string
        }
        Insert: {
          colis_id: string
          created_at?: string
          designation: string
          id?: string
          ordre?: number
          poids?: number | null
          produit_id?: string | null
          quantite: number
          reference_produit?: string | null
          updated_at?: string
        }
        Update: {
          colis_id?: string
          created_at?: string
          designation?: string
          id?: string
          ordre?: number
          poids?: number | null
          produit_id?: string | null
          quantite?: number
          reference_produit?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "colis_lignes_colis_id_fkey"
            columns: ["colis_id"]
            isOneToOne: false
            referencedRelation: "colis"
            referencedColumns: ["colis_id"]
          },
          {
            foreignKeyName: "colis_lignes_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "produits"
            referencedColumns: ["produit_id"]
          },
          {
            foreignKeyName: "colis_lignes_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "v_produits"
            referencedColumns: ["produit_id"]
          },
        ]
      }
      colis_statut_historique: {
        Row: {
          ancien_statut: string | null
          colis_id: string
          commentaire: string | null
          created_at: string
          id: string
          mode_acheminement: string
          nouveau_statut: string
          user_id: string | null
          user_nom: string | null
        }
        Insert: {
          ancien_statut?: string | null
          colis_id: string
          commentaire?: string | null
          created_at?: string
          id?: string
          mode_acheminement: string
          nouveau_statut: string
          user_id?: string | null
          user_nom?: string | null
        }
        Update: {
          ancien_statut?: string | null
          colis_id?: string
          commentaire?: string | null
          created_at?: string
          id?: string
          mode_acheminement?: string
          nouveau_statut?: string
          user_id?: string | null
          user_nom?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "colis_statut_historique_colis_id_fkey"
            columns: ["colis_id"]
            isOneToOne: false
            referencedRelation: "colis"
            referencedColumns: ["colis_id"]
          },
        ]
      }
      colisage_modifications_historique: {
        Row: {
          anciennes_valeurs: Json
          bl_id: string
          created_at: string
          date_modification: string
          date_revalidation: string | null
          id: string
          motif: string
          nouvelles_valeurs: Json | null
          user_id: string
          user_nom: string | null
        }
        Insert: {
          anciennes_valeurs?: Json
          bl_id: string
          created_at?: string
          date_modification?: string
          date_revalidation?: string | null
          id?: string
          motif: string
          nouvelles_valeurs?: Json | null
          user_id: string
          user_nom?: string | null
        }
        Update: {
          anciennes_valeurs?: Json
          bl_id?: string
          created_at?: string
          date_modification?: string
          date_revalidation?: string | null
          id?: string
          motif?: string
          nouvelles_valeurs?: Json | null
          user_id?: string
          user_nom?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "colisage_modifications_historique_bl_id_fkey"
            columns: ["bl_id"]
            isOneToOne: false
            referencedRelation: "bons_livraison"
            referencedColumns: ["bl_id"]
          },
        ]
      }
      colisage_responsables: {
        Row: {
          actif: boolean
          created_at: string
          created_by: string | null
          date_affectation: string
          depot_id: string | null
          employe_id: string
          responsable_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          actif?: boolean
          created_at?: string
          created_by?: string | null
          date_affectation?: string
          depot_id?: string | null
          employe_id: string
          responsable_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          actif?: boolean
          created_at?: string
          created_by?: string | null
          date_affectation?: string
          depot_id?: string | null
          employe_id?: string
          responsable_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "colisage_responsables_depot_id_fkey"
            columns: ["depot_id"]
            isOneToOne: false
            referencedRelation: "depots"
            referencedColumns: ["depot_id"]
          },
          {
            foreignKeyName: "colisage_responsables_employe_id_fkey"
            columns: ["employe_id"]
            isOneToOne: true
            referencedRelation: "employes"
            referencedColumns: ["employe_id"]
          },
        ]
      }
      commande_lignes: {
        Row: {
          commande_id: string
          created_at: string
          designation: string
          ligne_id: string
          montant_remise: number
          prix_unitaire: number
          produit_id: string | null
          quantite: number
          reference_produit: string | null
          remise_pct: number
          total_ht_ligne: number
          total_ligne: number
        }
        Insert: {
          commande_id: string
          created_at?: string
          designation: string
          ligne_id?: string
          montant_remise?: number
          prix_unitaire?: number
          produit_id?: string | null
          quantite?: number
          reference_produit?: string | null
          remise_pct?: number
          total_ht_ligne?: number
          total_ligne?: number
        }
        Update: {
          commande_id?: string
          created_at?: string
          designation?: string
          ligne_id?: string
          montant_remise?: number
          prix_unitaire?: number
          produit_id?: string | null
          quantite?: number
          reference_produit?: string | null
          remise_pct?: number
          total_ht_ligne?: number
          total_ligne?: number
        }
        Relationships: [
          {
            foreignKeyName: "commande_lignes_commande_id_fkey"
            columns: ["commande_id"]
            isOneToOne: false
            referencedRelation: "commandes"
            referencedColumns: ["commande_id"]
          },
          {
            foreignKeyName: "commande_lignes_commande_id_fkey"
            columns: ["commande_id"]
            isOneToOne: false
            referencedRelation: "v_client_achats"
            referencedColumns: ["commande_id"]
          },
          {
            foreignKeyName: "commande_lignes_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "produits"
            referencedColumns: ["produit_id"]
          },
          {
            foreignKeyName: "commande_lignes_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "v_produits"
            referencedColumns: ["produit_id"]
          },
        ]
      }
      commandes: {
        Row: {
          adresse: string | null
          client_id: string | null
          client_nom: string | null
          commande_id: string
          commercial_id: string | null
          commercial_nom: string | null
          created_at: string
          created_by: string | null
          created_by_nom: string | null
          date_commande: string
          depot_id: string | null
          etablissement: string | null
          exercice_id: string
          montant_total: number
          montant_ttc: number
          montant_tva: number
          nb_produits: number
          net_a_payer: number
          notes: string | null
          numero: string | null
          observations: string | null
          reference: string
          remise: number
          remise_globale_montant: number
          remise_globale_pct: number
          representant_nom: string | null
          statut: string
          taux_tva: number
          telephone: string | null
          total_ht_brut: number
          total_ht_net: number
          total_quantite: number
          total_remises_lignes: number
          updated_at: string
          ville: string | null
        }
        Insert: {
          adresse?: string | null
          client_id?: string | null
          client_nom?: string | null
          commande_id?: string
          commercial_id?: string | null
          commercial_nom?: string | null
          created_at?: string
          created_by?: string | null
          created_by_nom?: string | null
          date_commande?: string
          depot_id?: string | null
          etablissement?: string | null
          exercice_id?: string
          montant_total?: number
          montant_ttc?: number
          montant_tva?: number
          nb_produits?: number
          net_a_payer?: number
          notes?: string | null
          numero?: string | null
          observations?: string | null
          reference?: string
          remise?: number
          remise_globale_montant?: number
          remise_globale_pct?: number
          representant_nom?: string | null
          statut?: string
          taux_tva?: number
          telephone?: string | null
          total_ht_brut?: number
          total_ht_net?: number
          total_quantite?: number
          total_remises_lignes?: number
          updated_at?: string
          ville?: string | null
        }
        Update: {
          adresse?: string | null
          client_id?: string | null
          client_nom?: string | null
          commande_id?: string
          commercial_id?: string | null
          commercial_nom?: string | null
          created_at?: string
          created_by?: string | null
          created_by_nom?: string | null
          date_commande?: string
          depot_id?: string | null
          etablissement?: string | null
          exercice_id?: string
          montant_total?: number
          montant_ttc?: number
          montant_tva?: number
          nb_produits?: number
          net_a_payer?: number
          notes?: string | null
          numero?: string | null
          observations?: string | null
          reference?: string
          remise?: number
          remise_globale_montant?: number
          remise_globale_pct?: number
          representant_nom?: string | null
          statut?: string
          taux_tva?: number
          telephone?: string | null
          total_ht_brut?: number
          total_ht_net?: number
          total_quantite?: number
          total_remises_lignes?: number
          updated_at?: string
          ville?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "commandes_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "commandes_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "v_client_achats"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "commandes_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "v_client_stats"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "commandes_depot_id_fkey"
            columns: ["depot_id"]
            isOneToOne: false
            referencedRelation: "depots"
            referencedColumns: ["depot_id"]
          },
          {
            foreignKeyName: "commandes_exercice_id_fkey"
            columns: ["exercice_id"]
            isOneToOne: false
            referencedRelation: "exercices"
            referencedColumns: ["exercice_id"]
          },
        ]
      }
      conges: {
        Row: {
          conge_id: string
          created_at: string
          date_debut: string
          date_fin: string
          employe_id: string
          motif: string | null
          statut: string
          type: string
          updated_at: string
        }
        Insert: {
          conge_id?: string
          created_at?: string
          date_debut: string
          date_fin: string
          employe_id: string
          motif?: string | null
          statut?: string
          type?: string
          updated_at?: string
        }
        Update: {
          conge_id?: string
          created_at?: string
          date_debut?: string
          date_fin?: string
          employe_id?: string
          motif?: string | null
          statut?: string
          type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "conges_employe_id_fkey"
            columns: ["employe_id"]
            isOneToOne: false
            referencedRelation: "employes"
            referencedColumns: ["employe_id"]
          },
        ]
      }
      contrats: {
        Row: {
          contrat_id: string
          created_at: string
          date_debut: string
          date_fin: string | null
          employe_id: string | null
          employe_nom: string | null
          notes: string | null
          salaire: number
          statut: string
          type_contrat: string
          updated_at: string
        }
        Insert: {
          contrat_id?: string
          created_at?: string
          date_debut?: string
          date_fin?: string | null
          employe_id?: string | null
          employe_nom?: string | null
          notes?: string | null
          salaire?: number
          statut?: string
          type_contrat?: string
          updated_at?: string
        }
        Update: {
          contrat_id?: string
          created_at?: string
          date_debut?: string
          date_fin?: string | null
          employe_id?: string | null
          employe_nom?: string | null
          notes?: string | null
          salaire?: number
          statut?: string
          type_contrat?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "contrats_employe_id_fkey"
            columns: ["employe_id"]
            isOneToOne: false
            referencedRelation: "employes"
            referencedColumns: ["employe_id"]
          },
        ]
      }
      couts_logistiques_audit: {
        Row: {
          action: string
          actor: string | null
          actor_email: string | null
          apres: Json | null
          audit_id: string
          avant: Json | null
          commentaire: string | null
          created_at: string
          tournee_id: string
        }
        Insert: {
          action: string
          actor?: string | null
          actor_email?: string | null
          apres?: Json | null
          audit_id?: string
          avant?: Json | null
          commentaire?: string | null
          created_at?: string
          tournee_id: string
        }
        Update: {
          action?: string
          actor?: string | null
          actor_email?: string | null
          apres?: Json | null
          audit_id?: string
          avant?: Json | null
          commentaire?: string | null
          created_at?: string
          tournee_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "couts_logistiques_audit_tournee_id_fkey"
            columns: ["tournee_id"]
            isOneToOne: false
            referencedRelation: "tournees"
            referencedColumns: ["tournee_id"]
          },
        ]
      }
      departements: {
        Row: {
          created_at: string
          departement_id: string
          description: string | null
          nom: string
          responsable: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          departement_id?: string
          description?: string | null
          nom: string
          responsable?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          departement_id?: string
          description?: string | null
          nom?: string
          responsable?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      depots: {
        Row: {
          actif: boolean
          adresse: string | null
          capacite: number | null
          code: string
          code_postal: string | null
          commune: string | null
          created_at: string
          depot_id: string
          description: string | null
          is_principal: boolean
          latitude: number | null
          longitude: number | null
          nom: string
          pays: string | null
          quartier: string | null
          responsable: string | null
          responsable_email: string | null
          telephone: string | null
          type_depot: string
          updated_at: string
          ville: string | null
        }
        Insert: {
          actif?: boolean
          adresse?: string | null
          capacite?: number | null
          code: string
          code_postal?: string | null
          commune?: string | null
          created_at?: string
          depot_id?: string
          description?: string | null
          is_principal?: boolean
          latitude?: number | null
          longitude?: number | null
          nom: string
          pays?: string | null
          quartier?: string | null
          responsable?: string | null
          responsable_email?: string | null
          telephone?: string | null
          type_depot?: string
          updated_at?: string
          ville?: string | null
        }
        Update: {
          actif?: boolean
          adresse?: string | null
          capacite?: number | null
          code?: string
          code_postal?: string | null
          commune?: string | null
          created_at?: string
          depot_id?: string
          description?: string | null
          is_principal?: boolean
          latitude?: number | null
          longitude?: number | null
          nom?: string
          pays?: string | null
          quartier?: string | null
          responsable?: string | null
          responsable_email?: string | null
          telephone?: string | null
          type_depot?: string
          updated_at?: string
          ville?: string | null
        }
        Relationships: []
      }
      document_settings: {
        Row: {
          logo_url: string | null
          selected_template: string
          template_per_type: Json
          updated_at: string
          user_id: string
        }
        Insert: {
          logo_url?: string | null
          selected_template?: string
          template_per_type?: Json
          updated_at?: string
          user_id: string
        }
        Update: {
          logo_url?: string | null
          selected_template?: string
          template_per_type?: Json
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      document_template_prefs: {
        Row: {
          active_template_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          active_template_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          active_template_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      document_templates: {
        Row: {
          config: Json
          created_at: string
          description: string | null
          label: string
          template_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          config: Json
          created_at?: string
          description?: string | null
          label: string
          template_id?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          config?: Json
          created_at?: string
          description?: string | null
          label?: string
          template_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      documents: {
        Row: {
          created_at: string
          date_document: string
          description: string | null
          document_id: string
          statut: string
          titre: string
          type_document: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          date_document?: string
          description?: string | null
          document_id?: string
          statut?: string
          titre: string
          type_document?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          date_document?: string
          description?: string | null
          document_id?: string
          statut?: string
          titre?: string
          type_document?: string
          updated_at?: string
        }
        Relationships: []
      }
      ecriture_lignes: {
        Row: {
          compte: string
          compte_libelle: string
          created_at: string
          credit: number
          debit: number
          ecriture_id: string
          ligne_id: string
        }
        Insert: {
          compte: string
          compte_libelle: string
          created_at?: string
          credit?: number
          debit?: number
          ecriture_id: string
          ligne_id?: string
        }
        Update: {
          compte?: string
          compte_libelle?: string
          created_at?: string
          credit?: number
          debit?: number
          ecriture_id?: string
          ligne_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ecriture_lignes_ecriture_id_fkey"
            columns: ["ecriture_id"]
            isOneToOne: false
            referencedRelation: "ecritures_comptables"
            referencedColumns: ["ecriture_id"]
          },
        ]
      }
      ecritures_comptables: {
        Row: {
          created_at: string
          date_ecriture: string
          ecriture_id: string
          exercice_id: string
          journal: string
          lettrage: string | null
          libelle: string
          montant_total: number
          reference: string
          source_id: string | null
          source_type: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          date_ecriture?: string
          ecriture_id?: string
          exercice_id?: string
          journal?: string
          lettrage?: string | null
          libelle: string
          montant_total?: number
          reference?: string
          source_id?: string | null
          source_type?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          date_ecriture?: string
          ecriture_id?: string
          exercice_id?: string
          journal?: string
          lettrage?: string | null
          libelle?: string
          montant_total?: number
          reference?: string
          source_id?: string | null
          source_type?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "ecritures_comptables_exercice_id_fkey"
            columns: ["exercice_id"]
            isOneToOne: false
            referencedRelation: "exercices"
            referencedColumns: ["exercice_id"]
          },
        ]
      }
      employe_documents: {
        Row: {
          created_at: string
          employe_id: string
          id: string
          mime_type: string | null
          nom: string
          storage_path: string
          taille_octets: number | null
          type_document: string
          updated_at: string
          uploaded_by: string | null
        }
        Insert: {
          created_at?: string
          employe_id: string
          id?: string
          mime_type?: string | null
          nom: string
          storage_path: string
          taille_octets?: number | null
          type_document?: string
          updated_at?: string
          uploaded_by?: string | null
        }
        Update: {
          created_at?: string
          employe_id?: string
          id?: string
          mime_type?: string | null
          nom?: string
          storage_path?: string
          taille_octets?: number | null
          type_document?: string
          updated_at?: string
          uploaded_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "employe_documents_employe_id_fkey"
            columns: ["employe_id"]
            isOneToOne: false
            referencedRelation: "employes"
            referencedColumns: ["employe_id"]
          },
        ]
      }
      employes: {
        Row: {
          actif: boolean
          adresse: string | null
          avantages: Json
          banque: string | null
          categorie: string | null
          centre_cout: string | null
          certifications: Json
          commune: string | null
          competences: string[]
          contact_urgence_lien: string | null
          contact_urgence_nom: string | null
          contact_urgence_telephone: string | null
          created_at: string
          date_embauche: string
          date_fin_contrat: string | null
          date_naissance: string | null
          deleted_at: string | null
          deleted_by: string | null
          departement: string
          devise: string | null
          diplomes: Json
          echelon: string | null
          email: string | null
          employe_id: string
          fonction_id: string | null
          indemnites: Json
          lieu_naissance: string | null
          matricule: string
          mode_paiement:
            | Database["public"]["Enums"]["mode_paiement_enum"]
            | null
          nationalite: string | null
          niveau_etudes: string | null
          nom_complet: string
          numero_cni: string | null
          numero_cnps: string | null
          numero_compte: string | null
          numero_securite_sociale: string | null
          observations: string | null
          pays: string | null
          photo_url: string | null
          poste: string | null
          prenoms: string | null
          primes: Json
          responsable_hierarchique_id: string | null
          salaire: number
          service: string | null
          sexe: Database["public"]["Enums"]["sexe_enum"] | null
          site_affectation: string | null
          situation_matrimoniale:
            | Database["public"]["Enums"]["situation_matrimoniale_enum"]
            | null
          statut_employe:
            | Database["public"]["Enums"]["statut_employe_enum"]
            | null
          telephone: string | null
          telephone_secondaire: string | null
          temps_travail:
            | Database["public"]["Enums"]["temps_travail_enum"]
            | null
          type_contrat: Database["public"]["Enums"]["type_contrat_enum"] | null
          updated_at: string
          user_id: string | null
          ville: string | null
        }
        Insert: {
          actif?: boolean
          adresse?: string | null
          avantages?: Json
          banque?: string | null
          categorie?: string | null
          centre_cout?: string | null
          certifications?: Json
          commune?: string | null
          competences?: string[]
          contact_urgence_lien?: string | null
          contact_urgence_nom?: string | null
          contact_urgence_telephone?: string | null
          created_at?: string
          date_embauche?: string
          date_fin_contrat?: string | null
          date_naissance?: string | null
          deleted_at?: string | null
          deleted_by?: string | null
          departement?: string
          devise?: string | null
          diplomes?: Json
          echelon?: string | null
          email?: string | null
          employe_id?: string
          fonction_id?: string | null
          indemnites?: Json
          lieu_naissance?: string | null
          matricule?: string
          mode_paiement?:
            | Database["public"]["Enums"]["mode_paiement_enum"]
            | null
          nationalite?: string | null
          niveau_etudes?: string | null
          nom_complet: string
          numero_cni?: string | null
          numero_cnps?: string | null
          numero_compte?: string | null
          numero_securite_sociale?: string | null
          observations?: string | null
          pays?: string | null
          photo_url?: string | null
          poste?: string | null
          prenoms?: string | null
          primes?: Json
          responsable_hierarchique_id?: string | null
          salaire?: number
          service?: string | null
          sexe?: Database["public"]["Enums"]["sexe_enum"] | null
          site_affectation?: string | null
          situation_matrimoniale?:
            | Database["public"]["Enums"]["situation_matrimoniale_enum"]
            | null
          statut_employe?:
            | Database["public"]["Enums"]["statut_employe_enum"]
            | null
          telephone?: string | null
          telephone_secondaire?: string | null
          temps_travail?:
            | Database["public"]["Enums"]["temps_travail_enum"]
            | null
          type_contrat?: Database["public"]["Enums"]["type_contrat_enum"] | null
          updated_at?: string
          user_id?: string | null
          ville?: string | null
        }
        Update: {
          actif?: boolean
          adresse?: string | null
          avantages?: Json
          banque?: string | null
          categorie?: string | null
          centre_cout?: string | null
          certifications?: Json
          commune?: string | null
          competences?: string[]
          contact_urgence_lien?: string | null
          contact_urgence_nom?: string | null
          contact_urgence_telephone?: string | null
          created_at?: string
          date_embauche?: string
          date_fin_contrat?: string | null
          date_naissance?: string | null
          deleted_at?: string | null
          deleted_by?: string | null
          departement?: string
          devise?: string | null
          diplomes?: Json
          echelon?: string | null
          email?: string | null
          employe_id?: string
          fonction_id?: string | null
          indemnites?: Json
          lieu_naissance?: string | null
          matricule?: string
          mode_paiement?:
            | Database["public"]["Enums"]["mode_paiement_enum"]
            | null
          nationalite?: string | null
          niveau_etudes?: string | null
          nom_complet?: string
          numero_cni?: string | null
          numero_cnps?: string | null
          numero_compte?: string | null
          numero_securite_sociale?: string | null
          observations?: string | null
          pays?: string | null
          photo_url?: string | null
          poste?: string | null
          prenoms?: string | null
          primes?: Json
          responsable_hierarchique_id?: string | null
          salaire?: number
          service?: string | null
          sexe?: Database["public"]["Enums"]["sexe_enum"] | null
          site_affectation?: string | null
          situation_matrimoniale?:
            | Database["public"]["Enums"]["situation_matrimoniale_enum"]
            | null
          statut_employe?:
            | Database["public"]["Enums"]["statut_employe_enum"]
            | null
          telephone?: string | null
          telephone_secondaire?: string | null
          temps_travail?:
            | Database["public"]["Enums"]["temps_travail_enum"]
            | null
          type_contrat?: Database["public"]["Enums"]["type_contrat_enum"] | null
          updated_at?: string
          user_id?: string | null
          ville?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "employes_fonction_id_fkey"
            columns: ["fonction_id"]
            isOneToOne: false
            referencedRelation: "fonctions"
            referencedColumns: ["fonction_id"]
          },
          {
            foreignKeyName: "employes_responsable_hierarchique_id_fkey"
            columns: ["responsable_hierarchique_id"]
            isOneToOne: false
            referencedRelation: "employes"
            referencedColumns: ["employe_id"]
          },
        ]
      }
      evaluations: {
        Row: {
          commentaire: string | null
          created_at: string
          date_evaluation: string
          employe_id: string | null
          employe_nom: string | null
          evaluation_id: string
          note: number
          periode: string | null
          updated_at: string
        }
        Insert: {
          commentaire?: string | null
          created_at?: string
          date_evaluation?: string
          employe_id?: string | null
          employe_nom?: string | null
          evaluation_id?: string
          note?: number
          periode?: string | null
          updated_at?: string
        }
        Update: {
          commentaire?: string | null
          created_at?: string
          date_evaluation?: string
          employe_id?: string | null
          employe_nom?: string | null
          evaluation_id?: string
          note?: number
          periode?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "evaluations_employe_id_fkey"
            columns: ["employe_id"]
            isOneToOne: false
            referencedRelation: "employes"
            referencedColumns: ["employe_id"]
          },
        ]
      }
      exercice_cloture_journal: {
        Row: {
          cloture_par: string | null
          date_cloture: string
          details: Json | null
          exercice_cible_id: string
          exercice_source_id: string
          journal_id: string
          montant_total_clients: number
          montant_total_fournisseurs: number
          nb_clients_reportes: number
          nb_fournisseurs_reportes: number
        }
        Insert: {
          cloture_par?: string | null
          date_cloture?: string
          details?: Json | null
          exercice_cible_id: string
          exercice_source_id: string
          journal_id?: string
          montant_total_clients?: number
          montant_total_fournisseurs?: number
          nb_clients_reportes?: number
          nb_fournisseurs_reportes?: number
        }
        Update: {
          cloture_par?: string | null
          date_cloture?: string
          details?: Json | null
          exercice_cible_id?: string
          exercice_source_id?: string
          journal_id?: string
          montant_total_clients?: number
          montant_total_fournisseurs?: number
          nb_clients_reportes?: number
          nb_fournisseurs_reportes?: number
        }
        Relationships: [
          {
            foreignKeyName: "exercice_cloture_journal_exercice_cible_id_fkey"
            columns: ["exercice_cible_id"]
            isOneToOne: false
            referencedRelation: "exercices"
            referencedColumns: ["exercice_id"]
          },
          {
            foreignKeyName: "exercice_cloture_journal_exercice_source_id_fkey"
            columns: ["exercice_source_id"]
            isOneToOne: false
            referencedRelation: "exercices"
            referencedColumns: ["exercice_id"]
          },
        ]
      }
      exercices: {
        Row: {
          cloture_par: string | null
          code: string
          created_at: string
          date_cloture: string | null
          date_debut: string
          date_fin: string
          exercice_id: string
          is_actif: boolean
          statut: Database["public"]["Enums"]["exercice_statut"]
          updated_at: string
        }
        Insert: {
          cloture_par?: string | null
          code: string
          created_at?: string
          date_cloture?: string | null
          date_debut: string
          date_fin: string
          exercice_id?: string
          is_actif?: boolean
          statut?: Database["public"]["Enums"]["exercice_statut"]
          updated_at?: string
        }
        Update: {
          cloture_par?: string | null
          code?: string
          created_at?: string
          date_cloture?: string | null
          date_debut?: string
          date_fin?: string
          exercice_id?: string
          is_actif?: boolean
          statut?: Database["public"]["Enums"]["exercice_statut"]
          updated_at?: string
        }
        Relationships: []
      }
      expeditions: {
        Row: {
          bl_id: string | null
          cout: number
          created_at: string
          date_arrivee_prevue: string | null
          date_arrivee_reelle: string | null
          date_depart: string | null
          expedition_id: string
          notes: string | null
          ordre_colisage_id: string | null
          reference: string
          statut: string
          tournee_id: string | null
          tracking: string | null
          transporteur: string | null
          updated_at: string
        }
        Insert: {
          bl_id?: string | null
          cout?: number
          created_at?: string
          date_arrivee_prevue?: string | null
          date_arrivee_reelle?: string | null
          date_depart?: string | null
          expedition_id?: string
          notes?: string | null
          ordre_colisage_id?: string | null
          reference?: string
          statut?: string
          tournee_id?: string | null
          tracking?: string | null
          transporteur?: string | null
          updated_at?: string
        }
        Update: {
          bl_id?: string | null
          cout?: number
          created_at?: string
          date_arrivee_prevue?: string | null
          date_arrivee_reelle?: string | null
          date_depart?: string | null
          expedition_id?: string
          notes?: string | null
          ordre_colisage_id?: string | null
          reference?: string
          statut?: string
          tournee_id?: string | null
          tracking?: string | null
          transporteur?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "expeditions_bl_id_fkey"
            columns: ["bl_id"]
            isOneToOne: false
            referencedRelation: "bons_livraison"
            referencedColumns: ["bl_id"]
          },
          {
            foreignKeyName: "expeditions_ordre_colisage_id_fkey"
            columns: ["ordre_colisage_id"]
            isOneToOne: false
            referencedRelation: "ordres_colisage"
            referencedColumns: ["ordre_id"]
          },
          {
            foreignKeyName: "expeditions_tournee_id_fkey"
            columns: ["tournee_id"]
            isOneToOne: false
            referencedRelation: "tournees"
            referencedColumns: ["tournee_id"]
          },
        ]
      }
      factures: {
        Row: {
          client_id: string | null
          client_nom: string | null
          commande_id: string | null
          created_at: string
          date_echeance: string | null
          date_facture: string
          exercice_id: string
          facture_id: string
          montant_paye: number
          montant_total: number
          notes: string | null
          reference: string
          statut: string
          updated_at: string
        }
        Insert: {
          client_id?: string | null
          client_nom?: string | null
          commande_id?: string | null
          created_at?: string
          date_echeance?: string | null
          date_facture?: string
          exercice_id?: string
          facture_id?: string
          montant_paye?: number
          montant_total?: number
          notes?: string | null
          reference?: string
          statut?: string
          updated_at?: string
        }
        Update: {
          client_id?: string | null
          client_nom?: string | null
          commande_id?: string | null
          created_at?: string
          date_echeance?: string | null
          date_facture?: string
          exercice_id?: string
          facture_id?: string
          montant_paye?: number
          montant_total?: number
          notes?: string | null
          reference?: string
          statut?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "factures_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "factures_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "v_client_achats"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "factures_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "v_client_stats"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "factures_commande_id_fkey"
            columns: ["commande_id"]
            isOneToOne: false
            referencedRelation: "commandes"
            referencedColumns: ["commande_id"]
          },
          {
            foreignKeyName: "factures_commande_id_fkey"
            columns: ["commande_id"]
            isOneToOne: false
            referencedRelation: "v_client_achats"
            referencedColumns: ["commande_id"]
          },
          {
            foreignKeyName: "factures_exercice_id_fkey"
            columns: ["exercice_id"]
            isOneToOne: false
            referencedRelation: "exercices"
            referencedColumns: ["exercice_id"]
          },
        ]
      }
      finances_corrections_audit: {
        Row: {
          champ: string
          cible_id: string
          cible_type: string
          correction_id: string
          corrige_par: string | null
          corrige_par_nom: string | null
          created_at: string
          ecart: number
          motif: string | null
          valeur_apres: number
          valeur_avant: number
        }
        Insert: {
          champ: string
          cible_id: string
          cible_type: string
          correction_id?: string
          corrige_par?: string | null
          corrige_par_nom?: string | null
          created_at?: string
          ecart: number
          motif?: string | null
          valeur_apres: number
          valeur_avant: number
        }
        Update: {
          champ?: string
          cible_id?: string
          cible_type?: string
          correction_id?: string
          corrige_par?: string | null
          corrige_par_nom?: string | null
          created_at?: string
          ecart?: number
          motif?: string | null
          valeur_apres?: number
          valeur_avant?: number
        }
        Relationships: []
      }
      fne_factures: {
        Row: {
          balance_sticker: number | null
          client_email: string | null
          client_ncc: string | null
          client_nom: string | null
          client_seller_name: string | null
          client_telephone: string | null
          code_dgi: string | null
          commercial_message: string | null
          created_at: string
          date_emission: string
          discount: number | null
          error_message: string | null
          establishment: string | null
          facture_id: string | null
          fne_id: string
          footer: string | null
          invoice_type: string | null
          items: Json | null
          montant: number
          notes: string | null
          parent_fne_id: string | null
          payment_method: string | null
          point_of_sale: string | null
          qr_code: string | null
          reference: string
          response_payload: Json | null
          retry_count: number | null
          source: string | null
          statut: string
          submitted_at: string | null
          template: string | null
          token: string | null
          updated_at: string
          validated_at: string | null
          verification_url: string | null
        }
        Insert: {
          balance_sticker?: number | null
          client_email?: string | null
          client_ncc?: string | null
          client_nom?: string | null
          client_seller_name?: string | null
          client_telephone?: string | null
          code_dgi?: string | null
          commercial_message?: string | null
          created_at?: string
          date_emission?: string
          discount?: number | null
          error_message?: string | null
          establishment?: string | null
          facture_id?: string | null
          fne_id?: string
          footer?: string | null
          invoice_type?: string | null
          items?: Json | null
          montant?: number
          notes?: string | null
          parent_fne_id?: string | null
          payment_method?: string | null
          point_of_sale?: string | null
          qr_code?: string | null
          reference?: string
          response_payload?: Json | null
          retry_count?: number | null
          source?: string | null
          statut?: string
          submitted_at?: string | null
          template?: string | null
          token?: string | null
          updated_at?: string
          validated_at?: string | null
          verification_url?: string | null
        }
        Update: {
          balance_sticker?: number | null
          client_email?: string | null
          client_ncc?: string | null
          client_nom?: string | null
          client_seller_name?: string | null
          client_telephone?: string | null
          code_dgi?: string | null
          commercial_message?: string | null
          created_at?: string
          date_emission?: string
          discount?: number | null
          error_message?: string | null
          establishment?: string | null
          facture_id?: string | null
          fne_id?: string
          footer?: string | null
          invoice_type?: string | null
          items?: Json | null
          montant?: number
          notes?: string | null
          parent_fne_id?: string | null
          payment_method?: string | null
          point_of_sale?: string | null
          qr_code?: string | null
          reference?: string
          response_payload?: Json | null
          retry_count?: number | null
          source?: string | null
          statut?: string
          submitted_at?: string | null
          template?: string | null
          token?: string | null
          updated_at?: string
          validated_at?: string | null
          verification_url?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fne_factures_facture_id_fkey"
            columns: ["facture_id"]
            isOneToOne: false
            referencedRelation: "factures"
            referencedColumns: ["facture_id"]
          },
          {
            foreignKeyName: "fne_factures_parent_fne_id_fkey"
            columns: ["parent_fne_id"]
            isOneToOne: false
            referencedRelation: "fne_factures"
            referencedColumns: ["fne_id"]
          },
        ]
      }
      fne_logs: {
        Row: {
          action: string
          attempt_number: number | null
          created_at: string
          duration_ms: number | null
          fne_facture_id: string | null
          http_status: number | null
          log_id: string
          payload: Json | null
          response: Json | null
          statut: string
          user_nom: string | null
        }
        Insert: {
          action: string
          attempt_number?: number | null
          created_at?: string
          duration_ms?: number | null
          fne_facture_id?: string | null
          http_status?: number | null
          log_id?: string
          payload?: Json | null
          response?: Json | null
          statut?: string
          user_nom?: string | null
        }
        Update: {
          action?: string
          attempt_number?: number | null
          created_at?: string
          duration_ms?: number | null
          fne_facture_id?: string | null
          http_status?: number | null
          log_id?: string
          payload?: Json | null
          response?: Json | null
          statut?: string
          user_nom?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fne_logs_fne_facture_id_fkey"
            columns: ["fne_facture_id"]
            isOneToOne: false
            referencedRelation: "fne_factures"
            referencedColumns: ["fne_id"]
          },
        ]
      }
      fne_settings: {
        Row: {
          cle: string
          description: string | null
          setting_id: string
          updated_at: string
          valeur: string | null
        }
        Insert: {
          cle: string
          description?: string | null
          setting_id?: string
          updated_at?: string
          valeur?: string | null
        }
        Update: {
          cle?: string
          description?: string | null
          setting_id?: string
          updated_at?: string
          valeur?: string | null
        }
        Relationships: []
      }
      fonctions: {
        Row: {
          actif: boolean
          created_at: string
          departement_id: string | null
          description: string | null
          fonction_id: string
          libelle: string
          updated_at: string
        }
        Insert: {
          actif?: boolean
          created_at?: string
          departement_id?: string | null
          description?: string | null
          fonction_id?: string
          libelle: string
          updated_at?: string
        }
        Update: {
          actif?: boolean
          created_at?: string
          departement_id?: string | null
          description?: string | null
          fonction_id?: string
          libelle?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fonctions_departement_id_fkey"
            columns: ["departement_id"]
            isOneToOne: false
            referencedRelation: "departements"
            referencedColumns: ["departement_id"]
          },
        ]
      }
      fournisseurs: {
        Row: {
          actif: boolean
          adresse: string | null
          contact: string | null
          created_at: string
          email: string | null
          fournisseur_id: string
          raison_sociale: string
          telephone: string | null
          updated_at: string
          ville: string | null
        }
        Insert: {
          actif?: boolean
          adresse?: string | null
          contact?: string | null
          created_at?: string
          email?: string | null
          fournisseur_id?: string
          raison_sociale: string
          telephone?: string | null
          updated_at?: string
          ville?: string | null
        }
        Update: {
          actif?: boolean
          adresse?: string | null
          contact?: string | null
          created_at?: string
          email?: string | null
          fournisseur_id?: string
          raison_sociale?: string
          telephone?: string | null
          updated_at?: string
          ville?: string | null
        }
        Relationships: []
      }
      gares: {
        Row: {
          actif: boolean
          code: string | null
          created_at: string
          gare_id: string
          nom: string
          notes: string | null
          transporteur_id: string | null
          updated_at: string
          ville: string | null
        }
        Insert: {
          actif?: boolean
          code?: string | null
          created_at?: string
          gare_id?: string
          nom: string
          notes?: string | null
          transporteur_id?: string | null
          updated_at?: string
          ville?: string | null
        }
        Update: {
          actif?: boolean
          code?: string | null
          created_at?: string
          gare_id?: string
          nom?: string
          notes?: string | null
          transporteur_id?: string | null
          updated_at?: string
          ville?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "gares_transporteur_id_fkey"
            columns: ["transporteur_id"]
            isOneToOne: false
            referencedRelation: "transporteurs"
            referencedColumns: ["transporteur_id"]
          },
        ]
      }
      historique_envois: {
        Row: {
          canal: string
          contenu: string | null
          created_at: string
          destinataire: string
          document_id: string | null
          document_type: string | null
          envoi_id: string
          envoye_par: string | null
          erreur: string | null
          statut: string
          sujet: string | null
        }
        Insert: {
          canal: string
          contenu?: string | null
          created_at?: string
          destinataire: string
          document_id?: string | null
          document_type?: string | null
          envoi_id?: string
          envoye_par?: string | null
          erreur?: string | null
          statut?: string
          sujet?: string | null
        }
        Update: {
          canal?: string
          contenu?: string | null
          created_at?: string
          destinataire?: string
          document_id?: string | null
          document_type?: string | null
          envoi_id?: string
          envoye_par?: string | null
          erreur?: string | null
          statut?: string
          sujet?: string | null
        }
        Relationships: []
      }
      incident_alerts: {
        Row: {
          context: Json | null
          created_at: string
          id: string
          message: string | null
          resolved: boolean
          resolved_at: string | null
          resolved_by: string | null
          severity: string
          source: string
          title: string
        }
        Insert: {
          context?: Json | null
          created_at?: string
          id?: string
          message?: string | null
          resolved?: boolean
          resolved_at?: string | null
          resolved_by?: string | null
          severity: string
          source: string
          title: string
        }
        Update: {
          context?: Json | null
          created_at?: string
          id?: string
          message?: string | null
          resolved?: boolean
          resolved_at?: string | null
          resolved_by?: string | null
          severity?: string
          source?: string
          title?: string
        }
        Relationships: []
      }
      incident_lignes: {
        Row: {
          created_at: string
          designation: string
          incident_id: string
          ligne_id: string
          produit_id: string
          quantite: number
          reference_produit: string | null
        }
        Insert: {
          created_at?: string
          designation: string
          incident_id: string
          ligne_id?: string
          produit_id: string
          quantite: number
          reference_produit?: string | null
        }
        Update: {
          created_at?: string
          designation?: string
          incident_id?: string
          ligne_id?: string
          produit_id?: string
          quantite?: number
          reference_produit?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "incident_lignes_incident_id_fkey"
            columns: ["incident_id"]
            isOneToOne: false
            referencedRelation: "incidents"
            referencedColumns: ["incident_id"]
          },
          {
            foreignKeyName: "incident_lignes_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "produits"
            referencedColumns: ["produit_id"]
          },
          {
            foreignKeyName: "incident_lignes_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "v_produits"
            referencedColumns: ["produit_id"]
          },
        ]
      }
      incidents: {
        Row: {
          created_at: string
          date_incident: string
          depot_id: string | null
          description: string | null
          gravite: string
          incident_id: string
          motif: string | null
          nb_produits: number
          numero: string | null
          observations: string | null
          reference: string
          responsable_id: string | null
          responsable_nom: string | null
          statut: string
          total_quantite: number
          type_incident: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          date_incident?: string
          depot_id?: string | null
          description?: string | null
          gravite?: string
          incident_id?: string
          motif?: string | null
          nb_produits?: number
          numero?: string | null
          observations?: string | null
          reference?: string
          responsable_id?: string | null
          responsable_nom?: string | null
          statut?: string
          total_quantite?: number
          type_incident?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          date_incident?: string
          depot_id?: string | null
          description?: string | null
          gravite?: string
          incident_id?: string
          motif?: string | null
          nb_produits?: number
          numero?: string | null
          observations?: string | null
          reference?: string
          responsable_id?: string | null
          responsable_nom?: string | null
          statut?: string
          total_quantite?: number
          type_incident?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "incidents_depot_id_fkey"
            columns: ["depot_id"]
            isOneToOne: false
            referencedRelation: "depots"
            referencedColumns: ["depot_id"]
          },
        ]
      }
      inventaire_lignes: {
        Row: {
          created_at: string
          designation: string
          ecart: number
          inventaire_id: string
          ligne_id: string
          observation: string | null
          produit_id: string
          quantite_comptee: number
          reference_produit: string | null
          stock_theorique: number
          valeur_ecart: number
          valeur_unitaire: number
        }
        Insert: {
          created_at?: string
          designation: string
          ecart?: number
          inventaire_id: string
          ligne_id?: string
          observation?: string | null
          produit_id: string
          quantite_comptee?: number
          reference_produit?: string | null
          stock_theorique?: number
          valeur_ecart?: number
          valeur_unitaire?: number
        }
        Update: {
          created_at?: string
          designation?: string
          ecart?: number
          inventaire_id?: string
          ligne_id?: string
          observation?: string | null
          produit_id?: string
          quantite_comptee?: number
          reference_produit?: string | null
          stock_theorique?: number
          valeur_ecart?: number
          valeur_unitaire?: number
        }
        Relationships: [
          {
            foreignKeyName: "inventaire_lignes_inventaire_id_fkey"
            columns: ["inventaire_id"]
            isOneToOne: false
            referencedRelation: "inventaires"
            referencedColumns: ["inventaire_id"]
          },
          {
            foreignKeyName: "inventaire_lignes_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "produits"
            referencedColumns: ["produit_id"]
          },
          {
            foreignKeyName: "inventaire_lignes_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "v_produits"
            referencedColumns: ["produit_id"]
          },
        ]
      }
      inventaires: {
        Row: {
          categorie_id: string | null
          created_at: string
          created_by: string | null
          created_by_nom: string | null
          date_inventaire: string
          depot_id: string | null
          exercice_id: string
          inventaire_id: string
          nb_ecarts: number
          nb_produits: number
          numero: string
          observations: string | null
          regularized_at: string | null
          statut: string
          type_inventaire: string
          updated_at: string
          valeur_totale: number
          validated_at: string | null
          validated_by: string | null
        }
        Insert: {
          categorie_id?: string | null
          created_at?: string
          created_by?: string | null
          created_by_nom?: string | null
          date_inventaire?: string
          depot_id?: string | null
          exercice_id?: string
          inventaire_id?: string
          nb_ecarts?: number
          nb_produits?: number
          numero: string
          observations?: string | null
          regularized_at?: string | null
          statut?: string
          type_inventaire: string
          updated_at?: string
          valeur_totale?: number
          validated_at?: string | null
          validated_by?: string | null
        }
        Update: {
          categorie_id?: string | null
          created_at?: string
          created_by?: string | null
          created_by_nom?: string | null
          date_inventaire?: string
          depot_id?: string | null
          exercice_id?: string
          inventaire_id?: string
          nb_ecarts?: number
          nb_produits?: number
          numero?: string
          observations?: string | null
          regularized_at?: string | null
          statut?: string
          type_inventaire?: string
          updated_at?: string
          valeur_totale?: number
          validated_at?: string | null
          validated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "inventaires_categorie_id_fkey"
            columns: ["categorie_id"]
            isOneToOne: false
            referencedRelation: "categories_produits"
            referencedColumns: ["categorie_id"]
          },
          {
            foreignKeyName: "inventaires_depot_id_fkey"
            columns: ["depot_id"]
            isOneToOne: false
            referencedRelation: "depots"
            referencedColumns: ["depot_id"]
          },
          {
            foreignKeyName: "inventaires_exercice_id_fkey"
            columns: ["exercice_id"]
            isOneToOne: false
            referencedRelation: "exercices"
            referencedColumns: ["exercice_id"]
          },
        ]
      }
      livraison_commande_historique: {
        Row: {
          ancien_statut:
            | Database["public"]["Enums"]["statut_livraison_cmd"]
            | null
          commentaire: string | null
          created_at: string
          id: string
          livraison_id: string
          nouveau_statut: Database["public"]["Enums"]["statut_livraison_cmd"]
          user_id: string | null
          user_nom: string | null
        }
        Insert: {
          ancien_statut?:
            | Database["public"]["Enums"]["statut_livraison_cmd"]
            | null
          commentaire?: string | null
          created_at?: string
          id?: string
          livraison_id: string
          nouveau_statut: Database["public"]["Enums"]["statut_livraison_cmd"]
          user_id?: string | null
          user_nom?: string | null
        }
        Update: {
          ancien_statut?:
            | Database["public"]["Enums"]["statut_livraison_cmd"]
            | null
          commentaire?: string | null
          created_at?: string
          id?: string
          livraison_id?: string
          nouveau_statut?: Database["public"]["Enums"]["statut_livraison_cmd"]
          user_id?: string | null
          user_nom?: string | null
        }
        Relationships: []
      }
      livraisons: {
        Row: {
          adresse: string | null
          bl_id: string | null
          client_id: string | null
          client_nom: string | null
          commande_id: string | null
          commune: string | null
          contact_dest: string | null
          created_at: string
          date_livraison: string
          expedition_id: string | null
          figee: boolean
          gare_arrivee_id: string | null
          gare_depart_id: string | null
          livraison_id: string
          livreur_id: string | null
          notes: string | null
          reference: string
          statut: string
          telephone_dest: string | null
          tournee_id: string | null
          transporteur: string | null
          transporteur_id: string | null
          updated_at: string
          ville: string | null
        }
        Insert: {
          adresse?: string | null
          bl_id?: string | null
          client_id?: string | null
          client_nom?: string | null
          commande_id?: string | null
          commune?: string | null
          contact_dest?: string | null
          created_at?: string
          date_livraison?: string
          expedition_id?: string | null
          figee?: boolean
          gare_arrivee_id?: string | null
          gare_depart_id?: string | null
          livraison_id?: string
          livreur_id?: string | null
          notes?: string | null
          reference?: string
          statut?: string
          telephone_dest?: string | null
          tournee_id?: string | null
          transporteur?: string | null
          transporteur_id?: string | null
          updated_at?: string
          ville?: string | null
        }
        Update: {
          adresse?: string | null
          bl_id?: string | null
          client_id?: string | null
          client_nom?: string | null
          commande_id?: string | null
          commune?: string | null
          contact_dest?: string | null
          created_at?: string
          date_livraison?: string
          expedition_id?: string | null
          figee?: boolean
          gare_arrivee_id?: string | null
          gare_depart_id?: string | null
          livraison_id?: string
          livreur_id?: string | null
          notes?: string | null
          reference?: string
          statut?: string
          telephone_dest?: string | null
          tournee_id?: string | null
          transporteur?: string | null
          transporteur_id?: string | null
          updated_at?: string
          ville?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "livraisons_bl_id_fkey"
            columns: ["bl_id"]
            isOneToOne: false
            referencedRelation: "bons_livraison"
            referencedColumns: ["bl_id"]
          },
          {
            foreignKeyName: "livraisons_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "livraisons_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "v_client_achats"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "livraisons_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "v_client_stats"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "livraisons_commande_id_fkey"
            columns: ["commande_id"]
            isOneToOne: false
            referencedRelation: "commandes"
            referencedColumns: ["commande_id"]
          },
          {
            foreignKeyName: "livraisons_commande_id_fkey"
            columns: ["commande_id"]
            isOneToOne: false
            referencedRelation: "v_client_achats"
            referencedColumns: ["commande_id"]
          },
          {
            foreignKeyName: "livraisons_expedition_id_fkey"
            columns: ["expedition_id"]
            isOneToOne: false
            referencedRelation: "expeditions"
            referencedColumns: ["expedition_id"]
          },
          {
            foreignKeyName: "livraisons_gare_arrivee_id_fkey"
            columns: ["gare_arrivee_id"]
            isOneToOne: false
            referencedRelation: "gares"
            referencedColumns: ["gare_id"]
          },
          {
            foreignKeyName: "livraisons_gare_depart_id_fkey"
            columns: ["gare_depart_id"]
            isOneToOne: false
            referencedRelation: "gares"
            referencedColumns: ["gare_id"]
          },
          {
            foreignKeyName: "livraisons_livreur_id_fkey"
            columns: ["livreur_id"]
            isOneToOne: false
            referencedRelation: "livreurs"
            referencedColumns: ["livreur_id"]
          },
          {
            foreignKeyName: "livraisons_tournee_id_fkey"
            columns: ["tournee_id"]
            isOneToOne: false
            referencedRelation: "tournees"
            referencedColumns: ["tournee_id"]
          },
          {
            foreignKeyName: "livraisons_transporteur_id_fkey"
            columns: ["transporteur_id"]
            isOneToOne: false
            referencedRelation: "transporteurs"
            referencedColumns: ["transporteur_id"]
          },
        ]
      }
      livraisons_commande: {
        Row: {
          anomalie_motif: string | null
          bl_id: string | null
          chauffeur_nom: string | null
          commande_id: string
          created_at: string
          date_confirmation: string | null
          date_expedition: string | null
          date_livraison: string | null
          date_prevue_livraison: string | null
          derniere_maj: string
          gare_nom: string | null
          livraison_id: string
          nb_cartons: number
          observations: string | null
          progression_pct: number
          quantite_commandee: number
          quantite_expediee: number
          quantite_livree: number
          quantite_preparee: number
          statut: Database["public"]["Enums"]["statut_livraison_cmd"]
          tournee_id: string | null
          transporteur: string | null
          type_livraison: string | null
          updated_at: string
          vehicule: string | null
          ville_livraison: string | null
        }
        Insert: {
          anomalie_motif?: string | null
          bl_id?: string | null
          chauffeur_nom?: string | null
          commande_id: string
          created_at?: string
          date_confirmation?: string | null
          date_expedition?: string | null
          date_livraison?: string | null
          date_prevue_livraison?: string | null
          derniere_maj?: string
          gare_nom?: string | null
          livraison_id?: string
          nb_cartons?: number
          observations?: string | null
          progression_pct?: number
          quantite_commandee?: number
          quantite_expediee?: number
          quantite_livree?: number
          quantite_preparee?: number
          statut?: Database["public"]["Enums"]["statut_livraison_cmd"]
          tournee_id?: string | null
          transporteur?: string | null
          type_livraison?: string | null
          updated_at?: string
          vehicule?: string | null
          ville_livraison?: string | null
        }
        Update: {
          anomalie_motif?: string | null
          bl_id?: string | null
          chauffeur_nom?: string | null
          commande_id?: string
          created_at?: string
          date_confirmation?: string | null
          date_expedition?: string | null
          date_livraison?: string | null
          date_prevue_livraison?: string | null
          derniere_maj?: string
          gare_nom?: string | null
          livraison_id?: string
          nb_cartons?: number
          observations?: string | null
          progression_pct?: number
          quantite_commandee?: number
          quantite_expediee?: number
          quantite_livree?: number
          quantite_preparee?: number
          statut?: Database["public"]["Enums"]["statut_livraison_cmd"]
          tournee_id?: string | null
          transporteur?: string | null
          type_livraison?: string | null
          updated_at?: string
          vehicule?: string | null
          ville_livraison?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "livraisons_commande_bl_id_fkey"
            columns: ["bl_id"]
            isOneToOne: false
            referencedRelation: "bons_livraison"
            referencedColumns: ["bl_id"]
          },
          {
            foreignKeyName: "livraisons_commande_commande_id_fkey"
            columns: ["commande_id"]
            isOneToOne: true
            referencedRelation: "commandes"
            referencedColumns: ["commande_id"]
          },
          {
            foreignKeyName: "livraisons_commande_commande_id_fkey"
            columns: ["commande_id"]
            isOneToOne: true
            referencedRelation: "v_client_achats"
            referencedColumns: ["commande_id"]
          },
          {
            foreignKeyName: "livraisons_commande_tournee_id_fkey"
            columns: ["tournee_id"]
            isOneToOne: false
            referencedRelation: "tournees"
            referencedColumns: ["tournee_id"]
          },
        ]
      }
      livreurs: {
        Row: {
          actif: boolean
          created_at: string
          immatriculation: string | null
          livreur_id: string
          nom: string
          observations: string | null
          societe: string | null
          telephone: string | null
          updated_at: string
          vehicule_defaut: string | null
        }
        Insert: {
          actif?: boolean
          created_at?: string
          immatriculation?: string | null
          livreur_id?: string
          nom: string
          observations?: string | null
          societe?: string | null
          telephone?: string | null
          updated_at?: string
          vehicule_defaut?: string | null
        }
        Update: {
          actif?: boolean
          created_at?: string
          immatriculation?: string | null
          livreur_id?: string
          nom?: string
          observations?: string | null
          societe?: string | null
          telephone?: string | null
          updated_at?: string
          vehicule_defaut?: string | null
        }
        Relationships: []
      }
      livsuivi_commandes: {
        Row: {
          bl_id: string | null
          cloturee: boolean
          commande_id: string
          commentaire_reception: string | null
          created_at: string
          derniere_maj: string
          gare_depot: string | null
          gare_destination: string | null
          heure_arrivee: string | null
          heure_depart: string | null
          heure_livraison: string | null
          id: string
          livreur_nom: string | null
          nb_cartons: number | null
          ordre_passage: number | null
          photo_preuve_url: string | null
          point_livraison: string | null
          receptionnaire_nom: string | null
          receptionnaire_telephone: string | null
          retour_motif: string | null
          signature_url: string | null
          statut: Database["public"]["Enums"]["livsuivi_statut"]
          tournee_id: string | null
          type_livraison: Database["public"]["Enums"]["livsuivi_type"]
          updated_at: string
          vehicule: string | null
          ville_destination: string | null
        }
        Insert: {
          bl_id?: string | null
          cloturee?: boolean
          commande_id: string
          commentaire_reception?: string | null
          created_at?: string
          derniere_maj?: string
          gare_depot?: string | null
          gare_destination?: string | null
          heure_arrivee?: string | null
          heure_depart?: string | null
          heure_livraison?: string | null
          id?: string
          livreur_nom?: string | null
          nb_cartons?: number | null
          ordre_passage?: number | null
          photo_preuve_url?: string | null
          point_livraison?: string | null
          receptionnaire_nom?: string | null
          receptionnaire_telephone?: string | null
          retour_motif?: string | null
          signature_url?: string | null
          statut?: Database["public"]["Enums"]["livsuivi_statut"]
          tournee_id?: string | null
          type_livraison?: Database["public"]["Enums"]["livsuivi_type"]
          updated_at?: string
          vehicule?: string | null
          ville_destination?: string | null
        }
        Update: {
          bl_id?: string | null
          cloturee?: boolean
          commande_id?: string
          commentaire_reception?: string | null
          created_at?: string
          derniere_maj?: string
          gare_depot?: string | null
          gare_destination?: string | null
          heure_arrivee?: string | null
          heure_depart?: string | null
          heure_livraison?: string | null
          id?: string
          livreur_nom?: string | null
          nb_cartons?: number | null
          ordre_passage?: number | null
          photo_preuve_url?: string | null
          point_livraison?: string | null
          receptionnaire_nom?: string | null
          receptionnaire_telephone?: string | null
          retour_motif?: string | null
          signature_url?: string | null
          statut?: Database["public"]["Enums"]["livsuivi_statut"]
          tournee_id?: string | null
          type_livraison?: Database["public"]["Enums"]["livsuivi_type"]
          updated_at?: string
          vehicule?: string | null
          ville_destination?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "livsuivi_commandes_bl_id_fkey"
            columns: ["bl_id"]
            isOneToOne: false
            referencedRelation: "bons_livraison"
            referencedColumns: ["bl_id"]
          },
          {
            foreignKeyName: "livsuivi_commandes_commande_id_fkey"
            columns: ["commande_id"]
            isOneToOne: true
            referencedRelation: "commandes"
            referencedColumns: ["commande_id"]
          },
          {
            foreignKeyName: "livsuivi_commandes_commande_id_fkey"
            columns: ["commande_id"]
            isOneToOne: true
            referencedRelation: "v_client_achats"
            referencedColumns: ["commande_id"]
          },
          {
            foreignKeyName: "livsuivi_commandes_tournee_id_fkey"
            columns: ["tournee_id"]
            isOneToOne: false
            referencedRelation: "tournees"
            referencedColumns: ["tournee_id"]
          },
        ]
      }
      livsuivi_historique: {
        Row: {
          commentaire: string | null
          created_at: string
          etape: Database["public"]["Enums"]["livsuivi_statut"]
          id: string
          livraison_id: string
          meta: Json
          user_id: string | null
          user_nom: string | null
        }
        Insert: {
          commentaire?: string | null
          created_at?: string
          etape: Database["public"]["Enums"]["livsuivi_statut"]
          id?: string
          livraison_id: string
          meta?: Json
          user_id?: string | null
          user_nom?: string | null
        }
        Update: {
          commentaire?: string | null
          created_at?: string
          etape?: Database["public"]["Enums"]["livsuivi_statut"]
          id?: string
          livraison_id?: string
          meta?: Json
          user_id?: string | null
          user_nom?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "livsuivi_historique_livraison_id_fkey"
            columns: ["livraison_id"]
            isOneToOne: false
            referencedRelation: "livsuivi_commandes"
            referencedColumns: ["id"]
          },
        ]
      }
      login_history: {
        Row: {
          device: string | null
          email: string | null
          id: string
          ip_address: string | null
          nom_complet: string | null
          occurred_at: string
          role: string | null
          status: string
          user_agent: string | null
          user_id: string | null
        }
        Insert: {
          device?: string | null
          email?: string | null
          id?: string
          ip_address?: string | null
          nom_complet?: string | null
          occurred_at?: string
          role?: string | null
          status?: string
          user_agent?: string | null
          user_id?: string | null
        }
        Update: {
          device?: string | null
          email?: string | null
          id?: string
          ip_address?: string | null
          nom_complet?: string | null
          occurred_at?: string
          role?: string | null
          status?: string
          user_agent?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      mfa_backup_codes: {
        Row: {
          code_hash: string
          created_at: string
          id: string
          used_at: string | null
          user_id: string
        }
        Insert: {
          code_hash: string
          created_at?: string
          id?: string
          used_at?: string | null
          user_id: string
        }
        Update: {
          code_hash?: string
          created_at?: string
          id?: string
          used_at?: string | null
          user_id?: string
        }
        Relationships: []
      }
      mfa_otp_attempts: {
        Row: {
          fail_count: number
          last_fail_at: string | null
          locked_until: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          fail_count?: number
          last_fail_at?: string | null
          locked_until?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          fail_count?: number
          last_fail_at?: string | null
          locked_until?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      mfa_session_validations: {
        Row: {
          expires_at: string
          id: string
          ip_address: string | null
          revoked_at: string | null
          session_token: string
          user_agent: string | null
          user_id: string
          validated_at: string
        }
        Insert: {
          expires_at?: string
          id?: string
          ip_address?: string | null
          revoked_at?: string | null
          session_token: string
          user_agent?: string | null
          user_id: string
          validated_at?: string
        }
        Update: {
          expires_at?: string
          id?: string
          ip_address?: string | null
          revoked_at?: string | null
          session_token?: string
          user_agent?: string | null
          user_id?: string
          validated_at?: string
        }
        Relationships: []
      }
      missions: {
        Row: {
          budget: number
          created_at: string
          date_debut: string
          date_fin: string | null
          destination: string | null
          employe_id: string | null
          employe_nom: string | null
          mission_id: string
          objet: string | null
          reference: string
          statut: string
          updated_at: string
        }
        Insert: {
          budget?: number
          created_at?: string
          date_debut?: string
          date_fin?: string | null
          destination?: string | null
          employe_id?: string | null
          employe_nom?: string | null
          mission_id?: string
          objet?: string | null
          reference?: string
          statut?: string
          updated_at?: string
        }
        Update: {
          budget?: number
          created_at?: string
          date_debut?: string
          date_fin?: string | null
          destination?: string | null
          employe_id?: string | null
          employe_nom?: string | null
          mission_id?: string
          objet?: string | null
          reference?: string
          statut?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "missions_employe_id_fkey"
            columns: ["employe_id"]
            isOneToOne: false
            referencedRelation: "employes"
            referencedColumns: ["employe_id"]
          },
        ]
      }
      notifications: {
        Row: {
          created_at: string
          date_notification: string
          lu: boolean
          message: string | null
          notification_id: string
          read_at: string | null
          titre: string
          type_notification: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          date_notification?: string
          lu?: boolean
          message?: string | null
          notification_id?: string
          read_at?: string | null
          titre: string
          type_notification?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          date_notification?: string
          lu?: boolean
          message?: string | null
          notification_id?: string
          read_at?: string | null
          titre?: string
          type_notification?: string
          updated_at?: string
        }
        Relationships: []
      }
      notifications_purge_log: {
        Row: {
          deleted_read: number
          deleted_unread: number
          error: string | null
          executed_at: string
          purge_id: string
          remaining: number
        }
        Insert: {
          deleted_read?: number
          deleted_unread?: number
          error?: string | null
          executed_at?: string
          purge_id?: string
          remaining?: number
        }
        Update: {
          deleted_read?: number
          deleted_unread?: number
          error?: string | null
          executed_at?: string
          purge_id?: string
          remaining?: number
        }
        Relationships: []
      }
      numerotation_compteurs: {
        Row: {
          annee: number
          dernier_numero: number
          type_doc: string
          updated_at: string
        }
        Insert: {
          annee: number
          dernier_numero?: number
          type_doc: string
          updated_at?: string
        }
        Update: {
          annee?: number
          dernier_numero?: number
          type_doc?: string
          updated_at?: string
        }
        Relationships: []
      }
      ordres_colisage: {
        Row: {
          commande_id: string | null
          created_at: string
          dimensions: string | null
          nb_colis: number
          notes: string | null
          ordre_id: string
          poids_total: number
          reference: string
          statut: string
          updated_at: string
        }
        Insert: {
          commande_id?: string | null
          created_at?: string
          dimensions?: string | null
          nb_colis?: number
          notes?: string | null
          ordre_id?: string
          poids_total?: number
          reference?: string
          statut?: string
          updated_at?: string
        }
        Update: {
          commande_id?: string | null
          created_at?: string
          dimensions?: string | null
          nb_colis?: number
          notes?: string | null
          ordre_id?: string
          poids_total?: number
          reference?: string
          statut?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "ordres_colisage_commande_id_fkey"
            columns: ["commande_id"]
            isOneToOne: false
            referencedRelation: "commandes"
            referencedColumns: ["commande_id"]
          },
          {
            foreignKeyName: "ordres_colisage_commande_id_fkey"
            columns: ["commande_id"]
            isOneToOne: false
            referencedRelation: "v_client_achats"
            referencedColumns: ["commande_id"]
          },
        ]
      }
      paie_parametres: {
        Row: {
          actif: boolean
          categorie: string
          code: string
          created_at: string
          description: string | null
          libelle: string
          parametre_id: string
          unite: string
          updated_at: string
          valeur: number
        }
        Insert: {
          actif?: boolean
          categorie?: string
          code: string
          created_at?: string
          description?: string | null
          libelle: string
          parametre_id?: string
          unite?: string
          updated_at?: string
          valeur?: number
        }
        Update: {
          actif?: boolean
          categorie?: string
          code?: string
          created_at?: string
          description?: string | null
          libelle?: string
          parametre_id?: string
          unite?: string
          updated_at?: string
          valeur?: number
        }
        Relationships: []
      }
      paie_rubriques: {
        Row: {
          actif: boolean
          base: string
          code: string
          created_at: string
          description: string | null
          libelle: string
          mode_calcul: string
          montant_fixe: number
          ordre: number
          rubrique_id: string
          soumis_cnps: boolean
          soumis_igr: boolean
          soumis_its: boolean
          taux: number
          type: string
          updated_at: string
        }
        Insert: {
          actif?: boolean
          base?: string
          code: string
          created_at?: string
          description?: string | null
          libelle: string
          mode_calcul?: string
          montant_fixe?: number
          ordre?: number
          rubrique_id?: string
          soumis_cnps?: boolean
          soumis_igr?: boolean
          soumis_its?: boolean
          taux?: number
          type?: string
          updated_at?: string
        }
        Update: {
          actif?: boolean
          base?: string
          code?: string
          created_at?: string
          description?: string | null
          libelle?: string
          mode_calcul?: string
          montant_fixe?: number
          ordre?: number
          rubrique_id?: string
          soumis_cnps?: boolean
          soumis_igr?: boolean
          soumis_its?: boolean
          taux?: number
          type?: string
          updated_at?: string
        }
        Relationships: []
      }
      paiement_annulations_audit: {
        Row: {
          annule_le: string
          annule_par: string | null
          created_at: string
          facture_id: string | null
          id: string
          montant_annule: number
          notes: string | null
          paiement_id: string
          raison: string
        }
        Insert: {
          annule_le?: string
          annule_par?: string | null
          created_at?: string
          facture_id?: string | null
          id?: string
          montant_annule?: number
          notes?: string | null
          paiement_id: string
          raison: string
        }
        Update: {
          annule_le?: string
          annule_par?: string | null
          created_at?: string
          facture_id?: string | null
          id?: string
          montant_annule?: number
          notes?: string | null
          paiement_id?: string
          raison?: string
        }
        Relationships: [
          {
            foreignKeyName: "paiement_annulations_audit_facture_id_fkey"
            columns: ["facture_id"]
            isOneToOne: false
            referencedRelation: "factures"
            referencedColumns: ["facture_id"]
          },
          {
            foreignKeyName: "paiement_annulations_audit_paiement_id_fkey"
            columns: ["paiement_id"]
            isOneToOne: false
            referencedRelation: "paiements"
            referencedColumns: ["paiement_id"]
          },
        ]
      }
      paiements: {
        Row: {
          client_nom: string | null
          commentaire_validation: string | null
          created_at: string
          cree_par: string | null
          date_paiement: string
          exercice_id: string
          facture_id: string | null
          mode_paiement: string
          montant: number
          motif_rejet: string | null
          notes: string | null
          paiement_id: string
          reference: string
          rejete_le: string | null
          rejete_par: string | null
          statut: string
          updated_at: string
          valide_le: string | null
          valide_par: string | null
        }
        Insert: {
          client_nom?: string | null
          commentaire_validation?: string | null
          created_at?: string
          cree_par?: string | null
          date_paiement?: string
          exercice_id?: string
          facture_id?: string | null
          mode_paiement?: string
          montant?: number
          motif_rejet?: string | null
          notes?: string | null
          paiement_id?: string
          reference?: string
          rejete_le?: string | null
          rejete_par?: string | null
          statut?: string
          updated_at?: string
          valide_le?: string | null
          valide_par?: string | null
        }
        Update: {
          client_nom?: string | null
          commentaire_validation?: string | null
          created_at?: string
          cree_par?: string | null
          date_paiement?: string
          exercice_id?: string
          facture_id?: string | null
          mode_paiement?: string
          montant?: number
          motif_rejet?: string | null
          notes?: string | null
          paiement_id?: string
          reference?: string
          rejete_le?: string | null
          rejete_par?: string | null
          statut?: string
          updated_at?: string
          valide_le?: string | null
          valide_par?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "paiements_exercice_id_fkey"
            columns: ["exercice_id"]
            isOneToOne: false
            referencedRelation: "exercices"
            referencedColumns: ["exercice_id"]
          },
          {
            foreignKeyName: "paiements_facture_id_fkey"
            columns: ["facture_id"]
            isOneToOne: false
            referencedRelation: "factures"
            referencedColumns: ["facture_id"]
          },
        ]
      }
      parametres: {
        Row: {
          cle: string
          created_at: string
          description: string | null
          parametre_id: string
          updated_at: string
          valeur: string | null
        }
        Insert: {
          cle: string
          created_at?: string
          description?: string | null
          parametre_id?: string
          updated_at?: string
          valeur?: string | null
        }
        Update: {
          cle?: string
          created_at?: string
          description?: string | null
          parametre_id?: string
          updated_at?: string
          valeur?: string | null
        }
        Relationships: []
      }
      perf_query_log: {
        Row: {
          created_at: string
          duration_ms: number
          error: string | null
          id: string
          metadata: Json | null
          query_name: string
          row_count: number | null
          user_id: string | null
        }
        Insert: {
          created_at?: string
          duration_ms: number
          error?: string | null
          id?: string
          metadata?: Json | null
          query_name: string
          row_count?: number | null
          user_id?: string | null
        }
        Update: {
          created_at?: string
          duration_ms?: number
          error?: string | null
          id?: string
          metadata?: Json | null
          query_name?: string
          row_count?: number | null
          user_id?: string | null
        }
        Relationships: []
      }
      preparateurs_colisage: {
        Row: {
          actif: boolean
          created_at: string
          created_by: string | null
          depot_id: string | null
          nom: string
          observations: string | null
          poste: string | null
          preparateur_id: string
          telephone: string | null
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          actif?: boolean
          created_at?: string
          created_by?: string | null
          depot_id?: string | null
          nom: string
          observations?: string | null
          poste?: string | null
          preparateur_id?: string
          telephone?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          actif?: boolean
          created_at?: string
          created_by?: string | null
          depot_id?: string | null
          nom?: string
          observations?: string | null
          poste?: string | null
          preparateur_id?: string
          telephone?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "preparateurs_colisage_depot_id_fkey"
            columns: ["depot_id"]
            isOneToOne: false
            referencedRelation: "depots"
            referencedColumns: ["depot_id"]
          },
        ]
      }
      produits: {
        Row: {
          actif: boolean
          auteur: string | null
          categorie: string
          categorie_id: string | null
          cover_path: string | null
          cover_thumb_path: string | null
          cover_updated_at: string | null
          created_at: string
          editeur: string | null
          isbn: string | null
          matiere: string | null
          niveau: string | null
          niveau_ordre: number | null
          pin_order: number | null
          prix_achat: number
          prix_vente: number
          produit_id: string
          reference: string
          seuil_alerte: number
          titre: string
          updated_at: string
        }
        Insert: {
          actif?: boolean
          auteur?: string | null
          categorie?: string
          categorie_id?: string | null
          cover_path?: string | null
          cover_thumb_path?: string | null
          cover_updated_at?: string | null
          created_at?: string
          editeur?: string | null
          isbn?: string | null
          matiere?: string | null
          niveau?: string | null
          niveau_ordre?: number | null
          pin_order?: number | null
          prix_achat?: number
          prix_vente?: number
          produit_id?: string
          reference?: string
          seuil_alerte?: number
          titre: string
          updated_at?: string
        }
        Update: {
          actif?: boolean
          auteur?: string | null
          categorie?: string
          categorie_id?: string | null
          cover_path?: string | null
          cover_thumb_path?: string | null
          cover_updated_at?: string | null
          created_at?: string
          editeur?: string | null
          isbn?: string | null
          matiere?: string | null
          niveau?: string | null
          niveau_ordre?: number | null
          pin_order?: number | null
          prix_achat?: number
          prix_vente?: number
          produit_id?: string
          reference?: string
          seuil_alerte?: number
          titre?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "produits_categorie_id_fkey"
            columns: ["categorie_id"]
            isOneToOne: false
            referencedRelation: "categories_produits"
            referencedColumns: ["categorie_id"]
          },
        ]
      }
      profiles: {
        Row: {
          actif: boolean
          avatar_url: string | null
          created_at: string
          departement: string | null
          email: string | null
          fonction: string | null
          id: string
          is_restricted: boolean
          mfa_enrolled_at: string | null
          mfa_required: boolean
          nom_complet: string | null
          prenom: string | null
          telephone: string | null
          updated_at: string
        }
        Insert: {
          actif?: boolean
          avatar_url?: string | null
          created_at?: string
          departement?: string | null
          email?: string | null
          fonction?: string | null
          id: string
          is_restricted?: boolean
          mfa_enrolled_at?: string | null
          mfa_required?: boolean
          nom_complet?: string | null
          prenom?: string | null
          telephone?: string | null
          updated_at?: string
        }
        Update: {
          actif?: boolean
          avatar_url?: string | null
          created_at?: string
          departement?: string | null
          email?: string | null
          fonction?: string | null
          id?: string
          is_restricted?: boolean
          mfa_enrolled_at?: string | null
          mfa_required?: boolean
          nom_complet?: string | null
          prenom?: string | null
          telephone?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      proforma_lignes: {
        Row: {
          created_at: string
          designation: string
          ligne_id: string
          prix_unitaire: number
          produit_id: string | null
          proforma_id: string
          quantite: number
          total_ligne: number
        }
        Insert: {
          created_at?: string
          designation: string
          ligne_id?: string
          prix_unitaire?: number
          produit_id?: string | null
          proforma_id: string
          quantite?: number
          total_ligne?: number
        }
        Update: {
          created_at?: string
          designation?: string
          ligne_id?: string
          prix_unitaire?: number
          produit_id?: string | null
          proforma_id?: string
          quantite?: number
          total_ligne?: number
        }
        Relationships: [
          {
            foreignKeyName: "proforma_lignes_proforma_id_fkey"
            columns: ["proforma_id"]
            isOneToOne: false
            referencedRelation: "proformas"
            referencedColumns: ["proforma_id"]
          },
        ]
      }
      proformas: {
        Row: {
          client_id: string | null
          client_nom: string | null
          commande_id: string | null
          created_at: string
          date_proforma: string
          date_validite: string | null
          exercice_id: string
          montant_total: number
          notes: string | null
          proforma_id: string
          reference: string
          statut: string
          updated_at: string
        }
        Insert: {
          client_id?: string | null
          client_nom?: string | null
          commande_id?: string | null
          created_at?: string
          date_proforma?: string
          date_validite?: string | null
          exercice_id?: string
          montant_total?: number
          notes?: string | null
          proforma_id?: string
          reference?: string
          statut?: string
          updated_at?: string
        }
        Update: {
          client_id?: string | null
          client_nom?: string | null
          commande_id?: string | null
          created_at?: string
          date_proforma?: string
          date_validite?: string | null
          exercice_id?: string
          montant_total?: number
          notes?: string | null
          proforma_id?: string
          reference?: string
          statut?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "proformas_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "proformas_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "v_client_achats"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "proformas_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "v_client_stats"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "proformas_commande_id_fkey"
            columns: ["commande_id"]
            isOneToOne: false
            referencedRelation: "commandes"
            referencedColumns: ["commande_id"]
          },
          {
            foreignKeyName: "proformas_commande_id_fkey"
            columns: ["commande_id"]
            isOneToOne: false
            referencedRelation: "v_client_achats"
            referencedColumns: ["commande_id"]
          },
          {
            foreignKeyName: "proformas_exercice_id_fkey"
            columns: ["exercice_id"]
            isOneToOne: false
            referencedRelation: "exercices"
            referencedColumns: ["exercice_id"]
          },
        ]
      }
      rbac_audit_log: {
        Row: {
          action: string
          apres: Json | null
          avant: Json | null
          created_at: string
          details: Json
          id: string
          ip: string | null
          role_code: string | null
          role_id: string | null
          user_agent: string | null
          user_email: string | null
          user_id: string | null
        }
        Insert: {
          action: string
          apres?: Json | null
          avant?: Json | null
          created_at?: string
          details?: Json
          id?: string
          ip?: string | null
          role_code?: string | null
          role_id?: string | null
          user_agent?: string | null
          user_email?: string | null
          user_id?: string | null
        }
        Update: {
          action?: string
          apres?: Json | null
          avant?: Json | null
          created_at?: string
          details?: Json
          id?: string
          ip?: string | null
          role_code?: string | null
          role_id?: string | null
          user_agent?: string | null
          user_email?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      rbac_permissions: {
        Row: {
          action: string
          code: string
          created_at: string
          description: string | null
          libelle: string
          module: string
          sous_module: string | null
        }
        Insert: {
          action: string
          code: string
          created_at?: string
          description?: string | null
          libelle: string
          module: string
          sous_module?: string | null
        }
        Update: {
          action?: string
          code?: string
          created_at?: string
          description?: string | null
          libelle?: string
          module?: string
          sous_module?: string | null
        }
        Relationships: []
      }
      rbac_role_permissions: {
        Row: {
          accorde: boolean
          created_at: string
          permission_code: string
          role_id: string
        }
        Insert: {
          accorde?: boolean
          created_at?: string
          permission_code: string
          role_id: string
        }
        Update: {
          accorde?: boolean
          created_at?: string
          permission_code?: string
          role_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "rbac_role_permissions_permission_code_fkey"
            columns: ["permission_code"]
            isOneToOne: false
            referencedRelation: "rbac_permissions"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "rbac_role_permissions_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "rbac_roles"
            referencedColumns: ["role_id"]
          },
        ]
      }
      rbac_roles: {
        Row: {
          actif: boolean
          code: string
          created_at: string
          description: string | null
          hierite_de: string | null
          libelle: string
          role_id: string
          systeme: boolean
          updated_at: string
        }
        Insert: {
          actif?: boolean
          code: string
          created_at?: string
          description?: string | null
          hierite_de?: string | null
          libelle: string
          role_id?: string
          systeme?: boolean
          updated_at?: string
        }
        Update: {
          actif?: boolean
          code?: string
          created_at?: string
          description?: string | null
          hierite_de?: string | null
          libelle?: string
          role_id?: string
          systeme?: boolean
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "rbac_roles_hierite_de_fkey"
            columns: ["hierite_de"]
            isOneToOne: false
            referencedRelation: "rbac_roles"
            referencedColumns: ["role_id"]
          },
        ]
      }
      rbac_user_roles: {
        Row: {
          assigned_at: string
          assigned_by: string | null
          role_id: string
          user_id: string
        }
        Insert: {
          assigned_at?: string
          assigned_by?: string | null
          role_id: string
          user_id: string
        }
        Update: {
          assigned_at?: string
          assigned_by?: string | null
          role_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "rbac_user_roles_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "rbac_roles"
            referencedColumns: ["role_id"]
          },
        ]
      }
      retour_lignes: {
        Row: {
          created_at: string
          designation: string
          ligne_id: string
          motif: string | null
          produit_id: string | null
          quantite: number
          reference_produit: string | null
          retour_id: string
        }
        Insert: {
          created_at?: string
          designation: string
          ligne_id?: string
          motif?: string | null
          produit_id?: string | null
          quantite: number
          reference_produit?: string | null
          retour_id: string
        }
        Update: {
          created_at?: string
          designation?: string
          ligne_id?: string
          motif?: string | null
          produit_id?: string | null
          quantite?: number
          reference_produit?: string | null
          retour_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "retour_lignes_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "produits"
            referencedColumns: ["produit_id"]
          },
          {
            foreignKeyName: "retour_lignes_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "v_produits"
            referencedColumns: ["produit_id"]
          },
          {
            foreignKeyName: "retour_lignes_retour_id_fkey"
            columns: ["retour_id"]
            isOneToOne: false
            referencedRelation: "retours"
            referencedColumns: ["retour_id"]
          },
        ]
      }
      retours: {
        Row: {
          adresse: string | null
          client_id: string | null
          client_nom: string | null
          commande_id: string | null
          created_at: string
          created_by: string | null
          created_by_nom: string | null
          date_retour: string
          depot_id: string | null
          etablissement: string | null
          exercice_id: string
          facture_id: string | null
          livraison_id: string | null
          montant: number | null
          motif: string | null
          nb_produits: number
          notes: string | null
          numero: string | null
          observations: string | null
          produit_nom: string | null
          quantite: number | null
          reference: string
          representant_nom: string | null
          retour_id: string
          statut: string
          telephone: string | null
          total_quantite: number
          updated_at: string
          ville: string | null
        }
        Insert: {
          adresse?: string | null
          client_id?: string | null
          client_nom?: string | null
          commande_id?: string | null
          created_at?: string
          created_by?: string | null
          created_by_nom?: string | null
          date_retour?: string
          depot_id?: string | null
          etablissement?: string | null
          exercice_id?: string
          facture_id?: string | null
          livraison_id?: string | null
          montant?: number | null
          motif?: string | null
          nb_produits?: number
          notes?: string | null
          numero?: string | null
          observations?: string | null
          produit_nom?: string | null
          quantite?: number | null
          reference?: string
          representant_nom?: string | null
          retour_id?: string
          statut?: string
          telephone?: string | null
          total_quantite?: number
          updated_at?: string
          ville?: string | null
        }
        Update: {
          adresse?: string | null
          client_id?: string | null
          client_nom?: string | null
          commande_id?: string | null
          created_at?: string
          created_by?: string | null
          created_by_nom?: string | null
          date_retour?: string
          depot_id?: string | null
          etablissement?: string | null
          exercice_id?: string
          facture_id?: string | null
          livraison_id?: string | null
          montant?: number | null
          motif?: string | null
          nb_produits?: number
          notes?: string | null
          numero?: string | null
          observations?: string | null
          produit_nom?: string | null
          quantite?: number | null
          reference?: string
          representant_nom?: string | null
          retour_id?: string
          statut?: string
          telephone?: string | null
          total_quantite?: number
          updated_at?: string
          ville?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "retours_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "retours_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "v_client_achats"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "retours_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "v_client_stats"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "retours_commande_id_fkey"
            columns: ["commande_id"]
            isOneToOne: false
            referencedRelation: "commandes"
            referencedColumns: ["commande_id"]
          },
          {
            foreignKeyName: "retours_commande_id_fkey"
            columns: ["commande_id"]
            isOneToOne: false
            referencedRelation: "v_client_achats"
            referencedColumns: ["commande_id"]
          },
          {
            foreignKeyName: "retours_depot_id_fkey"
            columns: ["depot_id"]
            isOneToOne: false
            referencedRelation: "depots"
            referencedColumns: ["depot_id"]
          },
          {
            foreignKeyName: "retours_exercice_id_fkey"
            columns: ["exercice_id"]
            isOneToOne: false
            referencedRelation: "exercices"
            referencedColumns: ["exercice_id"]
          },
          {
            foreignKeyName: "retours_facture_id_fkey"
            columns: ["facture_id"]
            isOneToOne: false
            referencedRelation: "factures"
            referencedColumns: ["facture_id"]
          },
          {
            foreignKeyName: "retours_livraison_id_fkey"
            columns: ["livraison_id"]
            isOneToOne: false
            referencedRelation: "livraisons"
            referencedColumns: ["livraison_id"]
          },
        ]
      }
      security_alerts: {
        Row: {
          acknowledged_at: string | null
          acknowledged_by: string | null
          alert_type: string
          city: string | null
          country: string | null
          created_at: string
          criticite: Database["public"]["Enums"]["audit_criticite"]
          detail: Json | null
          id: string
          ip_address: unknown
          message: string
          user_email: string | null
          user_id: string | null
        }
        Insert: {
          acknowledged_at?: string | null
          acknowledged_by?: string | null
          alert_type: string
          city?: string | null
          country?: string | null
          created_at?: string
          criticite?: Database["public"]["Enums"]["audit_criticite"]
          detail?: Json | null
          id?: string
          ip_address?: unknown
          message: string
          user_email?: string | null
          user_id?: string | null
        }
        Update: {
          acknowledged_at?: string | null
          acknowledged_by?: string | null
          alert_type?: string
          city?: string | null
          country?: string | null
          created_at?: string
          criticite?: Database["public"]["Enums"]["audit_criticite"]
          detail?: Json | null
          id?: string
          ip_address?: unknown
          message?: string
          user_email?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      soldes_ouverture_clients: {
        Row: {
          client_id: string
          commentaire: string | null
          created_at: string
          created_by: string | null
          exercice_id: string
          exercice_origine_id: string | null
          montant: number
          solde_id: string
        }
        Insert: {
          client_id: string
          commentaire?: string | null
          created_at?: string
          created_by?: string | null
          exercice_id: string
          exercice_origine_id?: string | null
          montant: number
          solde_id?: string
        }
        Update: {
          client_id?: string
          commentaire?: string | null
          created_at?: string
          created_by?: string | null
          exercice_id?: string
          exercice_origine_id?: string | null
          montant?: number
          solde_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "soldes_ouverture_clients_exercice_id_fkey"
            columns: ["exercice_id"]
            isOneToOne: false
            referencedRelation: "exercices"
            referencedColumns: ["exercice_id"]
          },
          {
            foreignKeyName: "soldes_ouverture_clients_exercice_origine_id_fkey"
            columns: ["exercice_origine_id"]
            isOneToOne: false
            referencedRelation: "exercices"
            referencedColumns: ["exercice_id"]
          },
        ]
      }
      soldes_ouverture_fournisseurs: {
        Row: {
          commentaire: string | null
          created_at: string
          created_by: string | null
          exercice_id: string
          exercice_origine_id: string | null
          fournisseur_id: string
          montant: number
          solde_id: string
        }
        Insert: {
          commentaire?: string | null
          created_at?: string
          created_by?: string | null
          exercice_id: string
          exercice_origine_id?: string | null
          fournisseur_id: string
          montant: number
          solde_id?: string
        }
        Update: {
          commentaire?: string | null
          created_at?: string
          created_by?: string | null
          exercice_id?: string
          exercice_origine_id?: string | null
          fournisseur_id?: string
          montant?: number
          solde_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "soldes_ouverture_fournisseurs_exercice_id_fkey"
            columns: ["exercice_id"]
            isOneToOne: false
            referencedRelation: "exercices"
            referencedColumns: ["exercice_id"]
          },
          {
            foreignKeyName: "soldes_ouverture_fournisseurs_exercice_origine_id_fkey"
            columns: ["exercice_origine_id"]
            isOneToOne: false
            referencedRelation: "exercices"
            referencedColumns: ["exercice_id"]
          },
        ]
      }
      specimen_lignes: {
        Row: {
          created_at: string
          designation: string
          ligne_id: string
          produit_id: string | null
          quantite: number
          reference_produit: string | null
          specimen_id: string
        }
        Insert: {
          created_at?: string
          designation: string
          ligne_id?: string
          produit_id?: string | null
          quantite: number
          reference_produit?: string | null
          specimen_id: string
        }
        Update: {
          created_at?: string
          designation?: string
          ligne_id?: string
          produit_id?: string | null
          quantite?: number
          reference_produit?: string | null
          specimen_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "specimen_lignes_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "produits"
            referencedColumns: ["produit_id"]
          },
          {
            foreignKeyName: "specimen_lignes_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "v_produits"
            referencedColumns: ["produit_id"]
          },
          {
            foreignKeyName: "specimen_lignes_specimen_id_fkey"
            columns: ["specimen_id"]
            isOneToOne: false
            referencedRelation: "specimens"
            referencedColumns: ["specimen_id"]
          },
        ]
      }
      specimens: {
        Row: {
          adresse: string | null
          client_id: string | null
          created_at: string
          created_by: string | null
          date_envoi: string
          donneur_nom: string
          etablissement: string
          gestionnaire_id: string | null
          gestionnaire_nom: string | null
          motif: string | null
          nb_produits: number
          numero: string
          observations: string | null
          representant_nom: string | null
          specimen_id: string
          statut: string
          telephone: string | null
          total_quantite: number
          updated_at: string
          ville: string | null
        }
        Insert: {
          adresse?: string | null
          client_id?: string | null
          created_at?: string
          created_by?: string | null
          date_envoi?: string
          donneur_nom: string
          etablissement: string
          gestionnaire_id?: string | null
          gestionnaire_nom?: string | null
          motif?: string | null
          nb_produits?: number
          numero: string
          observations?: string | null
          representant_nom?: string | null
          specimen_id?: string
          statut?: string
          telephone?: string | null
          total_quantite?: number
          updated_at?: string
          ville?: string | null
        }
        Update: {
          adresse?: string | null
          client_id?: string | null
          created_at?: string
          created_by?: string | null
          date_envoi?: string
          donneur_nom?: string
          etablissement?: string
          gestionnaire_id?: string | null
          gestionnaire_nom?: string | null
          motif?: string | null
          nb_produits?: number
          numero?: string
          observations?: string | null
          representant_nom?: string | null
          specimen_id?: string
          statut?: string
          telephone?: string | null
          total_quantite?: number
          updated_at?: string
          ville?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "specimens_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "specimens_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "v_client_achats"
            referencedColumns: ["client_id"]
          },
          {
            foreignKeyName: "specimens_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "v_client_stats"
            referencedColumns: ["client_id"]
          },
        ]
      }
      stock_corrections_audit: {
        Row: {
          correction_id: string
          corrige_par: string | null
          corrige_par_nom: string | null
          created_at: string
          ecart: number
          motif: string | null
          nb_mouvements: number
          produit_id: string
          stock_apres: number
          stock_avant: number
        }
        Insert: {
          correction_id?: string
          corrige_par?: string | null
          corrige_par_nom?: string | null
          created_at?: string
          ecart: number
          motif?: string | null
          nb_mouvements: number
          produit_id: string
          stock_apres: number
          stock_avant: number
        }
        Update: {
          correction_id?: string
          corrige_par?: string | null
          corrige_par_nom?: string | null
          created_at?: string
          ecart?: number
          motif?: string | null
          nb_mouvements?: number
          produit_id?: string
          stock_apres?: number
          stock_avant?: number
        }
        Relationships: [
          {
            foreignKeyName: "stock_corrections_audit_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "produits"
            referencedColumns: ["produit_id"]
          },
          {
            foreignKeyName: "stock_corrections_audit_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "v_produits"
            referencedColumns: ["produit_id"]
          },
        ]
      }
      stock_mouvements: {
        Row: {
          created_at: string
          depot_id: string | null
          document_id: string | null
          document_reference: string | null
          document_table: string | null
          exercice_id: string
          motif: string | null
          mouvement_id: string
          observation: string | null
          origine: string | null
          produit_id: string
          quantite: number
          quantite_entree: number | null
          quantite_sortie: number | null
          stock_resultant: number
          type: string
          user_id: string | null
          user_nom: string | null
        }
        Insert: {
          created_at?: string
          depot_id?: string | null
          document_id?: string | null
          document_reference?: string | null
          document_table?: string | null
          exercice_id?: string
          motif?: string | null
          mouvement_id?: string
          observation?: string | null
          origine?: string | null
          produit_id: string
          quantite?: number
          quantite_entree?: number | null
          quantite_sortie?: number | null
          stock_resultant?: number
          type?: string
          user_id?: string | null
          user_nom?: string | null
        }
        Update: {
          created_at?: string
          depot_id?: string | null
          document_id?: string | null
          document_reference?: string | null
          document_table?: string | null
          exercice_id?: string
          motif?: string | null
          mouvement_id?: string
          observation?: string | null
          origine?: string | null
          produit_id?: string
          quantite?: number
          quantite_entree?: number | null
          quantite_sortie?: number | null
          stock_resultant?: number
          type?: string
          user_id?: string | null
          user_nom?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "stock_mouvements_depot_id_fkey"
            columns: ["depot_id"]
            isOneToOne: false
            referencedRelation: "depots"
            referencedColumns: ["depot_id"]
          },
          {
            foreignKeyName: "stock_mouvements_exercice_id_fkey"
            columns: ["exercice_id"]
            isOneToOne: false
            referencedRelation: "exercices"
            referencedColumns: ["exercice_id"]
          },
          {
            foreignKeyName: "stock_mouvements_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "produits"
            referencedColumns: ["produit_id"]
          },
          {
            foreignKeyName: "stock_mouvements_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "v_produits"
            referencedColumns: ["produit_id"]
          },
        ]
      }
      stocks_depots: {
        Row: {
          depot_id: string
          id: string
          produit_id: string
          quantite: number
          seuil_alerte: number
          updated_at: string
        }
        Insert: {
          depot_id: string
          id?: string
          produit_id: string
          quantite?: number
          seuil_alerte?: number
          updated_at?: string
        }
        Update: {
          depot_id?: string
          id?: string
          produit_id?: string
          quantite?: number
          seuil_alerte?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "stocks_depots_depot_id_fkey"
            columns: ["depot_id"]
            isOneToOne: false
            referencedRelation: "depots"
            referencedColumns: ["depot_id"]
          },
          {
            foreignKeyName: "stocks_depots_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "produits"
            referencedColumns: ["produit_id"]
          },
          {
            foreignKeyName: "stocks_depots_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "v_produits"
            referencedColumns: ["produit_id"]
          },
        ]
      }
      tournees: {
        Row: {
          chauffeur_nom: string | null
          cloture_at: string | null
          cloture_by: string | null
          cloture_mode: string | null
          cout_autres: number
          cout_carburant: number
          cout_expeditions: number
          cout_livraison: number
          cout_manutentions: number
          cout_peages: number
          cout_repas: number
          cout_total: number | null
          created_at: string
          created_by: string | null
          date_tournee: string
          depot_depart_id: string | null
          ecriture_id: string | null
          heure_depart: string | null
          mode_reglement: string | null
          nb_cartons: number
          nb_clients: number
          nb_colis: number
          notes: string | null
          reference: string
          responsable_nom: string | null
          statut: string
          tournee_id: string
          type_tournee: string
          updated_at: string
          updated_by: string | null
          validation_at: string | null
          validation_by: string | null
          validation_commentaire: string | null
          validation_statut: string
          vehicule_id: string | null
        }
        Insert: {
          chauffeur_nom?: string | null
          cloture_at?: string | null
          cloture_by?: string | null
          cloture_mode?: string | null
          cout_autres?: number
          cout_carburant?: number
          cout_expeditions?: number
          cout_livraison?: number
          cout_manutentions?: number
          cout_peages?: number
          cout_repas?: number
          cout_total?: number | null
          created_at?: string
          created_by?: string | null
          date_tournee?: string
          depot_depart_id?: string | null
          ecriture_id?: string | null
          heure_depart?: string | null
          mode_reglement?: string | null
          nb_cartons?: number
          nb_clients?: number
          nb_colis?: number
          notes?: string | null
          reference: string
          responsable_nom?: string | null
          statut?: string
          tournee_id?: string
          type_tournee?: string
          updated_at?: string
          updated_by?: string | null
          validation_at?: string | null
          validation_by?: string | null
          validation_commentaire?: string | null
          validation_statut?: string
          vehicule_id?: string | null
        }
        Update: {
          chauffeur_nom?: string | null
          cloture_at?: string | null
          cloture_by?: string | null
          cloture_mode?: string | null
          cout_autres?: number
          cout_carburant?: number
          cout_expeditions?: number
          cout_livraison?: number
          cout_manutentions?: number
          cout_peages?: number
          cout_repas?: number
          cout_total?: number | null
          created_at?: string
          created_by?: string | null
          date_tournee?: string
          depot_depart_id?: string | null
          ecriture_id?: string | null
          heure_depart?: string | null
          mode_reglement?: string | null
          nb_cartons?: number
          nb_clients?: number
          nb_colis?: number
          notes?: string | null
          reference?: string
          responsable_nom?: string | null
          statut?: string
          tournee_id?: string
          type_tournee?: string
          updated_at?: string
          updated_by?: string | null
          validation_at?: string | null
          validation_by?: string | null
          validation_commentaire?: string | null
          validation_statut?: string
          vehicule_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "tournees_depot_depart_id_fkey"
            columns: ["depot_depart_id"]
            isOneToOne: false
            referencedRelation: "depots"
            referencedColumns: ["depot_id"]
          },
          {
            foreignKeyName: "tournees_ecriture_id_fkey"
            columns: ["ecriture_id"]
            isOneToOne: false
            referencedRelation: "ecritures_comptables"
            referencedColumns: ["ecriture_id"]
          },
          {
            foreignKeyName: "tournees_vehicule_id_fkey"
            columns: ["vehicule_id"]
            isOneToOne: false
            referencedRelation: "vehicules"
            referencedColumns: ["vehicule_id"]
          },
        ]
      }
      transactions: {
        Row: {
          categorie: string
          commande_id: string | null
          created_at: string
          created_by: string | null
          date_transaction: string
          exercice_id: string
          libelle: string
          mode_paiement: string
          montant: number
          notes: string | null
          reference: string
          statut: string
          transaction_id: string
          type: string
          updated_at: string
        }
        Insert: {
          categorie?: string
          commande_id?: string | null
          created_at?: string
          created_by?: string | null
          date_transaction?: string
          exercice_id?: string
          libelle: string
          mode_paiement?: string
          montant?: number
          notes?: string | null
          reference?: string
          statut?: string
          transaction_id?: string
          type: string
          updated_at?: string
        }
        Update: {
          categorie?: string
          commande_id?: string | null
          created_at?: string
          created_by?: string | null
          date_transaction?: string
          exercice_id?: string
          libelle?: string
          mode_paiement?: string
          montant?: number
          notes?: string | null
          reference?: string
          statut?: string
          transaction_id?: string
          type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "transactions_commande_id_fkey"
            columns: ["commande_id"]
            isOneToOne: false
            referencedRelation: "commandes"
            referencedColumns: ["commande_id"]
          },
          {
            foreignKeyName: "transactions_commande_id_fkey"
            columns: ["commande_id"]
            isOneToOne: false
            referencedRelation: "v_client_achats"
            referencedColumns: ["commande_id"]
          },
          {
            foreignKeyName: "transactions_exercice_id_fkey"
            columns: ["exercice_id"]
            isOneToOne: false
            referencedRelation: "exercices"
            referencedColumns: ["exercice_id"]
          },
        ]
      }
      transfert_lignes: {
        Row: {
          created_at: string
          ligne_id: string
          produit_id: string
          quantite: number
          quantite_recue: number
          transfert_id: string
        }
        Insert: {
          created_at?: string
          ligne_id?: string
          produit_id: string
          quantite: number
          quantite_recue?: number
          transfert_id: string
        }
        Update: {
          created_at?: string
          ligne_id?: string
          produit_id?: string
          quantite?: number
          quantite_recue?: number
          transfert_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "transfert_lignes_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "produits"
            referencedColumns: ["produit_id"]
          },
          {
            foreignKeyName: "transfert_lignes_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "v_produits"
            referencedColumns: ["produit_id"]
          },
          {
            foreignKeyName: "transfert_lignes_transfert_id_fkey"
            columns: ["transfert_id"]
            isOneToOne: false
            referencedRelation: "transferts"
            referencedColumns: ["transfert_id"]
          },
        ]
      }
      transferts: {
        Row: {
          created_at: string
          created_by: string | null
          date_creation: string
          date_expedition: string | null
          date_reception: string | null
          depot_destination_id: string
          depot_source_id: string
          motif: string | null
          notes: string | null
          numero: string
          statut: string
          transfert_id: string
          transporteur: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          date_creation?: string
          date_expedition?: string | null
          date_reception?: string | null
          depot_destination_id: string
          depot_source_id: string
          motif?: string | null
          notes?: string | null
          numero: string
          statut?: string
          transfert_id?: string
          transporteur?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          date_creation?: string
          date_expedition?: string | null
          date_reception?: string | null
          depot_destination_id?: string
          depot_source_id?: string
          motif?: string | null
          notes?: string | null
          numero?: string
          statut?: string
          transfert_id?: string
          transporteur?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "transferts_depot_destination_id_fkey"
            columns: ["depot_destination_id"]
            isOneToOne: false
            referencedRelation: "depots"
            referencedColumns: ["depot_id"]
          },
          {
            foreignKeyName: "transferts_depot_source_id_fkey"
            columns: ["depot_source_id"]
            isOneToOne: false
            referencedRelation: "depots"
            referencedColumns: ["depot_id"]
          },
        ]
      }
      transporteurs: {
        Row: {
          actif: boolean
          contact: string | null
          created_at: string
          email: string | null
          nom: string
          notes: string | null
          telephone: string | null
          transporteur_id: string
          type: string | null
          updated_at: string
        }
        Insert: {
          actif?: boolean
          contact?: string | null
          created_at?: string
          email?: string | null
          nom: string
          notes?: string | null
          telephone?: string | null
          transporteur_id?: string
          type?: string | null
          updated_at?: string
        }
        Update: {
          actif?: boolean
          contact?: string | null
          created_at?: string
          email?: string | null
          nom?: string
          notes?: string | null
          telephone?: string | null
          transporteur_id?: string
          type?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      trigger_execution_log: {
        Row: {
          affected_rows: number | null
          chauffeur: string | null
          executed_at: string
          id: string
          immat: string | null
          message: string | null
          nb_cartons: number | null
          nb_clients: number | null
          nb_colis: number | null
          responsable: string | null
          target_date: string | null
          trigger_name: string
        }
        Insert: {
          affected_rows?: number | null
          chauffeur?: string | null
          executed_at?: string
          id?: string
          immat?: string | null
          message?: string | null
          nb_cartons?: number | null
          nb_clients?: number | null
          nb_colis?: number | null
          responsable?: string | null
          target_date?: string | null
          trigger_name: string
        }
        Update: {
          affected_rows?: number | null
          chauffeur?: string | null
          executed_at?: string
          id?: string
          immat?: string | null
          message?: string | null
          nb_cartons?: number | null
          nb_clients?: number | null
          nb_colis?: number | null
          responsable?: string | null
          target_date?: string | null
          trigger_name?: string
        }
        Relationships: []
      }
      two_fa_secrets: {
        Row: {
          active: boolean
          codes_recuperation: string[] | null
          created_at: string
          secret_chiffre: string
          updated_at: string
          user_id: string
        }
        Insert: {
          active?: boolean
          codes_recuperation?: string[] | null
          created_at?: string
          secret_chiffre: string
          updated_at?: string
          user_id: string
        }
        Update: {
          active?: boolean
          codes_recuperation?: string[] | null
          created_at?: string
          secret_chiffre?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      user_action_stats: {
        Row: {
          action_key: string
          created_at: string
          hidden: boolean
          href: string | null
          icon: string | null
          id: string
          label: string | null
          last_used_at: string | null
          module: string | null
          pinned: boolean
          sort_order: number
          updated_at: string
          usage_count: number
          user_id: string
        }
        Insert: {
          action_key: string
          created_at?: string
          hidden?: boolean
          href?: string | null
          icon?: string | null
          id?: string
          label?: string | null
          last_used_at?: string | null
          module?: string | null
          pinned?: boolean
          sort_order?: number
          updated_at?: string
          usage_count?: number
          user_id: string
        }
        Update: {
          action_key?: string
          created_at?: string
          hidden?: boolean
          href?: string | null
          icon?: string | null
          id?: string
          label?: string | null
          last_used_at?: string | null
          module?: string | null
          pinned?: boolean
          sort_order?: number
          updated_at?: string
          usage_count?: number
          user_id?: string
        }
        Relationships: []
      }
      user_roles: {
        Row: {
          id: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          id?: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
      vehicules: {
        Row: {
          created_at: string
          date_expiration_assurance: string | null
          date_expiration_visite_technique: string | null
          date_prochain_entretien: string | null
          immatriculation: string
          kilometrage: number
          marque: string | null
          modele: string | null
          notes: string | null
          statut: string
          type_vehicule: string
          updated_at: string
          vehicule_id: string
        }
        Insert: {
          created_at?: string
          date_expiration_assurance?: string | null
          date_expiration_visite_technique?: string | null
          date_prochain_entretien?: string | null
          immatriculation: string
          kilometrage?: number
          marque?: string | null
          modele?: string | null
          notes?: string | null
          statut?: string
          type_vehicule?: string
          updated_at?: string
          vehicule_id?: string
        }
        Update: {
          created_at?: string
          date_expiration_assurance?: string | null
          date_expiration_visite_technique?: string | null
          date_prochain_entretien?: string | null
          immatriculation?: string
          kilometrage?: number
          marque?: string | null
          modele?: string | null
          notes?: string | null
          statut?: string
          type_vehicule?: string
          updated_at?: string
          vehicule_id?: string
        }
        Relationships: []
      }
      workflow_approvals: {
        Row: {
          approval_id: string
          created_at: string
          date_demande: string
          demandeur: string | null
          montant: number
          notes: string | null
          objet: string | null
          reference: string
          statut: string
          type_demande: string
          updated_at: string
        }
        Insert: {
          approval_id?: string
          created_at?: string
          date_demande?: string
          demandeur?: string | null
          montant?: number
          notes?: string | null
          objet?: string | null
          reference?: string
          statut?: string
          type_demande?: string
          updated_at?: string
        }
        Update: {
          approval_id?: string
          created_at?: string
          date_demande?: string
          demandeur?: string | null
          montant?: number
          notes?: string | null
          objet?: string | null
          reference?: string
          statut?: string
          type_demande?: string
          updated_at?: string
        }
        Relationships: []
      }
      workflows_definitions: {
        Row: {
          actif: boolean
          created_at: string
          description: string | null
          entite_type: string
          etapes: Json
          nom: string
          updated_at: string
          workflow_id: string
        }
        Insert: {
          actif?: boolean
          created_at?: string
          description?: string | null
          entite_type: string
          etapes?: Json
          nom: string
          updated_at?: string
          workflow_id?: string
        }
        Update: {
          actif?: boolean
          created_at?: string
          description?: string | null
          entite_type?: string
          etapes?: Json
          nom?: string
          updated_at?: string
          workflow_id?: string
        }
        Relationships: []
      }
    }
    Views: {
      audit_events_all: {
        Row: {
          action: Database["public"]["Enums"]["audit_action"] | null
          archived: boolean | null
          browser: string | null
          changes: Json | null
          city: string | null
          country: string | null
          criticite: Database["public"]["Enums"]["audit_criticite"] | null
          device: string | null
          duration_ms: number | null
          error_message: string | null
          http_method: string | null
          id: string | null
          ip_address: unknown
          metadata: Json | null
          module: string | null
          new_values: Json | null
          occurred_at: string | null
          old_values: Json | null
          os: string | null
          record_id: string | null
          record_ref: string | null
          request_id: string | null
          seq: number | null
          session_id: string | null
          status: string | null
          table_name: string | null
          url: string | null
          user_agent: string | null
          user_email: string | null
          user_id: string | null
        }
        Relationships: []
      }
      v_client_achats: {
        Row: {
          categorie: string | null
          categorie_id: string | null
          client_id: string | null
          client_nom: string | null
          commande_id: string | null
          commande_reference: string | null
          commande_statut: string | null
          date_commande: string | null
          ligne_id: string | null
          niveau: string | null
          prix_unitaire: number | null
          produit_id: string | null
          produit_titre: string | null
          quantite: number | null
          reference_produit: string | null
          remise_pct: number | null
          representant: string | null
          total_ht_ligne: number | null
          total_ligne: number | null
          type_client: string | null
          ville: string | null
        }
        Relationships: [
          {
            foreignKeyName: "commande_lignes_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "produits"
            referencedColumns: ["produit_id"]
          },
          {
            foreignKeyName: "commande_lignes_produit_id_fkey"
            columns: ["produit_id"]
            isOneToOne: false
            referencedRelation: "v_produits"
            referencedColumns: ["produit_id"]
          },
          {
            foreignKeyName: "produits_categorie_id_fkey"
            columns: ["categorie_id"]
            isOneToOne: false
            referencedRelation: "categories_produits"
            referencedColumns: ["categorie_id"]
          },
        ]
      }
      v_client_stats: {
        Row: {
          ca_total: number | null
          client_id: string | null
          derniere_commande: string | null
          nb_commandes: number | null
          premiere_commande: string | null
          qte_totale: number | null
          ticket_moyen: number | null
          top_categorie: string | null
          top_niveau: string | null
          top_produit: string | null
        }
        Relationships: []
      }
      v_colisage_responsables: {
        Row: {
          actif: boolean | null
          created_at: string | null
          date_affectation: string | null
          depot_id: string | null
          depot_nom: string | null
          employe_id: string | null
          matricule: string | null
          nom_complet: string | null
          poste: string | null
          responsable_id: string | null
          telephone: string | null
          updated_at: string | null
        }
        Relationships: [
          {
            foreignKeyName: "colisage_responsables_depot_id_fkey"
            columns: ["depot_id"]
            isOneToOne: false
            referencedRelation: "depots"
            referencedColumns: ["depot_id"]
          },
          {
            foreignKeyName: "colisage_responsables_employe_id_fkey"
            columns: ["employe_id"]
            isOneToOne: true
            referencedRelation: "employes"
            referencedColumns: ["employe_id"]
          },
        ]
      }
      v_produits: {
        Row: {
          actif: boolean | null
          auteur: string | null
          categorie: string | null
          categorie_id: string | null
          cover_path: string | null
          cover_thumb_path: string | null
          cover_updated_at: string | null
          created_at: string | null
          editeur: string | null
          isbn: string | null
          matiere: string | null
          niveau: string | null
          niveau_ordre: number | null
          pin_order: number | null
          prix_achat: number | null
          prix_vente: number | null
          produit_id: string | null
          reference: string | null
          seuil_alerte: number | null
          stock: number | null
          titre: string | null
          updated_at: string | null
        }
        Insert: {
          actif?: boolean | null
          auteur?: string | null
          categorie?: string | null
          categorie_id?: string | null
          cover_path?: string | null
          cover_thumb_path?: string | null
          cover_updated_at?: string | null
          created_at?: string | null
          editeur?: string | null
          isbn?: string | null
          matiere?: string | null
          niveau?: string | null
          niveau_ordre?: number | null
          pin_order?: never
          prix_achat?: number | null
          prix_vente?: number | null
          produit_id?: string | null
          reference?: string | null
          seuil_alerte?: number | null
          stock?: never
          titre?: string | null
          updated_at?: string | null
        }
        Update: {
          actif?: boolean | null
          auteur?: string | null
          categorie?: string | null
          categorie_id?: string | null
          cover_path?: string | null
          cover_thumb_path?: string | null
          cover_updated_at?: string | null
          created_at?: string | null
          editeur?: string | null
          isbn?: string | null
          matiere?: string | null
          niveau?: string | null
          niveau_ordre?: number | null
          pin_order?: never
          prix_achat?: number | null
          prix_vente?: number | null
          produit_id?: string | null
          reference?: string | null
          seuil_alerte?: number | null
          stock?: never
          titre?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "produits_categorie_id_fkey"
            columns: ["categorie_id"]
            isOneToOne: false
            referencedRelation: "categories_produits"
            referencedColumns: ["categorie_id"]
          },
        ]
      }
    }
    Functions: {
      _exec_sql_restore: { Args: { sql: string }; Returns: undefined }
      _next_commande_numero: { Args: { _date: string }; Returns: string }
      _next_inventaire_numero: { Args: { _date: string }; Returns: string }
      _raise_bad_transition: {
        Args: { _new: string; _old: string; _table: string }
        Returns: undefined
      }
      _recalc_commande_totaux: {
        Args: { _commande_id: string }
        Returns: undefined
      }
      ajuster_stock_depot: {
        Args: {
          _depot_id: string
          _document_id?: string
          _document_reference?: string
          _document_table?: string
          _motif?: string
          _nouvelle_quantite: number
          _observation?: string
          _origine?: string
          _produit_id: string
        }
        Returns: undefined
      }
      annuler_colisage: {
        Args: { _bl_id: string; _motif?: string }
        Returns: undefined
      }
      annuler_incident: { Args: { _incident_id: string }; Returns: undefined }
      annuler_inventaire: {
        Args: { _inventaire_id: string }
        Returns: undefined
      }
      annuler_paiement:
        | {
            Args: { _paiement_id: string }
            Returns: {
              client_nom: string | null
              commentaire_validation: string | null
              created_at: string
              cree_par: string | null
              date_paiement: string
              exercice_id: string
              facture_id: string | null
              mode_paiement: string
              montant: number
              motif_rejet: string | null
              notes: string | null
              paiement_id: string
              reference: string
              rejete_le: string | null
              rejete_par: string | null
              statut: string
              updated_at: string
              valide_le: string | null
              valide_par: string | null
            }
            SetofOptions: {
              from: "*"
              to: "paiements"
              isOneToOne: true
              isSetofReturn: false
            }
          }
        | {
            Args: { _notes?: string; _paiement_id: string; _raison: string }
            Returns: {
              client_nom: string | null
              commentaire_validation: string | null
              created_at: string
              cree_par: string | null
              date_paiement: string
              exercice_id: string
              facture_id: string | null
              mode_paiement: string
              montant: number
              motif_rejet: string | null
              notes: string | null
              paiement_id: string
              reference: string
              rejete_le: string | null
              rejete_par: string | null
              statut: string
              updated_at: string
              valide_le: string | null
              valide_par: string | null
            }
            SetofOptions: {
              from: "*"
              to: "paiements"
              isOneToOne: true
              isSetofReturn: false
            }
          }
      annuler_retour: { Args: { _retour_id: string }; Returns: undefined }
      annuler_specimen: { Args: { _specimen_id: string }; Returns: undefined }
      annuler_transfert: { Args: { _transfert_id: string }; Returns: undefined }
      annuler_validation_tournee: {
        Args: { _commentaire?: string; _tournee_id: string }
        Returns: undefined
      }
      assert_permission: { Args: { _perm: string }; Returns: undefined }
      assigner_livraisons_tournee: {
        Args: {
          p_assignments: Json
          p_livreur_id: string
          p_tournee_id: string
        }
        Returns: number
      }
      audit_compta_doublons_paiement: {
        Args: never
        Returns: {
          date_paiement: string
          facture_id: string
          mode_paiement: string
          montant: number
          nb_doublons: number
          paiement_ids: string[]
        }[]
      }
      audit_compta_ecritures_desequilibrees: {
        Args: never
        Returns: {
          date_ecriture: string
          ecart: number
          ecriture_id: string
          journal: string
          libelle: string
          reference: string
          total_credit: number
          total_debit: number
        }[]
      }
      audit_compta_factures_paiements: {
        Args: never
        Returns: {
          client_nom: string
          ecart: number
          facture_id: string
          montant_paye_calcule: number
          montant_paye_enregistre: number
          montant_total: number
          probleme: string
          reference: string
          statut: string
        }[]
      }
      audit_compta_paiements_orphelins: {
        Args: never
        Returns: {
          date_paiement: string
          facture_id: string
          montant: number
          paiement_id: string
          probleme: string
          reference: string
        }[]
      }
      audit_compta_soldes_clients: {
        Args: never
        Returns: {
          client_id: string
          ecart: number
          nom: string
          reference: string
          solde_calcule: number
          solde_enregistre: number
        }[]
      }
      audit_events_archive_old: { Args: { p_months?: number }; Returns: number }
      audit_events_by_module: {
        Args: { p_days?: number }
        Returns: {
          module: string
          total: number
        }[]
      }
      audit_events_daily: {
        Args: { p_days?: number }
        Returns: {
          critical: number
          day: string
          info: number
          total: number
          warning: number
        }[]
      }
      audit_events_list: {
        Args: {
          p_action?: string
          p_limit?: number
          p_module?: string
          p_offset?: number
          p_period_days?: number
          p_search?: string
          p_user_email?: string
        }
        Returns: {
          action: string
          changes: Json
          duration_ms: number
          http_method: string
          id: string
          ip_address: string
          module: string
          new_values: Json
          occurred_at: string
          old_values: Json
          record_id: string
          record_ref: string
          status: string
          table_name: string
          total_count: number
          url: string
          user_agent: string
          user_email: string
          user_id: string
        }[]
      }
      audit_events_stats: {
        Args: {
          p_action?: string
          p_module?: string
          p_period_days?: number
          p_search?: string
          p_user_email?: string
        }
        Returns: {
          connected_15min: number
          today_events: number
          total_events: number
          unique_users: number
        }[]
      }
      audit_finances_anomalies: { Args: never; Returns: Json }
      audit_stats_v2: { Args: never; Returns: Json }
      audit_stock_anomalies: { Args: never; Returns: Json }
      calcul_solde_client: {
        Args: { _client_id: string; _exercice_id: string }
        Returns: number
      }
      calcul_solde_fournisseur: {
        Args: { _exercice_id: string; _fournisseur_id: string }
        Returns: number
      }
      can_choose_depot: { Args: { _user_id: string }; Returns: boolean }
      changer_statut_colis: {
        Args: {
          _colis_id: string
          _commentaire?: string
          _nouveau_statut: string
        }
        Returns: {
          bl_id: string | null
          colis_id: string
          commande_id: string | null
          commune: string | null
          contenu: string | null
          created_at: string
          date_arrivee_client: string | null
          date_arrivee_estimee: string | null
          date_arrivee_ville: string | null
          date_colisage: string | null
          date_depart: string | null
          date_depot_gare: string | null
          date_envoi: string
          date_livraison_reelle: string | null
          date_remise_client: string | null
          date_remise_livreur: string | null
          destinataire: string | null
          gare_depart: string | null
          gare_responsable: string | null
          gare_telephone: string | null
          livreur_nom: string | null
          livreur_telephone: string | null
          mode_acheminement: string | null
          nb_cartons: number | null
          notes: string | null
          numero_carton: number | null
          observations: string | null
          poids: number
          quartier: string | null
          reference: string
          responsable_id: string | null
          responsable_nom: string | null
          statut: string
          statut_logistique: string
          tournee_id: string | null
          transporteur: string | null
          updated_at: string
          vehicule: string | null
          ville_destination: string | null
          ville_livraison: string | null
        }
        SetofOptions: {
          from: "*"
          to: "colis"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      changer_statut_livraison: {
        Args: {
          p_commentaire?: string
          p_livraison_id: string
          p_nouveau_statut: Database["public"]["Enums"]["statut_livraison_cmd"]
        }
        Returns: string
      }
      client_historique: {
        Args: { _client_id: string }
        Returns: {
          categorie: string
          commande_id: string
          commande_reference: string
          commande_statut: string
          date_commande: string
          niveau: string
          prix_unitaire: number
          produit_id: string
          produit_titre: string
          quantite: number
          reference_produit: string
          remise_pct: number
          total_ligne: number
        }[]
      }
      clients_facets: { Args: never; Returns: Json }
      cloturer_tournee: {
        Args: { _tournee_id: string }
        Returns: {
          chauffeur_nom: string | null
          cloture_at: string | null
          cloture_by: string | null
          cloture_mode: string | null
          cout_autres: number
          cout_carburant: number
          cout_expeditions: number
          cout_livraison: number
          cout_manutentions: number
          cout_peages: number
          cout_repas: number
          cout_total: number | null
          created_at: string
          created_by: string | null
          date_tournee: string
          depot_depart_id: string | null
          ecriture_id: string | null
          heure_depart: string | null
          mode_reglement: string | null
          nb_cartons: number
          nb_clients: number
          nb_colis: number
          notes: string | null
          reference: string
          responsable_nom: string | null
          statut: string
          tournee_id: string
          type_tournee: string
          updated_at: string
          updated_by: string | null
          validation_at: string | null
          validation_by: string | null
          validation_commentaire: string | null
          validation_statut: string
          vehicule_id: string | null
        }
        SetofOptions: {
          from: "*"
          to: "tournees"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      colisage_logistique_deja_pris: {
        Args: { _bl_id: string }
        Returns: boolean
      }
      compta_balance: {
        Args: { p_exercice_id?: string; p_from?: string; p_to?: string }
        Returns: {
          compte: string
          compte_libelle: string
          credit: number
          debit: number
          solde: number
        }[]
      }
      confirmer_achat: { Args: { _achat_id: string }; Returns: undefined }
      convertir_commande_en_bl: {
        Args: {
          _adresse_livraison?: string
          _commande_id: string
          _date_livraison?: string
          _decrementer_stock?: boolean
          _nb_colis: number
          _poids_total?: number
          _signataire?: string
          _transporteur?: string
        }
        Returns: {
          bl_id: string
          reference: string
        }[]
      }
      convertir_proforma_en_commande: {
        Args: { _proforma_id: string }
        Returns: string
      }
      creer_colisage: {
        Args: { _bl_id: string; _payload: Json }
        Returns: {
          bl_id: string | null
          colis_id: string
          commande_id: string | null
          commune: string | null
          contenu: string | null
          created_at: string
          date_arrivee_client: string | null
          date_arrivee_estimee: string | null
          date_arrivee_ville: string | null
          date_colisage: string | null
          date_depart: string | null
          date_depot_gare: string | null
          date_envoi: string
          date_livraison_reelle: string | null
          date_remise_client: string | null
          date_remise_livreur: string | null
          destinataire: string | null
          gare_depart: string | null
          gare_responsable: string | null
          gare_telephone: string | null
          livreur_nom: string | null
          livreur_telephone: string | null
          mode_acheminement: string | null
          nb_cartons: number | null
          notes: string | null
          numero_carton: number | null
          observations: string | null
          poids: number
          quartier: string | null
          reference: string
          responsable_id: string | null
          responsable_nom: string | null
          statut: string
          statut_logistique: string
          tournee_id: string | null
          transporteur: string | null
          updated_at: string
          vehicule: string | null
          ville_destination: string | null
          ville_livraison: string | null
        }[]
        SetofOptions: {
          from: "*"
          to: "colis"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      creer_colisage_manuel: {
        Args: { _bl_id: string; _cartons: Json; _payload: Json }
        Returns: {
          bl_id: string | null
          colis_id: string
          commande_id: string | null
          commune: string | null
          contenu: string | null
          created_at: string
          date_arrivee_client: string | null
          date_arrivee_estimee: string | null
          date_arrivee_ville: string | null
          date_colisage: string | null
          date_depart: string | null
          date_depot_gare: string | null
          date_envoi: string
          date_livraison_reelle: string | null
          date_remise_client: string | null
          date_remise_livreur: string | null
          destinataire: string | null
          gare_depart: string | null
          gare_responsable: string | null
          gare_telephone: string | null
          livreur_nom: string | null
          livreur_telephone: string | null
          mode_acheminement: string | null
          nb_cartons: number | null
          notes: string | null
          numero_carton: number | null
          observations: string | null
          poids: number
          quartier: string | null
          reference: string
          responsable_id: string | null
          responsable_nom: string | null
          statut: string
          statut_logistique: string
          tournee_id: string | null
          transporteur: string | null
          updated_at: string
          vehicule: string | null
          ville_destination: string | null
          ville_livraison: string | null
        }[]
        SetofOptions: {
          from: "*"
          to: "colis"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      creer_commande: {
        Args: { _payload: Json }
        Returns: {
          adresse: string | null
          client_id: string | null
          client_nom: string | null
          commande_id: string
          commercial_id: string | null
          commercial_nom: string | null
          created_at: string
          created_by: string | null
          created_by_nom: string | null
          date_commande: string
          depot_id: string | null
          etablissement: string | null
          exercice_id: string
          montant_total: number
          montant_ttc: number
          montant_tva: number
          nb_produits: number
          net_a_payer: number
          notes: string | null
          numero: string | null
          observations: string | null
          reference: string
          remise: number
          remise_globale_montant: number
          remise_globale_pct: number
          representant_nom: string | null
          statut: string
          taux_tva: number
          telephone: string | null
          total_ht_brut: number
          total_ht_net: number
          total_quantite: number
          total_remises_lignes: number
          updated_at: string
          ville: string | null
        }
        SetofOptions: {
          from: "*"
          to: "commandes"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      creer_incident_stock: {
        Args: { _payload: Json }
        Returns: {
          created_at: string
          date_incident: string
          depot_id: string | null
          description: string | null
          gravite: string
          incident_id: string
          motif: string | null
          nb_produits: number
          numero: string | null
          observations: string | null
          reference: string
          responsable_id: string | null
          responsable_nom: string | null
          statut: string
          total_quantite: number
          type_incident: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "incidents"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      creer_inventaire_global: {
        Args: { _payload?: Json }
        Returns: {
          categorie_id: string | null
          created_at: string
          created_by: string | null
          created_by_nom: string | null
          date_inventaire: string
          depot_id: string | null
          exercice_id: string
          inventaire_id: string
          nb_ecarts: number
          nb_produits: number
          numero: string
          observations: string | null
          regularized_at: string | null
          statut: string
          type_inventaire: string
          updated_at: string
          valeur_totale: number
          validated_at: string | null
          validated_by: string | null
        }
        SetofOptions: {
          from: "*"
          to: "inventaires"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      creer_inventaire_physique: {
        Args: { _payload: Json }
        Returns: {
          categorie_id: string | null
          created_at: string
          created_by: string | null
          created_by_nom: string | null
          date_inventaire: string
          depot_id: string | null
          exercice_id: string
          inventaire_id: string
          nb_ecarts: number
          nb_produits: number
          numero: string
          observations: string | null
          regularized_at: string | null
          statut: string
          type_inventaire: string
          updated_at: string
          valeur_totale: number
          validated_at: string | null
          validated_by: string | null
        }
        SetofOptions: {
          from: "*"
          to: "inventaires"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      creer_inventaire_theorique: {
        Args: { _payload?: Json }
        Returns: {
          categorie_id: string | null
          created_at: string
          created_by: string | null
          created_by_nom: string | null
          date_inventaire: string
          depot_id: string | null
          exercice_id: string
          inventaire_id: string
          nb_ecarts: number
          nb_produits: number
          numero: string
          observations: string | null
          regularized_at: string | null
          statut: string
          type_inventaire: string
          updated_at: string
          valeur_totale: number
          validated_at: string | null
          validated_by: string | null
        }
        SetofOptions: {
          from: "*"
          to: "inventaires"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      creer_retour: {
        Args: { _payload: Json }
        Returns: {
          adresse: string | null
          client_id: string | null
          client_nom: string | null
          commande_id: string | null
          created_at: string
          created_by: string | null
          created_by_nom: string | null
          date_retour: string
          depot_id: string | null
          etablissement: string | null
          exercice_id: string
          facture_id: string | null
          livraison_id: string | null
          montant: number | null
          motif: string | null
          nb_produits: number
          notes: string | null
          numero: string | null
          observations: string | null
          produit_nom: string | null
          quantite: number | null
          reference: string
          representant_nom: string | null
          retour_id: string
          statut: string
          telephone: string | null
          total_quantite: number
          updated_at: string
          ville: string | null
        }
        SetofOptions: {
          from: "*"
          to: "retours"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      creer_specimen: {
        Args: { _payload: Json }
        Returns: {
          adresse: string | null
          client_id: string | null
          created_at: string
          created_by: string | null
          date_envoi: string
          donneur_nom: string
          etablissement: string
          gestionnaire_id: string | null
          gestionnaire_nom: string | null
          motif: string | null
          nb_produits: number
          numero: string
          observations: string | null
          representant_nom: string | null
          specimen_id: string
          statut: string
          telephone: string | null
          total_quantite: number
          updated_at: string
          ville: string | null
        }
        SetofOptions: {
          from: "*"
          to: "specimens"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      crm_dashboard: { Args: { _from?: string; _to?: string }; Returns: Json }
      dashboard_client_stats: {
        Args: never
        Returns: {
          actifs: number
          solde_total: number
          total: number
        }[]
      }
      dashboard_overview_full: {
        Args: { _exercice_id: string; _periode_jours?: number }
        Returns: Json
      }
      definir_depot_principal: {
        Args: { _depot_id: string }
        Returns: undefined
      }
      deverrouiller_colisage: {
        Args: { _bl_id: string; _motif: string }
        Returns: string
      }
      each: { Args: { hs: unknown }; Returns: Record<string, unknown>[] }
      employe_anciennete_mois: {
        Args: { _employe_id: string }
        Returns: number
      }
      enregistrer_approvisionnement: {
        Args: { _payload: Json }
        Returns: {
          achat_id: string
          created_at: string
          created_by: string | null
          created_by_nom: string | null
          date_achat: string
          exercice_id: string
          fournisseur_id: string | null
          libelle: string
          montant: number
          notes: string | null
          reference: string
          reference_fournisseur: string | null
          statut: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "achats"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      enregistrer_paiement: {
        Args: { _payload: Json }
        Returns: {
          client_nom: string | null
          commentaire_validation: string | null
          created_at: string
          cree_par: string | null
          date_paiement: string
          exercice_id: string
          facture_id: string | null
          mode_paiement: string
          montant: number
          motif_rejet: string | null
          notes: string | null
          paiement_id: string
          reference: string
          rejete_le: string | null
          rejete_par: string | null
          statut: string
          updated_at: string
          valide_le: string | null
          valide_par: string | null
        }
        SetofOptions: {
          from: "*"
          to: "paiements"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      executer_cloture_exercice: {
        Args: { _activer_suivant?: boolean; _exercice_id: string }
        Returns: Json
      }
      executer_transfert: {
        Args: { _transfert_id: string }
        Returns: undefined
      }
      exercice_actif_id: { Args: never; Returns: string }
      exercice_pour_date: { Args: { _d: string }; Returns: string }
      exercices_comparatif: {
        Args: { _exercice_ids: string[] }
        Returns: {
          achats: number
          ca: number
          encaisse: number
          exercice_id: string
          nb_commandes: number
          nb_factures: number
        }[]
      }
      expirer_points_fidelite: { Args: never; Returns: number }
      factures_impayees_client: {
        Args: { _client_id: string }
        Returns: {
          date_facture: string
          facture_id: string
          montant_paye: number
          montant_total: number
          reference: string
          solde: number
          statut: string
        }[]
      }
      factures_list_paginated: {
        Args: {
          p_client?: string
          p_client_ids?: string[]
          p_commande_ids?: string[]
          p_date_au?: string
          p_date_du?: string
          p_exercice_id?: string
          p_limit?: number
          p_montant_max?: number
          p_montant_min?: number
          p_offset?: number
          p_q?: string
          p_reference?: string
          p_statut?: string
        }
        Returns: {
          client_id: string
          client_nom: string
          commande_id: string
          created_at: string
          date_echeance: string
          date_facture: string
          facture_id: string
          montant_paye: number
          montant_total: number
          notes: string
          reference: string
          statut: string
          sum_montant_paye: number
          sum_montant_total: number
          total_count: number
          updated_at: string
        }[]
      }
      finaliser_tournee: {
        Args: { _tournee_id: string }
        Returns: {
          chauffeur_nom: string | null
          cloture_at: string | null
          cloture_by: string | null
          cloture_mode: string | null
          cout_autres: number
          cout_carburant: number
          cout_expeditions: number
          cout_livraison: number
          cout_manutentions: number
          cout_peages: number
          cout_repas: number
          cout_total: number | null
          created_at: string
          created_by: string | null
          date_tournee: string
          depot_depart_id: string | null
          ecriture_id: string | null
          heure_depart: string | null
          mode_reglement: string | null
          nb_cartons: number
          nb_clients: number
          nb_colis: number
          notes: string | null
          reference: string
          responsable_nom: string | null
          statut: string
          tournee_id: string
          type_tournee: string
          updated_at: string
          updated_by: string | null
          validation_at: string | null
          validation_by: string | null
          validation_commentaire: string | null
          validation_statut: string
          vehicule_id: string | null
        }
        SetofOptions: {
          from: "*"
          to: "tournees"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      generer_facture: {
        Args: { _commande_id: string }
        Returns: {
          client_id: string | null
          client_nom: string | null
          commande_id: string | null
          created_at: string
          date_echeance: string | null
          date_facture: string
          exercice_id: string
          facture_id: string
          montant_paye: number
          montant_total: number
          notes: string | null
          reference: string
          statut: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "factures"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      generer_proforma_commande: {
        Args: { _commande_id: string }
        Returns: {
          client_id: string | null
          client_nom: string | null
          commande_id: string | null
          created_at: string
          date_proforma: string
          date_validite: string | null
          exercice_id: string
          montant_total: number
          notes: string | null
          proforma_id: string
          reference: string
          statut: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "proformas"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      get_carton_public: { Args: { _colis_id: string }; Returns: Json }
      get_lignes_retournables: {
        Args: { _facture_id: string }
        Returns: {
          designation: string
          prix_unitaire: number
          produit_id: string
          qte_deja_retournee: number
          qte_disponible: number
          qte_vendue: number
          reference_produit: string
          remise_pct: number
          total_ligne: number
        }[]
      }
      get_slo_metrics: { Args: never; Returns: Json }
      has_any_role: {
        Args: {
          _roles: Database["public"]["Enums"]["app_role"][]
          _user_id: string
        }
        Returns: boolean
      }
      has_commercial_access: { Args: { _user_id: string }; Returns: boolean }
      has_finance_access: { Args: { _user_id: string }; Returns: boolean }
      has_module: {
        Args: { _module: string; _user_id: string }
        Returns: boolean
      }
      has_operational_access: { Args: { _user_id: string }; Returns: boolean }
      has_permission: {
        Args: { _perm: string; _user_id: string }
        Returns: boolean
      }
      has_permission_v2: {
        Args: { _perm: string; _user_id: string }
        Returns: boolean
      }
      has_rbac_permission_fast: {
        Args: { _perm: string; _user_id: string }
        Returns: boolean
      }
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"]
          _user_id: string
        }
        Returns: boolean
      }
      is_exercice_admin: { Args: { _uid: string }; Returns: boolean }
      is_restricted_user: { Args: never; Returns: boolean }
      is_staff: { Args: { _user_id: string }; Returns: boolean }
      jsonb_diff: { Args: { new: Json; old: Json }; Returns: Json }
      list_user_permissions: {
        Args: { _user_id: string }
        Returns: {
          permission_code: string
        }[]
      }
      livsuivi_avancer: {
        Args: {
          _commentaire?: string
          _etape: Database["public"]["Enums"]["livsuivi_statut"]
          _livraison_id: string
          _meta?: Json
        }
        Returns: {
          bl_id: string | null
          cloturee: boolean
          commande_id: string
          commentaire_reception: string | null
          created_at: string
          derniere_maj: string
          gare_depot: string | null
          gare_destination: string | null
          heure_arrivee: string | null
          heure_depart: string | null
          heure_livraison: string | null
          id: string
          livreur_nom: string | null
          nb_cartons: number | null
          ordre_passage: number | null
          photo_preuve_url: string | null
          point_livraison: string | null
          receptionnaire_nom: string | null
          receptionnaire_telephone: string | null
          retour_motif: string | null
          signature_url: string | null
          statut: Database["public"]["Enums"]["livsuivi_statut"]
          tournee_id: string | null
          type_livraison: Database["public"]["Enums"]["livsuivi_type"]
          updated_at: string
          vehicule: string | null
          ville_destination: string | null
        }
        SetofOptions: {
          from: "*"
          to: "livsuivi_commandes"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      livsuivi_avancer_masse: {
        Args: {
          _etape: Database["public"]["Enums"]["livsuivi_statut"]
          _filtre_gare?: string
          _meta?: Json
          _tournee_id: string
        }
        Returns: number
      }
      livsuivi_confirmer_reception: {
        Args: {
          _commentaire?: string
          _id: string
          _photo_url?: string
          _receptionnaire_nom?: string
          _receptionnaire_tel?: string
          _signature_url?: string
        }
        Returns: {
          bl_id: string | null
          cloturee: boolean
          commande_id: string
          commentaire_reception: string | null
          created_at: string
          derniere_maj: string
          gare_depot: string | null
          gare_destination: string | null
          heure_arrivee: string | null
          heure_depart: string | null
          heure_livraison: string | null
          id: string
          livreur_nom: string | null
          nb_cartons: number | null
          ordre_passage: number | null
          photo_preuve_url: string | null
          point_livraison: string | null
          receptionnaire_nom: string | null
          receptionnaire_telephone: string | null
          retour_motif: string | null
          signature_url: string | null
          statut: Database["public"]["Enums"]["livsuivi_statut"]
          tournee_id: string | null
          type_livraison: Database["public"]["Enums"]["livsuivi_type"]
          updated_at: string
          vehicule: string | null
          ville_destination: string | null
        }
        SetofOptions: {
          from: "*"
          to: "livsuivi_commandes"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      livsuivi_next_etape: {
        Args: {
          _current: Database["public"]["Enums"]["livsuivi_statut"]
          _type: Database["public"]["Enums"]["livsuivi_type"]
        }
        Returns: Database["public"]["Enums"]["livsuivi_statut"]
      }
      log_audit_event: {
        Args: {
          p_action: Database["public"]["Enums"]["audit_action"]
          p_duration_ms?: number
          p_error_message?: string
          p_http_method?: string
          p_ip?: unknown
          p_metadata?: Json
          p_module?: string
          p_record_id?: string
          p_record_ref?: string
          p_status?: string
          p_table_name?: string
          p_url?: string
          p_user_agent?: string
        }
        Returns: string
      }
      log_permission_denied: {
        Args: { _context?: Json; _perm: string }
        Returns: undefined
      }
      log_user_login: {
        Args: {
          _device?: string
          _ip_address?: string
          _status?: string
          _user_agent?: string
        }
        Returns: string
      }
      merge_clients: {
        Args: { _dup_ids: string[]; _keep_id: string }
        Returns: Json
      }
      modifier_approvisionnement: {
        Args: { _achat_id: string; _payload: Json }
        Returns: {
          achat_id: string
          created_at: string
          created_by: string | null
          created_by_nom: string | null
          date_achat: string
          exercice_id: string
          fournisseur_id: string | null
          libelle: string
          montant: number
          notes: string | null
          reference: string
          reference_fournisseur: string | null
          statut: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "achats"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      modifier_colis_lignes: {
        Args: { _colis_id: string; _lignes: Json; _motif?: string }
        Returns: undefined
      }
      modifier_commande: {
        Args: { _commande_id: string; _payload: Json }
        Returns: {
          adresse: string | null
          client_id: string | null
          client_nom: string | null
          commande_id: string
          commercial_id: string | null
          commercial_nom: string | null
          created_at: string
          created_by: string | null
          created_by_nom: string | null
          date_commande: string
          depot_id: string | null
          etablissement: string | null
          exercice_id: string
          montant_total: number
          montant_ttc: number
          montant_tva: number
          nb_produits: number
          net_a_payer: number
          notes: string | null
          numero: string | null
          observations: string | null
          reference: string
          remise: number
          remise_globale_montant: number
          remise_globale_pct: number
          representant_nom: string | null
          statut: string
          taux_tva: number
          telephone: string | null
          total_ht_brut: number
          total_ht_net: number
          total_quantite: number
          total_remises_lignes: number
          updated_at: string
          ville: string | null
        }
        SetofOptions: {
          from: "*"
          to: "commandes"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      next_document_number: {
        Args: { _prefix: string; _year?: number }
        Returns: string
      }
      notifier_points_expirants: { Args: never; Returns: number }
      payer_achat: { Args: { _achat_id: string }; Returns: undefined }
      perf_hotspots_top: {
        Args: { p_limit?: number }
        Returns: {
          calls: number
          max_ms: number
          mean_ms: number
          query: string
          rows_avg: number
          total_ms: number
        }[]
      }
      preview_cloture_exercice: {
        Args: { _exercice_id: string }
        Returns: Json
      }
      produit_niveau_ordre: { Args: { n: string }; Returns: number }
      purge_notifications: { Args: never; Returns: undefined }
      purger_anciennes_sauvegardes: {
        Args: { _retention?: number; _type?: string }
        Returns: number
      }
      rapport_agregat: {
        Args: { _dim?: string; _filtres?: Json }
        Returns: Json
      }
      rapport_clients_produit: {
        Args: { _filtres?: Json; _limit?: number; _produit_id: string }
        Returns: Json
      }
      rapport_evolution: {
        Args: { _filtres?: Json; _granularite?: string }
        Returns: Json
      }
      rapport_flop_produits: { Args: { _filtres?: Json }; Returns: Json }
      rapport_kpi: { Args: { _filtres?: Json }; Returns: Json }
      rapport_produits: {
        Args: {
          _filtres?: Json
          _limit?: number
          _offset?: number
          _sens?: string
          _tri?: string
        }
        Returns: Json
      }
      rapport_top_produits: {
        Args: { _filtres?: Json; _limit?: number }
        Returns: Json
      }
      rbac_bulk_set_permissions: {
        Args: { _accorde: boolean; _codes: string[]; _role_id: string }
        Returns: number
      }
      rbac_request_headers: { Args: never; Returns: Json }
      rbac_role_ancestors: {
        Args: { _role_id: string }
        Returns: {
          role_id: string
        }[]
      }
      rbac_set_role_permission: {
        Args: { _accorde: boolean; _code: string; _role_id: string }
        Returns: number
      }
      recalc_commande: { Args: { _commande_id: string }; Returns: undefined }
      recalc_tournee_from_colis: { Args: { _date: string }; Returns: number }
      recalculer_livraison_commande: {
        Args: { _livraison_id: string }
        Returns: undefined
      }
      recalculer_solde_client: {
        Args: { _client_id: string; _motif?: string }
        Returns: Json
      }
      recalculer_soldes_global_clients: {
        Args: { _motif?: string }
        Returns: Json
      }
      receptionner_achat: { Args: { _achat_id: string }; Returns: undefined }
      receptionner_transfert: {
        Args: { _transfert_id: string }
        Returns: undefined
      }
      refuser_tournee_couts: {
        Args: { _commentaire: string; _tournee_id: string }
        Returns: undefined
      }
      regulariser_inventaire: {
        Args: { _inventaire_id: string }
        Returns: undefined
      }
      rejeter_paiement: {
        Args: { _motif: string; _paiement_id: string }
        Returns: {
          client_nom: string | null
          commentaire_validation: string | null
          created_at: string
          cree_par: string | null
          date_paiement: string
          exercice_id: string
          facture_id: string | null
          mode_paiement: string
          montant: number
          motif_rejet: string | null
          notes: string | null
          paiement_id: string
          reference: string
          rejete_le: string | null
          rejete_par: string | null
          statut: string
          updated_at: string
          valide_le: string | null
          valide_par: string | null
        }
        SetofOptions: {
          from: "*"
          to: "paiements"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      renumber_employes_matricules: { Args: never; Returns: number }
      report_bl_orphelins: {
        Args: never
        Returns: {
          bl_id: string
          client_id: string
          cree_le: string
          montant: number
          reference: string
          statut: string
        }[]
      }
      report_client_duplicates: {
        Args: never
        Returns: {
          client_ids: string[]
          nb: number
          nom_normalise: string
          noms: string[]
        }[]
      }
      report_stock_ecarts: {
        Args: never
        Returns: {
          ecart: number
          produit_id: string
          stock_actuel: number
          stock_calcule: number
          titre: string
        }[]
      }
      resolve_depot_sortie: {
        Args: { _module: string; _requested: string }
        Returns: string
      }
      restore_employe: {
        Args: { _employe_id: string; _retention_days?: number }
        Returns: undefined
      }
      search_clients_crm: {
        Args: { _filters?: Json; _limit?: number; _offset?: number }
        Returns: Json
      }
      soft_delete_employe: { Args: { _employe_id: string }; Returns: undefined }
      soumettre_commande: { Args: { _commande_id: string }; Returns: undefined }
      supprimer_achat: {
        Args: { _achat_id: string; _motif?: string }
        Returns: Json
      }
      supprimer_client: {
        Args: { _client_id: string; _motif?: string }
        Returns: Json
      }
      supprimer_colisage: {
        Args: { _bl_id: string; _motif?: string }
        Returns: Json
      }
      supprimer_commande_definitif: {
        Args: { _commande_id: string; _motif?: string }
        Returns: undefined
      }
      supprimer_employe: {
        Args: { _employe_id: string; _motif?: string }
        Returns: Json
      }
      supprimer_facture_definitif: {
        Args: { _facture_id: string; _motif?: string }
        Returns: undefined
      }
      supprimer_fournisseur: {
        Args: { _fournisseur_id: string; _motif?: string }
        Returns: Json
      }
      supprimer_livraison_suivi: {
        Args: { _id: string; _motif?: string }
        Returns: Json
      }
      supprimer_paiement_definitif: {
        Args: { _motif: string; _paiement_id: string }
        Returns: undefined
      }
      supprimer_produit: {
        Args: { _motif?: string; _produit_id: string }
        Returns: Json
      }
      supprimer_proforma_definitif: {
        Args: { _motif?: string; _proforma_id: string }
        Returns: undefined
      }
      supprimer_tournee: {
        Args: { _motif?: string; _tournee_id: string }
        Returns: Json
      }
      sync_rbac_matrix: { Args: never; Returns: Json }
      to_base36: { Args: { n: number; width?: number }; Returns: string }
      track_user_action: {
        Args: {
          _action_key: string
          _href?: string
          _icon?: string
          _label?: string
          _module?: string
        }
        Returns: undefined
      }
      trigger_execution_log_purge: { Args: never; Returns: undefined }
      utiliser_points_fidelite: {
        Args: { _facture_id: string; _points: number }
        Returns: Json
      }
      valider_commande: {
        Args: { _commande_id: string }
        Returns: {
          bl_reference: string
          facture_reference: string
        }[]
      }
      valider_decaissement_tournee: {
        Args: {
          _commentaire?: string
          _mode_reglement: string
          _tournee_id: string
        }
        Returns: string
      }
      valider_inventaire_physique: {
        Args: { _inventaire_id: string; _lignes: Json }
        Returns: {
          categorie_id: string | null
          created_at: string
          created_by: string | null
          created_by_nom: string | null
          date_inventaire: string
          depot_id: string | null
          exercice_id: string
          inventaire_id: string
          nb_ecarts: number
          nb_produits: number
          numero: string
          observations: string | null
          regularized_at: string | null
          statut: string
          type_inventaire: string
          updated_at: string
          valeur_totale: number
          validated_at: string | null
          validated_by: string | null
        }
        SetofOptions: {
          from: "*"
          to: "inventaires"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      valider_paiement: {
        Args: { _commentaire?: string; _paiement_id: string }
        Returns: {
          client_nom: string | null
          commentaire_validation: string | null
          created_at: string
          cree_par: string | null
          date_paiement: string
          exercice_id: string
          facture_id: string | null
          mode_paiement: string
          montant: number
          motif_rejet: string | null
          notes: string | null
          paiement_id: string
          reference: string
          rejete_le: string | null
          rejete_par: string | null
          statut: string
          updated_at: string
          valide_le: string | null
          valide_par: string | null
        }
        SetofOptions: {
          from: "*"
          to: "paiements"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      valider_transition_livraison: {
        Args: {
          _ancien: Database["public"]["Enums"]["statut_livraison_cmd"]
          _nouveau: Database["public"]["Enums"]["statut_livraison_cmd"]
          _type: Database["public"]["Enums"]["type_livraison"]
        }
        Returns: boolean
      }
    }
    Enums: {
      app_role:
        | "super_admin"
        | "directeur_general"
        | "comptable"
        | "directeur_commercial"
        | "gestionnaire_stock"
        | "responsable_magasinier"
        | "secretariat"
        | "assistante"
        | "service_logistique"
        | "assistante_comptable"
        | "responsable_logistique"
        | "rh"
        | "commercial"
      audit_action:
        | "INSERT"
        | "UPDATE"
        | "DELETE"
        | "LOGIN"
        | "LOGIN_FAILED"
        | "LOGOUT"
        | "EXPORT"
        | "IMPORT"
        | "PRINT"
        | "DOWNLOAD"
        | "UPLOAD"
        | "VALIDATION"
        | "APPROBATION"
        | "ANNULATION"
        | "CONSULTATION"
      audit_criticite: "info" | "warning" | "critical"
      exercice_statut:
        | "preparation"
        | "actif"
        | "cloture_en_cours"
        | "cloture"
        | "archive"
      livsuivi_statut:
        | "preparee"
        | "remise_livreur"
        | "depart_depot"
        | "arrive_client"
        | "livree"
        | "remise_transporteur"
        | "expediee"
        | "arrivee_gare"
        | "retiree_client"
        | "livree_locale"
        | "chargee"
        | "en_route"
        | "reception_confirmee"
        | "non_livre"
      livsuivi_type: "direct" | "expedition" | "mixte"
      mode_paiement_enum: "virement" | "cheque" | "especes" | "mobile_money"
      sexe_enum: "M" | "F" | "autre"
      situation_matrimoniale_enum:
        | "celibataire"
        | "marie"
        | "divorce"
        | "veuf"
        | "union_libre"
      statut_employe_enum:
        | "actif"
        | "suspendu"
        | "demission"
        | "licencie"
        | "retraite"
        | "fin_contrat"
      statut_livraison_cmd:
        | "commande_creee"
        | "preparation"
        | "colisage_termine"
        | "en_attente_expedition"
        | "expediee"
        | "en_cours_livraison"
        | "livree"
        | "livraison_partielle"
        | "livraison_confirmee"
        | "anomalie"
        | "assignee"
        | "chargee"
        | "en_route"
        | "deposee_gare"
        | "arrivee_destination"
        | "retiree_client"
        | "retour"
        | "annulee"
      temps_travail_enum: "temps_plein" | "temps_partiel" | "forfait_jour"
      type_contrat_enum:
        | "CDI"
        | "CDD"
        | "stage"
        | "consultant"
        | "interim"
        | "apprentissage"
      type_livraison: "directe" | "expedition"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: [
        "super_admin",
        "directeur_general",
        "comptable",
        "directeur_commercial",
        "gestionnaire_stock",
        "responsable_magasinier",
        "secretariat",
        "assistante",
        "service_logistique",
        "assistante_comptable",
        "responsable_logistique",
        "rh",
        "commercial",
      ],
      audit_action: [
        "INSERT",
        "UPDATE",
        "DELETE",
        "LOGIN",
        "LOGIN_FAILED",
        "LOGOUT",
        "EXPORT",
        "IMPORT",
        "PRINT",
        "DOWNLOAD",
        "UPLOAD",
        "VALIDATION",
        "APPROBATION",
        "ANNULATION",
        "CONSULTATION",
      ],
      audit_criticite: ["info", "warning", "critical"],
      exercice_statut: [
        "preparation",
        "actif",
        "cloture_en_cours",
        "cloture",
        "archive",
      ],
      livsuivi_statut: [
        "preparee",
        "remise_livreur",
        "depart_depot",
        "arrive_client",
        "livree",
        "remise_transporteur",
        "expediee",
        "arrivee_gare",
        "retiree_client",
        "livree_locale",
        "chargee",
        "en_route",
        "reception_confirmee",
        "non_livre",
      ],
      livsuivi_type: ["direct", "expedition", "mixte"],
      mode_paiement_enum: ["virement", "cheque", "especes", "mobile_money"],
      sexe_enum: ["M", "F", "autre"],
      situation_matrimoniale_enum: [
        "celibataire",
        "marie",
        "divorce",
        "veuf",
        "union_libre",
      ],
      statut_employe_enum: [
        "actif",
        "suspendu",
        "demission",
        "licencie",
        "retraite",
        "fin_contrat",
      ],
      statut_livraison_cmd: [
        "commande_creee",
        "preparation",
        "colisage_termine",
        "en_attente_expedition",
        "expediee",
        "en_cours_livraison",
        "livree",
        "livraison_partielle",
        "livraison_confirmee",
        "anomalie",
        "assignee",
        "chargee",
        "en_route",
        "deposee_gare",
        "arrivee_destination",
        "retiree_client",
        "retour",
        "annulee",
      ],
      temps_travail_enum: ["temps_plein", "temps_partiel", "forfait_jour"],
      type_contrat_enum: [
        "CDI",
        "CDD",
        "stage",
        "consultant",
        "interim",
        "apprentissage",
      ],
      type_livraison: ["directe", "expedition"],
    },
  },
} as const
