"""E2E: brouillon → validation d'un paiement + annulation avec recalcul KPI."""
import asyncio
import json
import os
from pathlib import Path

from playwright.async_api import async_playwright

BASE = "http://localhost:8080"
SHOTS = Path(__file__).parent / "screenshots"
SHOTS.mkdir(parents=True, exist_ok=True)


async def restore_session(context, page):
    key = os.environ.get("LOVABLE_BROWSER_SUPABASE_STORAGE_KEY")
    sess = os.environ.get("LOVABLE_BROWSER_SUPABASE_SESSION_JSON")
    cookies_json = os.environ.get("LOVABLE_BROWSER_SUPABASE_COOKIES_JSON")
    if cookies_json:
        cookies = json.loads(cookies_json)
        for c in cookies:
            c["url"] = BASE
        await context.add_cookies(cookies)
    await page.goto(BASE)
    if key and sess:
        await page.evaluate(
            f"window.localStorage.setItem({json.dumps(key)}, {json.dumps(sess)})"
        )


async def flow_brouillon_validation(page, client_id: str):
    await page.goto(f"{BASE}/paiements/nouveau?clientId={client_id}")
    await page.wait_for_load_state("networkidle")
    await page.screenshot(path=str(SHOTS / "01_form.png"))
    await page.get_by_role("radio").first.check()
    await page.get_by_label("Montant reçu", exact=False).fill("10000")
    await page.get_by_label("Référence", exact=False).fill("E2E-TEST-001")
    await page.get_by_role("button", name="Prévisualiser").click()
    await page.wait_for_selector("text=Récapitulatif")
    await page.screenshot(path=str(SHOTS / "02_recap.png"))
    await page.get_by_role("button", name="Valider").click()
    await page.wait_for_url("**/paiements/**", timeout=10_000)
    await page.screenshot(path=str(SHOTS / "03_created.png"))


async def flow_annulation(page, client_id: str, paiement_id: str):
    await page.goto(f"{BASE}/clients/{client_id}")
    await page.wait_for_load_state("networkidle")
    encours_avant = await page.locator('[data-kpi="encours"]').inner_text()
    await page.screenshot(path=str(SHOTS / "04_kpi_avant.png"))
    await page.goto(f"{BASE}/paiements/{paiement_id}")
    await page.get_by_role("button", name="Annuler ce paiement").click()
    await page.get_by_label("Raison", exact=False).fill("Test E2E - annulation")
    await page.get_by_role("button", name="Confirmer l'annulation").click()
    await page.wait_for_selector("text=Annulé", timeout=10_000)
    await page.screenshot(path=str(SHOTS / "05_annule.png"))
    await page.goto(f"{BASE}/clients/{client_id}")
    await page.wait_for_load_state("networkidle")
    encours_apres = await page.locator('[data-kpi="encours"]').inner_text()
    await page.screenshot(path=str(SHOTS / "06_kpi_apres.png"))
    assert encours_avant != encours_apres, "encours doit changer après annulation"


async def main():
    client_id = os.environ.get("E2E_CLIENT_ID")
    if not client_id:
        raise SystemExit("E2E_CLIENT_ID requis")
    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=True)
        context = await browser.new_context(viewport={"width": 1280, "height": 1800})
        page = await context.new_page()
        await restore_session(context, page)
        await flow_brouillon_validation(page, client_id)
        paiement_id = page.url.rstrip("/").split("/")[-1]
        await flow_annulation(page, client_id, paiement_id)
        await browser.close()


if __name__ == "__main__":
    asyncio.run(main())