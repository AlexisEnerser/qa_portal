import httpx
from app.config import get_settings
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.keys import Keys
import base64
import time
import logging

logger = logging.getLogger(__name__)
settings = get_settings()

TOKEN_EXPIRY_SECONDS = 50 * 60  # 50 minutos (igual que el script original)

class QengineService:
    def __init__(self):
        self.client_id = settings.zoho_client_id
        self.client_secret = settings.zoho_client_secret
        self.refresh_token = settings.zoho_refresh_token
        self.zoho_email = settings.zoho_email
        self.zoho_password = settings.zoho_password
        self.base_url = "https://qengine.zoho.com/api/v1/enerserdev"
        self._access_token = None
        self._token_timestamp = 0.0

    async def get_access_token(self):
        """
        Devuelve un token válido usando caché de 50 min (igual que el flujo N8N original).
        Solo refresca si el token expiró o no existe.
        """
        now = time.time()
        if self._access_token and (now - self._token_timestamp) < TOKEN_EXPIRY_SECONDS:
            return self._access_token

        url = "https://accounts.zoho.com/oauth/v2/token"
        params = {
            "refresh_token": self.refresh_token,
            "client_id": self.client_id,
            "client_secret": self.client_secret,
            "grant_type": "refresh_token"
        }
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(url, params=params)
                response.raise_for_status()
                data = response.json()
                self._access_token = data.get("access_token")
                self._token_timestamp = time.time()
                logger.info("Token de Zoho QEngine refrescado.")
                return self._access_token
            except Exception as e:
                logger.error(f"Error refrescando token de Zoho: {e}")
                return None

    async def get_test_suites(self, project_id: str):
        token = await self.get_access_token()
        url = f"{self.base_url}/projects/{project_id}/testsuites"
        headers = {"Authorization": f"Bearer {token}"}
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(url, headers=headers)
                response.raise_for_status()
                return response.json()
            except Exception as e:
                logger.error(f"Error consultando suites de Zoho: {e}")
                return []

    async def get_test_results(self, project_id: str, test_run_id: str):
        token = await self.get_access_token()
        url = f"{self.base_url}/projects/{project_id}/testcaseresult"
        params = {"executedenvironment_id": test_run_id, "startIndex": 1}
        headers = {"Authorization": f"Bearer {token}"}
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(url, headers=headers, params=params)
                response.raise_for_status()
                return response.json()
            except Exception as e:
                logger.error(f"Error consultando resultados de Zoho: {e}")
                return {}

    async def get_test_result_detail(self, project_id: str, result_id: str):
        """
        Obtiene el detalle de un resultado individual para extraer capturas de pantalla
        desde statementresult[].screenshot (igual que consult_zoho_Qengine_test_result.py).
        """
        token = await self.get_access_token()
        url = f"{self.base_url}/projects/{project_id}/testcaseresult/{result_id}"
        headers = {"Authorization": f"Bearer {token}"}
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(url, headers=headers)
                response.raise_for_status()
                data = response.json()
                image_items = []
                for stmt in data.get("testcaseresult", {}).get("statementresult", []):
                    screenshot = stmt.get("screenshot", "")
                    if not screenshot or "fileId=null" in screenshot:
                        continue
                    try:
                        file_id = screenshot.split("fileId=")[1]
                    except IndexError:
                        continue
                    image_items.append({
                        "id": file_id,
                        "url": f"https://qengine.zoho.com{screenshot}"
                    })
                return image_items
            except Exception as e:
                logger.error(f"Error consultando detalle de resultado {result_id}: {e}")
                return []

    def _extract_image_with_selenium(self, url: str):
        """
        Utiliza Selenium (Headless) para descargar una imagen y convertirla a Base64.
        Requiere que el entorno tenga Chrome/Chromium instalado.
        """
        chrome_options = Options()
        chrome_options.add_argument("--headless")
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")
        
        # En Linux/Docker, chromium-driver suele estar en /usr/bin/chromedriver
        service = Service("/usr/bin/chromedriver")
        
        driver = None
        try:
            driver = webdriver.Chrome(options=chrome_options, service=service)
            
            # El proceso original requería un login
            # Este es un paso crítico. Según extrae_imagenes.py:
            driver.get(url)
            time.sleep(2)
            
            # Si redirige a login, intentamos ingresar (usando credenciales de .env en el futuro)
            # Por ahora emulamos la lógica del script original:
            try:
                # Esperar campo de login
                username_field = WebDriverWait(driver, 5).until(
                    EC.presence_of_element_located((By.ID, "login_id"))
                )
                username_field.send_keys(self.zoho_email)
                username_field.send_keys(Keys.RETURN)
                time.sleep(2)
                password_field = WebDriverWait(driver, 5).until(
                    EC.presence_of_element_located((By.ID, "password"))
                )
                password_field.send_keys(self.zoho_password)
                password_field.send_keys(Keys.RETURN)
                time.sleep(3)
                # Volver a la URL original tras login
                driver.get(url)
            except:
                pass # Ya estábamos logueados o no se requirió

            # Extraer imagen vía JS
            base64_image = driver.execute_script("""
                var img = document.querySelector('img');
                if (!img) return null;
                var canvas = document.createElement('canvas');
                var ctx = canvas.getContext('2d');
                canvas.width = img.naturalWidth || img.width;
                canvas.height = img.naturalHeight || img.height;
                ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
                return canvas.toDataURL('image/jpeg', 0.8);
            """)
            
            if base64_image:
                return base64_image.split(',')[1]
            return None
        except Exception as e:
            logger.error(f"Error Selenium en imagen {url}: {e}")
            return None
        finally:
            if driver:
                driver.quit()

    async def process_images(self, items: list):
        """
        Procesa una lista de items con {'id': id, 'url': url} para obtener base64.
        """
        results = []
        for item in items:
            img_id = item.get("id")
            img_url = item.get("url")
            base64_data = self._extract_image_with_selenium(img_url)
            results.append({
                "id": img_id,
                "url": img_url,
                "imageBase64": base64_data or ""
            })
        return results

qengine_service = QengineService()
