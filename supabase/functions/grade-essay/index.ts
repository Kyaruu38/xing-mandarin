import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const MODEL = "claude-sonnet-5";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function buildRubric(level: number, task: string, extra: Record<string, unknown>): string {
  const base = `你是一位严格但公正的 HSK ${level} 级写作阅卷老师，按官方评分标准给分。`;
  let crit = "";
  if (task === "make_sentence") {
    crit = `任务类型：用指定词语造句。检查：(1) 是否正确使用了词语「${extra.word}」；(2) 语法是否正确、句子是否完整通顺、意思是否清楚。`;
  } else if (task === "short_essay") {
    const words = (extra.required_words as string[] | undefined)?.join("、") ?? "";
    crit = `任务类型：写一篇约 ${extra.min_chars ?? 80} 字的短文。检查：(1) 是否使用了全部指定词语（${words}）；(2) 字数是否达标；(3) 内容是否连贯、有条理；(4) 语法和词汇是否准确。`;
  } else if (task === "summary") {
    crit = `任务类型：缩写。学生需把原文缩写成约 ${extra.target_chars ?? 150} 字。检查：(1) 是否忠实复述原文主要内容；(2) 是否简洁、没有多余细节；(3) 语言是否通顺；(4) 缩写不应加入个人观点或评论，若加入则扣分。`;
  }
  return `${base}
${crit}

严格只输出以下 JSON（不要 markdown 代码块，不要任何多余文字）：
{"score":<0-100 整数>,"band":"<优秀|良好|合格|不合格>","summary":"<用印尼语写 1-2 句总评>","errors":[{"original":"<原文片段>","correction":"<修改建议>","reason":"<用印尼语简短解释>"}],"corrected_text":"<修改后的完整版本>","strengths":["<印尼语，优点>"],"suggestions":["<印尼语，改进建议>"]}`;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const json = (obj: unknown, status = 200) =>
    new Response(JSON.stringify(obj), { status, headers: { ...cors, "content-type": "application/json" } });

  try {
    const b = await req.json();
    const { hsk_level, task_type, prompt, required_words, word, article,
            target_chars, min_chars, student_text, question_id, set_id } = b;

    if (!student_text || !String(student_text).trim())
      return json({ error: "作答内容为空 / Jawaban kosong" }, 400);

    const system = buildRubric(Number(hsk_level), String(task_type),
      { word, required_words, target_chars, min_chars });

    let userMsg = `【题目要求】\n${prompt ?? ""}\n`;
    if (word) userMsg += `【指定词语】${word}\n`;
    if (Array.isArray(required_words) && required_words.length) userMsg += `【必须使用的词语】${required_words.join("、")}\n`;
    if (article) userMsg += `【原文】\n${article}\n`;
    userMsg += `\n【学生的作答】\n${student_text}`;

    const aiResp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({ model: MODEL, max_tokens: 3000, system, messages: [{ role: "user", content: userMsg }] }),
    });

    if (!aiResp.ok) return json({ error: "AI grading gagal", detail: await aiResp.text() }, 502);

    const data = await aiResp.json();
    const raw = (data.content ?? [])
      .filter((blk: { type: string }) => blk.type === "text")
      .map((blk: { text: string }) => blk.text)
      .join("").trim();

    let grade: Record<string, unknown>;
    try {
      grade = JSON.parse(raw.replace(/^```json\s*/i, "").replace(/```$/, "").trim());
    } catch {
      return json({ error: "Gagal parse hasil AI", raw }, 502);
    }

    try {
      const auth = req.headers.get("Authorization");
      if (auth) {
        const sb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: auth } } });
        await sb.from("essay_submissions").insert({
          set_id, question_id, student_text,
          ai_score: grade.score ?? null, ai_feedback: grade,
        });
      }
    } catch (_e) { /* abaikan */ }

    return json(grade);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
