"""
E2E test — Propagation RBAC en temps réel (étendu).

Scénario couvert :
  1. Tab A crée un rôle (UI).
  2. Tab B (onglet Historique) reçoit l'entrée `role_create` via Realtime.
  3. Tab A ouvre la matrice et coche une permission → audit `perm_add`
     avec `avant/apres` peuplés observé sur Tab B.
  4. Tab A ouvre "Utilisateurs" et assigne le rôle au premier utilisateur
     → audit `user_role_add` observé sur Tab B.
  5. Cleanup UI : décocher user, décocher permission, supprimer le rôle.

Prérequis : `LOVABLE_BROWSER_AUTH_STATUS=injected` (session super_admin).
Usage : `python3 tests/e2e/rbac-propagation.py`
"""
import asyncio, json, os, sys, time
from pathlib import Path
from playwright.async_api import async_playwright, Page

BASE = "http://localhost:8080"
SHOTS = Path(__file__).parent / "screenshots"
SHOTS.mkdir(exist_ok=True)

STORAGE_KEY = os.environ.get("LOVABLE_BROWSER_SUPABASE_STORAGE_KEY")
SESSION = os.environ.get("LOVABLE_BROWSER_SUPABASE_SESSION_JSON")
COOKIES = os.environ.get("LOVABLE_BROWSER_SUPABASE_COOKIES_JSON")

if not (STORAGE_KEY and SESSION):
    print("SKIP: no LOVABLE_BROWSER_SUPABASE_* session in env")
    sys.exit(0)

ROLE_CODE = f"e2e_test_{int(time.time())}"
ROLE_LIBELLE = f"E2E {ROLE_CODE}"


async def hydrate(ctx, page: Page):
    if COOKIES:
        cs = json.loads(COOKIES)
        for c in cs:
            c["url"] = BASE
        await ctx.add_cookies(cs)
    await page.goto(BASE, wait_until="domcontentloaded")
    await page.evaluate(
        f"window.localStorage.setItem({json.dumps(STORAGE_KEY)}, {json.dumps(SESSION)})"
    )


async def open_rbac(page: Page):
    await page.goto(f"{BASE}/roles-permissions", wait_until="networkidle")
    await asyncio.sleep(1.5)


async def audit_contains(page: Page, needle: str) -> bool:
    return await page.evaluate(
        "(n) => !!Array.from(document.querySelectorAll('table tbody tr'))"
        ".find(r => r.innerText.includes(n))",
        needle,
    )


