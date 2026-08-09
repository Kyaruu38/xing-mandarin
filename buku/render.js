const fs = require('fs');
const d = require('docx');
const { Document, Packer, Paragraph, TextRun, HeadingLevel, AlignmentType, Table, TableRow,
        TableCell, WidthType, ShadingType, BorderStyle, PageBreak, LevelFormat, Footer,
        PageNumber, TableOfContents, convertInchesToTwip } = d;

const GOLD = 'B8892B', NAVY = '10243F', INK = '1F2937', MUTED = '6B7280';
const HANZI = 'Microsoft YaHei';

function P(text, o={}){ return new Paragraph({ ...o, children:[ new TextRun({ text, ...(o.run||{}) }) ] }); }
function h1(t){ return new Paragraph({ heading:HeadingLevel.HEADING_1, spacing:{before:400,after:200}, children:[new TextRun({text:t, color:NAVY, bold:true, size:36})] }); }
function h2(t){ return new Paragraph({ heading:HeadingLevel.HEADING_2, spacing:{before:320,after:140}, children:[new TextRun({text:t, color:GOLD, bold:true, size:26})] }); }
function h3(t){ return new Paragraph({ heading:HeadingLevel.HEADING_3, spacing:{before:220,after:100}, children:[new TextRun({text:t, color:NAVY, bold:true, size:22})] }); }
function body(t){ return new Paragraph({ spacing:{after:120}, alignment:AlignmentType.JUSTIFIED, children:[new TextRun({text:t, size:21, color:INK})] }); }
function zh(t, sz){ return new TextRun({ text:t, font:HANZI, size:sz||24, color:INK }); }
function py(t){ return new TextRun({ text:t, italics:true, size:19, color:MUTED }); }

function bullets(items){
  return items.map(x => new Paragraph({ numbering:{reference:'bul', level:0}, spacing:{after:60},
    children:[new TextRun({text:x, size:21, color:INK})] }));
}

function cell(children, w, opts={}){
  return new TableCell({ width:{size:w, type:WidthType.DXA}, margins:{top:60,bottom:60,left:110,right:110},
    shading: opts.shade ? {type:ShadingType.CLEAR, fill:opts.shade, color:'auto'} : undefined,
    children });
}
function tbl(rows, widths){
  return new Table({ columnWidths:widths, width:{size:widths.reduce((a,b)=>a+b,0), type:WidthType.DXA},
    borders:{ top:{style:BorderStyle.SINGLE,size:2,color:'DDDDDD'}, bottom:{style:BorderStyle.SINGLE,size:2,color:'DDDDDD'},
              left:{style:BorderStyle.SINGLE,size:2,color:'DDDDDD'}, right:{style:BorderStyle.SINGLE,size:2,color:'DDDDDD'},
              insideHorizontal:{style:BorderStyle.SINGLE,size:2,color:'EEEEEE'}, insideVertical:{style:BorderStyle.SINGLE,size:2,color:'EEEEEE'} },
    rows });
}

function vocabTable(vocab){
  const W = [560, 1400, 1500, 2900, 2900];
  const head = new TableRow({ tableHeader:true, children:[
    cell([P('No',{run:{bold:true,size:18,color:'FFFFFF'}})], W[0], {shade:NAVY}),
    cell([P('Hanzi',{run:{bold:true,size:18,color:'FFFFFF'}})], W[1], {shade:NAVY}),
    cell([P('Pinyin',{run:{bold:true,size:18,color:'FFFFFF'}})], W[2], {shade:NAVY}),
    cell([P('English',{run:{bold:true,size:18,color:'FFFFFF'}})], W[3], {shade:NAVY}),
    cell([P('Indonesia',{run:{bold:true,size:18,color:'FFFFFF'}})], W[4], {shade:NAVY})
  ]});
  const rows = vocab.map((v,i)=> new TableRow({ children:[
    cell([P(String(i+1),{run:{size:18,color:MUTED}})], W[0], i%2? {shade:'FAFAFA'}:{}),
    cell([new Paragraph({children:[zh(v[0])]})], W[1], i%2? {shade:'FAFAFA'}:{}),
    cell([new Paragraph({children:[py(v[1])]})], W[2], i%2? {shade:'FAFAFA'}:{}),
    cell([P(v[2],{run:{size:19}})], W[3], i%2? {shade:'FAFAFA'}:{}),
    cell([P(v[3],{run:{size:19}})], W[4], i%2? {shade:'FAFAFA'}:{})
  ]}));
  return tbl([head, ...rows], W);
}

