# generate_listening_audio.py — jalanin LOKAL sekali doang (bukan di server)
# pip install edge-tts supabase pydub  (+ install ffmpeg buat gabung dialog)
#
# Sebelum jalanin, set env var dulu (JANGAN hardcode service key di file ini):
#   export SUPABASE_SERVICE_KEY="..."      (bash)
#   $env:SUPABASE_SERVICE_KEY = "..."      (PowerShell)
import asyncio, os, random, edge_tts
from pydub import AudioSegment
from supabase import create_client

SUPABASE_URL = "https://xzgvhzmmqbijpbrhagjf.supabase.co"
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")
if not SUPABASE_KEY:
    raise SystemExit("Set SUPABASE_SERVICE_KEY dulu (env var) sebelum jalanin script ini.")

BUCKET       = "listening-audio"
FEMALE_VOICES = ["zh-CN-XiaoxiaoNeural", "zh-CN-XiaoyiNeural"]
MALE_VOICES   = ["zh-CN-YunxiNeural", "zh-CN-YunjianNeural", "zh-CN-YunxiaNeural"]
Q_VOICE       = "zh-CN-YunyangNeural"

sb = create_client(SUPABASE_URL, SUPABASE_KEY)

async def synth_line(text, speaker, voice, tmp):
    for attempt in range(3):
        try:
            await asyncio.wait_for(
                edge_tts.Communicate(text, voice, rate="-25%").save(tmp),
                timeout=30
            )
            return
        except Exception as e:
            if attempt == 2:
                raise
            await asyncio.sleep(2)

async def build_clip(clip):
    # clip = {"path": "h3/set1/q2.mp3", "lines": [["A","你好"],["B","你好啊"]]}
    if not clip.get("lines"):
        print(f"⚠️  skip {clip['path']}: lines kosong")
        return "skipped"

    voice_map = {"A": random.choice(FEMALE_VOICES), "B": random.choice(MALE_VOICES), "Q": Q_VOICE}

    parts = []
    for i, (spk, txt) in enumerate(clip["lines"]):
        tmp = f"_tmp_{i}.mp3"
        try:
            await synth_line(txt, spk, voice_map[spk], tmp)
            parts.append(AudioSegment.from_mp3(tmp))
        finally:
            if os.path.exists(tmp):
                os.remove(tmp)

    # gabung + kasih jeda 400ms antar kalimat
    audio = parts[0]
    for p in parts[1:]:
        audio += AudioSegment.silent(400) + p

    out = "out.mp3"
    try:
        audio.export(out, format="mp3", bitrate="64k")  # 64k biar tone tetep jelas buat listening test
        with open(out, "rb") as f:
            sb.storage.from_(BUCKET).upload(clip["path"], f,
                {"content-type": "audio/mpeg", "upsert": "true"})
    finally:
        if os.path.exists(out):
            os.remove(out)

    print("✅", clip["path"])
    return "ok"

async def main():
    import json
    clips = json.load(open("clips.json", encoding="utf-8"))   # daftar semua klip

    skipped, failed = [], []
    for c in clips:
        try:
            result = await build_clip(c)
            if result == "skipped":
                skipped.append(c.get("path", "?"))
        except Exception as e:
            print(f"❌ {c.get('path', '?')}: {e}")
            failed.append(c.get("path", "?"))
        await asyncio.sleep(0.3)  # jeda kecil biar edge-tts nggak ke-throttle pas batch ratusan

    print("\n=== Ringkasan ===")
    print(f"Total: {len(clips)}  Berhasil: {len(clips) - len(failed) - len(skipped)}  "
          f"Skip: {len(skipped)}  Gagal: {len(failed)}")
    if skipped:
        print("Di-skip (lines kosong):")
        for p in skipped:
            print(f"  - {p}")
    if failed:
        print("Gagal (bisa di-retry manual):")
        for p in failed:
            print(f"  - {p}")

asyncio.run(main())
