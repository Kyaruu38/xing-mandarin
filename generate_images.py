import requests, urllib.parse, os, time, json
from supabase import create_client

SUPABASE_URL = "https://xzgvhzmmqbijpbrhagjf.supabase.co"
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")
if not SUPABASE_KEY:
    raise SystemExit("Set SUPABASE_SERVICE_KEY dulu (env var) sebelum jalanin script ini.")
BUCKET = "listening-images"
STYLE  = ", clean flat vector illustration, simple, minimal, white background, no text, no words"

sb = create_client(SUPABASE_URL, SUPABASE_KEY)

def gen(item):
    prompt = item["prompt"] + STYLE
    url = f"https://image.pollinations.ai/prompt/{urllib.parse.quote(prompt)}?width=512&height=512&nologo=true"
    for attempt in range(3):
        try:
            r = requests.get(url, timeout=120)
            r.raise_for_status()
            data = r.content
            if len(data) < 2000:
                raise Exception("gambar terlalu kecil, mungkin gagal generate")
            tmp = "_img.jpg"
            with open(tmp, "wb") as f:
                f.write(data)
            with open(tmp, "rb") as f:
                sb.storage.from_(BUCKET).upload(item["path"], f,
                    {"content-type": "image/jpeg", "upsert": "true"})
            os.remove(tmp)
            print("OK", item["path"], f"({len(data)//1024}KB)")
            return "ok"
        except Exception as e:
            if attempt == 2:
                print("FAIL", item["path"], e)
                return "fail"
            time.sleep(3)

def main():
    items = json.load(open("images.json", encoding="utf-8"))
    ok = fail = 0
    for it in items:
        r = gen(it)
        ok += (r == "ok"); fail += (r == "fail")
        time.sleep(16)
    print(f"\n=== Total:{len(items)}  OK:{ok}  Fail:{fail} ===")

main()