function exprBlock(e){
  return [
    new Paragraph({ spacing:{before:120, after:20}, children:[ zh(e[0], 26) ]}),
    new Paragraph({ spacing:{after:20}, children:[ py(e[1]) ]}),
    new Paragraph({ spacing:{after:20}, children:[ new TextRun({text:e[2], size:19, color:INK}) ]}),
    new Paragraph({ spacing:{after:140}, children:[ new TextRun({text:e[3], size:19, color:GOLD}) ]})
  ];
}

function dialogue(dl, idx){
  const out = [ h3('Dialogue ' + idx),
    new Paragraph({ spacing:{after:140}, children:[ new TextRun({text:'Situasi: '+dl.situasi, size:19, italics:true, color:MUTED}) ]}) ];
  dl.lines.forEach(l=>{
    out.push(new Paragraph({ spacing:{before:100, after:16}, indent:{left:convertInchesToTwip(0.15)},
      children:[ new TextRun({text:l[0]+': ', bold:true, size:22, color:GOLD}), zh(l[1], 26) ]}));
    out.push(new Paragraph({ spacing:{after:16}, indent:{left:convertInchesToTwip(0.45)}, children:[ py(l[2]) ]}));
    out.push(new Paragraph({ spacing:{after:16}, indent:{left:convertInchesToTwip(0.45)}, children:[ new TextRun({text:l[3], size:19, color:INK}) ]}));
    out.push(new Paragraph({ spacing:{after:60}, indent:{left:convertInchesToTwip(0.45)}, children:[ new TextRun({text:l[4], size:19, color:MUTED}) ]}));
  });
  return out;
}

function grammarBlock(g, i){
  const out = [ h3(String(i+1) + '. ' + g.point), body(g.penjelasan) ];
  out.push(new Paragraph({ spacing:{before:80, after:100}, shading:{type:ShadingType.CLEAR, fill:'FBF6E9', color:'auto'},
    border:{left:{style:BorderStyle.SINGLE, size:12, color:GOLD, space:8}},
    children:[ new TextRun({text:'Pola:  ', bold:true, size:19, color:NAVY}), new TextRun({text:g.pola, size:20, font:HANZI, color:INK}) ]}));
  g.contoh.forEach(c=>{
    out.push(new Paragraph({ spacing:{before:90, after:14}, indent:{left:convertInchesToTwip(0.2)}, children:[ zh(c[0], 24) ]}));
    out.push(new Paragraph({ spacing:{after:14}, indent:{left:convertInchesToTwip(0.2)}, children:[ py(c[1]) ]}));
    out.push(new Paragraph({ spacing:{after:60}, indent:{left:convertInchesToTwip(0.2)}, children:[ new TextRun({text:c[2], size:19, color:INK}) ]}));
  });
  out.push(new Paragraph({ spacing:{before:120, after:180},
    children:[ new TextRun({text:'Catatan: ', bold:true, size:19, color:GOLD}), new TextRun({text:g.tips, size:19, color:INK, italics:true}) ]}));
  return out;
}

function splitPara(text, mk){
  return String(text).split('\n').map(t => t.trim()).filter(t => t.length)
    .map(t => new Paragraph({ spacing:{after:100}, alignment:AlignmentType.JUSTIFIED, children:[ mk(t) ] }));
}
function readingBlock(r){
  const out = [ h2('Reading Passage'),
    new Paragraph({ spacing:{after:120}, children:[ zh(r.title_zh, 28), new TextRun({text:'   '+r.title_id, size:19, color:MUTED, italics:true}) ]}) ];
  out.push(...splitPara(r.zh, t => zh(t, 24)));
  out.push(new Paragraph({ spacing:{after:60}, children:[] }));
  out.push(...splitPara(r.py, t => py(t)));
  out.push(new Paragraph({ spacing:{after:60}, children:[] }));
  out.push(...splitPara(r.en, t => new TextRun({text:t, size:21, color:INK})));
  out.push(new Paragraph({ spacing:{after:60}, children:[] }));
  out.push(...splitPara(r.id, t => new TextRun({text:t, size:21, color:INK})));
  return out;
}