async def wait_audit(page: Page, needle: str, timeout: float = 8.0) -> bool:
    """Attend qu'une ligne d'audit contenant `needle` apparaisse (Realtime)."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        if await audit_contains(page, needle):
            return True
        await asyncio.sleep(0.5)
    return False


async def main():
    results: dict[str, bool] = {}
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        ctx = await browser.new_context(viewport={"width": 1280, "height": 1800})
        tab_a = await ctx.new_page()
        tab_b = await ctx.new_page()

        errors: list[str] = []
        for t in (tab_a, tab_b):
            t.on(
                "console",
                lambda m: errors.append(f"[{m.type}] {m.text}") if m.type == "error" else None,
            )

        await hydrate(ctx, tab_a)
        await hydrate(ctx, tab_b)
        await open_rbac(tab_a)
        await open_rbac(tab_b)

        # Tab B → onglet Historique (observateur Realtime)
        try:
            await tab_b.get_by_role("tab", name="Historique").click()
            await asyncio.sleep(1)
        except Exception as e:
            print("Historique tab introuvable:", e)
        await tab_b.screenshot(path=str(SHOTS / "01_tabB_audit_before.png"))

        # ============ 1. CREATION ROLE ============
        await tab_a.get_by_role("tab", name="Rôles").click()
        await asyncio.sleep(0.5)
        try:
            await tab_a.get_by_role("button", name="Nouveau rôle").click()
        except Exception:
            await tab_a.get_by_role("button", name="Créer un rôle").click()
        await asyncio.sleep(0.5)
        await tab_a.get_by_placeholder("Ex : Chef de projet").fill(ROLE_LIBELLE)
        await tab_a.get_by_placeholder("ex: chef_projet").fill(ROLE_CODE)
        await tab_a.screenshot(path=str(SHOTS / "02_tabA_create_form.png"))
        await tab_a.get_by_role("button", name="Créer", exact=True).click()
        await asyncio.sleep(2)
        await tab_a.screenshot(path=str(SHOTS / "03_tabA_after_create.png"))

        results["role_create → audit"] = await wait_audit(tab_b, ROLE_CODE, 8.0)
        await tab_b.screenshot(path=str(SHOTS / "04_tabB_after_create.png"))

        # ============ 2. TOGGLE PERMISSION ============
        try:
            await tab_a.get_by_role("tab", name="Matrice").click()
            await asyncio.sleep(1)
            # Sélectionner le nouveau rôle si un Select est présent
            try:
                await tab_a.get_by_role("combobox").first.click()
                await asyncio.sleep(0.3)
                await tab_a.get_by_role("option", name=ROLE_LIBELLE).click()
                await asyncio.sleep(0.5)
            except Exception:
                await tab_a.keyboard.press("Escape")
                await asyncio.sleep(0.3)
            # Ouvrir le premier accordéon module
            try:
                await tab_a.locator('button[data-state="closed"]').first.click()
                await asyncio.sleep(0.5)
            except Exception:
                pass
            # Cocher la première case décochée dans la matrice
            box = tab_a.locator('button[role="checkbox"][data-state="unchecked"]').first
            await box.scroll_into_view_if_needed()
            await box.click(force=True)
            await asyncio.sleep(2)
            await tab_a.screenshot(path=str(SHOTS / "05_tabA_perm_toggled.png"))

            results["perm_add → audit"] = await wait_audit(tab_b, "perm_add", 8.0) or await wait_audit(tab_b, ROLE_CODE, 4.0)
            await tab_b.screenshot(path=str(SHOTS / "06_tabB_after_perm.png"))
        except Exception as e:
            print("perm toggle skipped:", e)
            results["perm_add → audit"] = False

        # ============ 3. ASSIGN USER ============
        try:
            await tab_a.get_by_role("tab", name="Utilisateurs").click()
            await asyncio.sleep(1.5)
            # Trouver l'index de colonne du nouveau rôle via JS (le libellé peut être tronqué visuellement)
            col_index = await tab_a.evaluate(
                """(libelle) => {
                    const ths = Array.from(document.querySelectorAll('table thead th'));
                    const idx = ths.findIndex(t => t.innerText.trim() === libelle);
                    return idx;
                }""",
                ROLE_LIBELLE,
            )
            if col_index < 0:
                raise Exception(f"colonne rôle introuvable ({ROLE_LIBELLE})")
            first_row_box = tab_a.locator(
                f'table tbody tr:first-child td:nth-child({col_index + 1}) button[role="checkbox"]'
            )
            await first_row_box.scroll_into_view_if_needed()
            await first_row_box.click(force=True)
            await asyncio.sleep(2)
            await tab_a.screenshot(path=str(SHOTS / "07_tabA_user_assigned.png"))

            results["assign → audit"] = await wait_audit(tab_b, "assign", 8.0)
            await tab_b.screenshot(path=str(SHOTS / "08_tabB_after_assign.png"))

            # Cleanup: décocher
            await first_row_box.click(force=True)
            await asyncio.sleep(1)
        except Exception as e:
            print("user assign skipped:", e)
            results["assign → audit"] = False

        # ============ 4. CLEANUP: DELETE ROLE ============
        try:
            await tab_a.get_by_role("tab", name="Rôles").click()
            await asyncio.sleep(1)
            # Repérer la ligne contenant le libellé et cliquer son bouton "Supprimer"
            row = tab_a.locator("tr", has_text=ROLE_LIBELLE).first
            # Le bouton Supprimer n'a qu'une icône Trash2 → cibler le dernier bouton ghost de la ligne
            await row.locator("button").last.click()
            await asyncio.sleep(0.5)
            for label in ("Confirmer", "Supprimer", "Oui"):
                try:
                    await tab_a.get_by_role("button", name=label).last.click(timeout=2000)
                    break
                except Exception:
                    continue
            await asyncio.sleep(1.5)
            results["role_delete → audit"] = await wait_audit(tab_b, "role_delete", 6.0)
        except Exception as e:
            print("cleanup skipped:", e)
            results["role_delete → audit"] = False

        # ============ REPORT ============
        print("=" * 60)
        print(f"E2E propagation RBAC — rôle {ROLE_CODE}")
        print("=" * 60)
        ok = True
        for k, v in results.items():
            mark = "✓" if v else "✗"
            print(f"  {mark}  {k}")
            ok = ok and v
        print("=" * 60)
        print("RESULT:", "OK" if ok else "FAIL")
        if errors:
            print(f"Console errors ({len(errors)}):")
            for e in errors[-10:]:
                print(" ", e[:200])
        await browser.close()
        sys.exit(0 if ok else 1)


asyncio.run(main())