function exBlock(x){
  const out = [ h2('Exercises') ];
  out.push(h3('Part A · Listening'));
  out.push(body('Part 1 — True or False. Dengarkan percakapan, lalu tentukan pernyataan berikut benar (B) atau salah (S).'));
  x.listening_tf.forEach((q,i)=> out.push(new Paragraph({ spacing:{after:70}, children:[
    new TextRun({text:(i+1)+'.  ', size:19}), zh(q[0], 22), new TextRun({text:'    (  B  /  S  )', size:19, color:MUTED}) ]})));
  out.push(body('Part 2 — Multiple Choice. Dengarkan percakapan, lalu pilih jawaban yang tepat.'));
  x.listening_mc.forEach((q,i)=>{
    out.push(new Paragraph({ spacing:{before:100, after:40}, children:[ new TextRun({text:(i+3)+'.  ', size:19}), zh(q.q, 22) ]}));
    q.c.forEach((c,j)=> out.push(new Paragraph({ spacing:{after:20}, indent:{left:convertInchesToTwip(0.3)},
      children:[ new TextRun({text:'ABC'[j]+'. ', size:19, color:MUTED}), zh(c, 22) ]})));
  });
  out.push(body('Part 3 — Answer the Question. Dengarkan bacaan, lalu jawab dengan kalimat lengkap.'));
  x.listening_open.forEach((q,i)=> out.push(new Paragraph({ spacing:{after:200}, children:[
    new TextRun({text:(i+5)+'.  ', size:19}), zh(q[0], 22), new TextRun({text:'   ______________________________', size:19, color:MUTED}) ]})));

  out.push(h3('Part B · Reading'));
  out.push(body('Part 1 — Matching. Pasangkan setiap kalimat dengan tanggapan yang tepat.'));
  x.reading_match.pilihan.forEach(p=> out.push(new Paragraph({ spacing:{after:20}, indent:{left:convertInchesToTwip(0.2)}, children:[ zh(p, 22) ]})));
  x.reading_match.soal.forEach((s,i)=> out.push(new Paragraph({ spacing:{before:i?40:120, after:20},
    children:[ new TextRun({text:(i+1)+'.  ', size:19}), zh(s, 22), new TextRun({text:'   (      )', size:19, color:MUTED}) ]})));
  out.push(body('Part 2 — Multiple Choice.'));
  x.reading_mc.forEach((q,i)=>{
    out.push(new Paragraph({ spacing:{before:100, after:40}, children:[ new TextRun({text:(i+6)+'.  ', size:19}), zh(q.q, 22) ]}));
    q.c.forEach((c,j)=> out.push(new Paragraph({ spacing:{after:20}, indent:{left:convertInchesToTwip(0.3)},
      children:[ new TextRun({text:'ABC'[j]+'. ', size:19, color:MUTED}), zh(c, 22) ]})));
  });
  out.push(body('Part 3 — Reorder the Events. Urutkan tiga kejadian berikut sesuai isi bacaan.'));
  x.reading_order.kalimat.forEach(k=> out.push(new Paragraph({ spacing:{after:20}, indent:{left:convertInchesToTwip(0.2)}, children:[ zh(k, 22) ]})));
  out.push(new Paragraph({ spacing:{before:80, after:200}, children:[ new TextRun({text:'Urutan:  ______  →  ______  →  ______', size:19, color:MUTED}) ]}));

  out.push(h3('Part C · Writing'));
  out.push(body('Part 1 — Rearrange the Words. Susun kata-kata berikut menjadi kalimat yang benar.'));
  x.writing_rearrange.forEach((q,i)=>{
    out.push(new Paragraph({ spacing:{before:90, after:20}, children:[ new TextRun({text:(i+1)+'.  ', size:19}), zh(q[0].join('   /   '), 22) ]}));
    out.push(new Paragraph({ spacing:{after:60}, indent:{left:convertInchesToTwip(0.3)}, children:[ new TextRun({text:'______________________________________', size:19, color:MUTED}) ]}));
  });
  out.push(body('Part 2 — Sentence Creation. Buat satu kalimat untuk setiap kata berikut.'));
  x.writing_create.kata.forEach((k,i)=>{
    out.push(new Paragraph({ spacing:{before:90, after:20}, children:[ new TextRun({text:(i+1)+'.  ', size:19}), zh(k, 24) ]}));
    out.push(new Paragraph({ spacing:{after:60}, indent:{left:convertInchesToTwip(0.3)}, children:[ new TextRun({text:'______________________________________', size:19, color:MUTED}) ]}));
  });

  out.push(h3('Part D · Speaking'));
  out.push(body('Part 1 — Role Play.'));
  out.push(new Paragraph({ spacing:{after:60}, children:[ new TextRun({text:'Situasi: ', bold:true, size:19, color:NAVY}), new TextRun({text:x.speaking_roleplay.situasi, size:19}) ]}));
  out.push(new Paragraph({ spacing:{after:60}, children:[ new TextRun({text:'Tujuan komunikasi: ', bold:true, size:19, color:NAVY}), new TextRun({text:x.speaking_roleplay.tujuan, size:19}) ]}));
  out.push(new Paragraph({ spacing:{after:160}, children:[ new TextRun({text:'Wajib dipakai: ', bold:true, size:19, color:NAVY}), zh(x.speaking_roleplay.wajib.join('  ·  '), 22) ]}));
  out.push(body('Part 2 — One-minute Speaking Video.'));
  out.push(new Paragraph({ spacing:{after:60}, children:[ new TextRun({text:'Tema: ', bold:true, size:19, color:NAVY}), new TextRun({text:x.speaking_video.tema, size:19}) ]}));
  out.push(new Paragraph({ spacing:{after:160}, children:[ new TextRun({text:'Wajib dipakai: ', bold:true, size:19, color:NAVY}), zh(x.speaking_video.wajib.join('  ·  '), 22) ]}));
  return out;
}

function chapter(c){
  const out = [ new Paragraph({ children:[new PageBreak()] }),
    new Paragraph({ spacing:{after:40}, children:[ new TextRun({text:'CHAPTER '+c.no, bold:true, size:20, color:GOLD, characterSpacing:40}) ]}),
    h1(c.title_en),
    new Paragraph({ spacing:{after:220}, children:[ new TextRun({text:c.title_id, size:22, color:MUTED, italics:true}) ]}) ];
  if(c.note) out.push(new Paragraph({ spacing:{after:200}, shading:{type:ShadingType.CLEAR, fill:'FBF6E9', color:'auto'},
    border:{left:{style:BorderStyle.SINGLE, size:12, color:GOLD, space:8}},
    children:[ new TextRun({text:c.note, size:19, italics:true, color:INK}) ]}));
  out.push(h2('Learning Objectives'));
  out.push(body('Setelah menyelesaikan chapter ini, kamu mampu:'));
  out.push(...bullets(c.objectives));
  if(c.primer && c.primer.length){
    out.push(h2('Dasar yang Perlu Dipahami Dulu'));
    c.primer.forEach(pr=>{ out.push(h3(pr.h)); out.push(body(pr.p)); });
  }
  out.push(h2('New Vocabulary'));
  out.push(body('Total ' + c.vocab.length + ' kosakata baru.'));
  out.push(vocabTable(c.vocab));
  out.push(h2('Useful Expressions'));
  c.expressions.forEach(e=> out.push(...exprBlock(e)));
  out.push(h2('Dialogues'));
  c.dialogues.forEach((dl,i)=> out.push(...dialogue(dl, i+1)));
  out.push(...readingBlock(c.reading));
  out.push(h2('Grammar Focus'));
  c.grammar.forEach((g,i)=> out.push(...grammarBlock(g, i)));
  out.push(...exBlock(c.exercises));
  return out;
}


function appendix(chs){
  const out = [ new Paragraph({ children:[new PageBreak()] }), h1('Appendix') ];

  out.push(...extrasBlock());

  out.push(new Paragraph({ children:[new PageBreak()] }));
  out.push(h2('Listening Scripts'));
  out.push(body('Transkrip untuk Part A setiap chapter. Bacaan yang dipakai di Part 3 adalah Reading Passage chapter tersebut.'));
  chs.forEach(c=>{
    out.push(h3('Chapter ' + c.no + ' — ' + c.title_en));
    c.dialogues.forEach((dl,i)=>{
      out.push(new Paragraph({ spacing:{before:120, after:40}, children:[ new TextRun({text:'Dialogue '+(i+1)+' — '+dl.situasi, size:18, italics:true, color:MUTED}) ]}));
      dl.lines.forEach(l=> out.push(new Paragraph({ spacing:{after:20}, indent:{left:convertInchesToTwip(0.2)},
        children:[ new TextRun({text:l[0]+': ', bold:true, size:19, color:GOLD}), zh(l[1], 22) ]})));
    });
    out.push(new Paragraph({ spacing:{before:120, after:40}, children:[ new TextRun({text:'Reading Passage — '+c.reading.title_id, size:18, italics:true, color:MUTED}) ]}));
    out.push(...splitPara(c.reading.zh, t => zh(t, 22)));
  });

  out.push(new Paragraph({ children:[new PageBreak()] }));
  out.push(h2('Answer Key'));
  chs.forEach(c=>{
    const x = c.exercises;
    out.push(h3('Chapter ' + c.no));
    const line = (label, val) => new Paragraph({ spacing:{after:50},
      children:[ new TextRun({text:label+'  ', bold:true, size:19, color:NAVY}), new TextRun({text:val, size:19, color:INK}) ]});
    out.push(line('Part A1 (True/False):', x.listening_tf.map((q,i)=>(i+1)+'. '+q[1]).join('   ')));
    out.push(line('Part A2 (Multiple Choice):', x.listening_mc.map((q,i)=>(i+3)+'. '+q.a).join('   ')));
    x.listening_open.forEach((q,i)=> out.push(new Paragraph({ spacing:{after:50},
      children:[ new TextRun({text:'Part A3:  '+(i+5)+'. ', bold:true, size:19, color:NAVY}), zh(q[1], 22) ]})));
    out.push(line('Part B1 (Matching):', x.reading_match.kunci.map((k,i)=>(i+1)+'. '+k).join('   ')));
    out.push(line('Part B2 (Multiple Choice):', x.reading_mc.map((q,i)=>(i+6)+'. '+q.a).join('   ')));
    out.push(line('Part B3 (Reorder):', x.reading_order.kunci));
    x.writing_rearrange.forEach((q,i)=> out.push(new Paragraph({ spacing:{after:50},
      children:[ new TextRun({text:'Part C1:  '+(i+1)+'. ', bold:true, size:19, color:NAVY}), zh(q[1], 22) ]})));
    out.push(new Paragraph({ spacing:{before:60, after:40}, children:[ new TextRun({text:'Part C2 (Sentence Creation) — contoh jawaban, jawaban lain yang benar tetap diterima:', bold:true, size:19, color:NAVY}) ]}));
    x.writing_create.contoh_jawaban.forEach((a,i)=> out.push(new Paragraph({ spacing:{after:30}, indent:{left:convertInchesToTwip(0.25)},
      children:[ new TextRun({text:(i+1)+'. ', size:19, color:MUTED}), zh(a, 22) ]})));
    out.push(new Paragraph({ spacing:{before:60, after:180}, children:[ new TextRun({text:'Part D (Speaking): dinilai dengan rubrik di bawah, tidak ada kunci jawaban tunggal.', size:19, italics:true, color:MUTED}) ]}));
  });

  out.push(new Paragraph({ children:[new PageBreak()] }));
  out.push(h2('Speaking Assessment Rubric'));
  out.push(body('Setiap tugas Speaking dinilai pada empat aspek, masing-masing 1 sampai 5. Total nilai 20.'));
  const RW = [2600, 6660];
  const rub = [
    ['Pelafalan & nada','Nada empat-empatnya benar dan mudah dipahami penutur asli tanpa harus mengulang.'],
    ['Kosakata wajib','Semua kata yang diwajibkan dipakai, dan dipakai dengan benar — bukan sekadar diselipkan.'],
    ['Kelancaran','Bicara mengalir; jeda berpikir wajar dan tidak memutus kalimat di tengah.'],
    ['Ketepatan tugas','Isi bicaranya menjawab situasi dan tujuan komunikasi yang diminta soal.']
  ];
  out.push(tbl([
    new TableRow({ tableHeader:true, children:[
      cell([P('Aspek',{run:{bold:true,size:18,color:'FFFFFF'}})], RW[0], {shade:NAVY}),
      cell([P('Nilai 5 berarti',{run:{bold:true,size:18,color:'FFFFFF'}})], RW[1], {shade:NAVY}) ]}),
    ...rub.map((r,i)=> new TableRow({ children:[
      cell([P(r[0],{run:{bold:true,size:19}})], RW[0], i%2?{shade:'FAFAFA'}:{}),
      cell([P(r[1],{run:{size:19}})], RW[1], i%2?{shade:'FAFAFA'}:{}) ]}))
  ], RW));

  out.push(new Paragraph({ children:[new PageBreak()] }));
  out.push(h2('Vocabulary Summary'));
  out.push(body('Seluruh kosakata buku ini, diurutkan per chapter.'));
  chs.forEach(c=>{ out.push(h3('Chapter ' + c.no + ' — ' + c.title_en + '  (' + c.vocab.length + ' kata)')); out.push(vocabTable(c.vocab)); });
  return out;
}


function extrasBlock(){
  // Jalur relatif terhadap berkas ini, bukan terhadap direktori kerja -- supaya
  // render.js tetap jalan dipanggil dari mana pun di dalam repo.
  var ex; try { ex = require(require('path').join(__dirname, 'extras.json')); } catch(e){ console.error('extras.json tidak terbaca:', e.message); return []; }
  const out = [ new Paragraph({ children:[new PageBreak()] }), h2('Kumpulan Ungkapan Siap Pakai') ];
  const W4 = [2900, 1900, 2200, 2260];
  function four(title, note, rows){
    out.push(h3(title));
    if(note) out.push(body(note));
    out.push(tbl([
      new TableRow({ tableHeader:true, children:[
        cell([P('Hanzi',{run:{bold:true,size:18,color:'FFFFFF'}})], W4[0], {shade:NAVY}),
        cell([P('Pinyin',{run:{bold:true,size:18,color:'FFFFFF'}})], W4[1], {shade:NAVY}),
        cell([P('English',{run:{bold:true,size:18,color:'FFFFFF'}})], W4[2], {shade:NAVY}),
        cell([P('Indonesia',{run:{bold:true,size:18,color:'FFFFFF'}})], W4[3], {shade:NAVY}) ]}),
      ...rows.map((r,i)=> new TableRow({ children:[
        cell([new Paragraph({children:[zh(r[0], 22)]})], W4[0], i%2?{shade:'FAFAFA'}:{}),
        cell([new Paragraph({children:[py(r[1])]})], W4[1], i%2?{shade:'FAFAFA'}:{}),
        cell([P(r[2],{run:{size:18}})], W4[2], i%2?{shade:'FAFAFA'}:{}),
        cell([P(r[3],{run:{size:18}})], W4[3], i%2?{shade:'FAFAFA'}:{}) ]}))
    ], W4));
  }
  four('Business Mandarin Expressions', 'Ungkapan yang paling sering dipakai di kantor, lintas situasi.', ex.expr);
  four('Business Email Expressions', 'Potongan kalimat baku untuk menyusun email dari pembuka sampai penutup.', ex.email);
  four('Telephone Expressions', 'Urutannya sengaja disusun mengikuti jalannya satu panggilan telepon.', ex.phone);
  out.push(h3('Common Business Abbreviations'));
  out.push(body('Singkatan berikut dipakai apa adanya dalam bahasa Inggris, tapi rekan kerja Tiongkok sering menyebut padanan Mandarinnya. Keduanya perlu kamu kenali.'));
  const WA = [1300, 2400, 2400, 3160];
  out.push(tbl([
    new TableRow({ tableHeader:true, children:[
      cell([P('Singkatan',{run:{bold:true,size:18,color:'FFFFFF'}})], WA[0], {shade:NAVY}),
      cell([P('Hanzi',{run:{bold:true,size:18,color:'FFFFFF'}})], WA[1], {shade:NAVY}),
      cell([P('Pinyin',{run:{bold:true,size:18,color:'FFFFFF'}})], WA[2], {shade:NAVY}),
      cell([P('Arti',{run:{bold:true,size:18,color:'FFFFFF'}})], WA[3], {shade:NAVY}) ]}),
    ...ex.abbr.map((r,i)=> new TableRow({ children:[
      cell([P(r[0],{run:{bold:true,size:19}})], WA[0], i%2?{shade:'FAFAFA'}:{}),
      cell([new Paragraph({children:[zh(r[1], 22)]})], WA[1], i%2?{shade:'FAFAFA'}:{}),
      cell([new Paragraph({children:[py(r[2])]})], WA[2], i%2?{shade:'FAFAFA'}:{}),
      cell([P(r[3],{run:{size:18}})], WA[3], i%2?{shade:'FAFAFA'}:{}) ]}))
  ], WA));
  return out;
}

const chapters = process.argv.slice(3).map(f => JSON.parse(fs.readFileSync(f,'utf8')));
const OUT = process.argv[2];

const cover = [
  new Paragraph({ spacing:{before:2400, after:120}, alignment:AlignmentType.CENTER,
    children:[ new TextRun({text:'XING MANDARIN', bold:true, size:26, color:GOLD, characterSpacing:120}) ]}),
  new Paragraph({ spacing:{after:140, line:640}, alignment:AlignmentType.CENTER,
    children:[ new TextRun({text:'Business Mandarin', bold:true, size:52, color:NAVY}) ]}),
  new Paragraph({ spacing:{after:260, line:640}, alignment:AlignmentType.CENTER,
    children:[ new TextRun({text:'Foundation', bold:true, size:52, color:NAVY}) ]}),
  new Paragraph({ spacing:{after:1200}, alignment:AlignmentType.CENTER,
    children:[ new TextRun({text:'From Beginner to HSK 4 for Workplace Communication', size:22, color:MUTED, italics:true}) ]}),
  new Paragraph({ children:[new PageBreak()] }),
  h1('Tentang Buku Ini'),
  body('Business Mandarin Foundation dirancang untuk orang yang belajar Mandarin karena pekerjaan, bukan karena ujian. Materinya berjalan dari nol sampai setara HSK 4, tapi setiap kosakata, dialog, dan bacaannya diambil dari situasi kerja yang benar-benar terjadi: rapat yang diundur, klien yang menanyakan stok, supplier yang telat kirim, negosiasi harga yang buntu.'),
  body('Bedanya dengan buku HSK biasa ada di konteksnya. Buku HSK mengajarkan 会议 sebagai kosakata level empat. Buku ini mengajarkan 会议 bersama cara membuka rapat, cara memintanya diundur, dan cara menutupnya — karena itu yang kamu butuhkan Senin pagi.'),
  h2('Untuk siapa buku ini'),
  ...bullets(['Pemula yang belum pernah belajar Mandarin sama sekali.','Mahasiswa dan fresh graduate yang menyiapkan diri masuk dunia kerja.','Karyawan yang perusahaannya berhubungan dengan Tiongkok.','Pebisnis dan entrepreneur yang berurusan langsung dengan supplier atau pembeli Tiongkok.','Profesional yang sudah bekerja di perusahaan Tiongkok dan ingin lepas dari ketergantungan penerjemah.']),
  h2('Cara memakai buku ini'),
  body('Setiap chapter punya susunan yang sama, jadi kamu tidak perlu belajar ulang cara belajarnya. Mulai dari Learning Objectives supaya tahu targetnya, hafalkan kosakata dan ungkapan, baca dialognya keras-keras, kerjakan bacaan, pahami grammar, lalu kerjakan latihan. Bagian Speaking sengaja diletakkan paling akhir dan tidak boleh dilewati — kemampuan yang tidak pernah diucapkan tidak akan bertahan.'),
  body('Chapter 0 khusus untuk yang belum pernah belajar Mandarin. Kalau kamu sudah bisa membaca pinyin dan menyebut angka, langsung saja ke Chapter 1.')
];

const doc = new Document({
  creator:'Xing Mandarin', title:'Business Mandarin Foundation',
  numbering:{ config:[{ reference:'bul', levels:[{ level:0, format:LevelFormat.BULLET, text:'•', alignment:AlignmentType.LEFT,
    style:{ paragraph:{ indent:{ left:convertInchesToTwip(0.35), hanging:convertInchesToTwip(0.2) } } } }] }] },
  styles:{ default:{ document:{ run:{ font:'Calibri', size:21, color:INK }, paragraph:{ spacing:{line:300} } } } },
  sections:[{
    properties:{ page:{ margin:{ top:1200, bottom:1200, left:1200, right:1200 } } },
    footers:{ default: new Footer({ children:[ new Paragraph({ alignment:AlignmentType.CENTER,
      children:[ new TextRun({ children:['Xing Mandarin  ·  Business Mandarin Foundation  ·  ', PageNumber.CURRENT], size:16, color:MUTED }) ] }) ] }) },
    children:[ ...cover, ...chapters.flatMap(chapter), ...appendix(chapters) ]
  }]
});

Packer.toBuffer(doc).then(b => { fs.writeFileSync(OUT, b); console.log('written', OUT, b.length, 'bytes'); });
