import "./style.css";

const icons = {
  search: '<svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="6"/><path d="m16 16 4 4"/></svg>',
  plus: '<svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>',
  library: '<svg viewBox="0 0 24 24"><path d="M5 4h4v16H5zM10.5 4h4v16h-4zM17 5l3 14"/></svg>',
  compass: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8"/><path d="m15 9-2 4-4 2 2-4z"/></svg>',
  layers: '<svg viewBox="0 0 24 24"><path d="m12 4 8 4-8 4-8-4z"/><path d="m4 12 8 4 8-4M4 16l8 4 8-4"/></svg>',
  file: '<svg viewBox="0 0 24 24"><path d="M6 3h8l4 4v14H6z"/><path d="M14 3v5h5M9 12h6M9 16h6"/></svg>',
  course: '<svg viewBox="0 0 24 24"><path d="m4 8 8-4 8 4-8 4z"/><path d="M7 10v5c2 2 8 2 10 0v-5M20 9v6"/></svg>',
  graph: '<svg viewBox="0 0 24 24"><circle cx="6" cy="12" r="2"/><circle cx="18" cy="6" r="2"/><circle cx="18" cy="18" r="2"/><path d="m8 11 8-4M8 13l8 4"/></svg>',
  pen: '<svg viewBox="0 0 24 24"><path d="m14 6 4 4M4 20l4-1 11-11a2.8 2.8 0 0 0-4-4L4 15z"/></svg>',
  bookmark: '<svg viewBox="0 0 24 24"><path d="M7 4h10v16l-5-3-5 3z"/></svg>',
  quote: '<svg viewBox="0 0 24 24"><path d="M9 11H5V7h5v5l-3 5M18 11h-4V7h5v5l-3 5"/></svg>',
  more: '<svg viewBox="0 0 24 24"><circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/></svg>',
  chevron: '<svg viewBox="0 0 24 24"><path d="m9 6 6 6-6 6"/></svg>',
  spark: '<svg viewBox="0 0 24 24"><path d="m12 3 1.5 5.5L19 10l-5.5 1.5L12 17l-1.5-5.5L5 10l5.5-1.5z"/><path d="m19 16 .6 2.4L22 19l-2.4.6L19 22l-.6-2.4L16 19l2.4-.6z"/></svg>',
  send: '<svg viewBox="0 0 24 24"><path d="m20 4-7 16-3-7-7-3z"/><path d="m10 13 4-4"/></svg>',
  grid: '<svg viewBox="0 0 24 24"><path d="M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z"/></svg>',
  panel: '<svg viewBox="0 0 24 24"><path d="M4 5h16v14H4zM15 5v14"/></svg>',
  close: '<svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6 6 18"/></svg>',
  check: '<svg viewBox="0 0 24 24"><path d="m5 12 4 4L19 6"/></svg>',
  clock: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8"/><path d="M12 7v5l3 2"/></svg>',
  arrow: '<svg viewBox="0 0 24 24"><path d="M5 12h13M14 8l4 4-4 4"/></svg>',
};

const papers = [
  { type: "PDF", title: "Attention Is All You Need", meta: "Vaswani et al. · 2017", tone: "violet" },
  { type: "PDF", title: "The Extended Mind", meta: "Clark & Chalmers · 1998", tone: "sage" },
  { type: "DOC", title: "课程论文选题思路", meta: "我的笔记 · 昨天", tone: "sand" },
  { type: "WEB", title: "Embodied Cognition", meta: "Stanford Encyclopedia", tone: "blue" },
];

const renderPaper = (paper, index) => `
  <button class="paper-card ${index === 0 ? "selected" : ""}" data-paper="${index}">
    <span class="paper-type ${paper.tone}">${paper.type}</span>
    <span class="paper-copy">
      <strong>${paper.title}</strong>
      <small>${paper.meta}</small>
    </span>
  </button>`;

const app = document.querySelector("#app");
app.innerHTML = `
  <main class="desktop-shell">
    <header class="topbar">
      <div class="traffic"><i></i><i></i><i></i></div>
      <div class="brand"><span class="brand-mark">A</span><b>Arcadia</b><em>STUDY SPACE</em></div>
      <label class="global-search">${icons.search}<input placeholder="搜索资料、笔记或知识点" /><kbd>⌘ K</kbd></label>
      <div class="top-actions">
        <button class="icon-button tooltip" aria-label="快速添加" data-tip="快速添加">${icons.plus}</button>
        <span class="divider"></span>
        <button class="avatar">林</button>
      </div>
    </header>

    <div class="workspace">
      <aside class="sidebar">
        <nav class="main-nav">
          <button class="nav-item">${icons.compass}<span>总览</span></button>
          <button class="nav-item active">${icons.library}<span>知识库</span><b>42</b></button>
          <button class="nav-item">${icons.course}<span>课程空间</span></button>
          <button class="nav-item">${icons.pen}<span>论文写作</span></button>
          <button class="nav-item">${icons.graph}<span>知识图谱</span></button>
        </nav>
        <section class="collection">
          <div class="section-label"><span>资料库</span><button>${icons.plus}</button></div>
          <button class="folder active"><i class="folder-dot coral"></i>认知科学<span>18</span></button>
          <button class="folder"><i class="folder-dot sage"></i>计算机视觉<span>12</span></button>
          <button class="folder"><i class="folder-dot gold"></i>社会学概论<span>7</span></button>
          <button class="folder"><i class="folder-dot blue"></i>未分类<span>5</span></button>
        </section>
        <button class="graph-preview" id="openGraph">
          <span>${icons.graph} 知识网络</span>
          <div class="mini-graph">
            <i></i><i></i><i></i><i></i><i></i>
            <svg viewBox="0 0 180 78"><path d="M22 42 70 22 102 54 152 27M70 22l17 40m15-8 50-27"/></svg>
          </div>
          <small>已连接 128 个知识点 <b>查看 ${icons.arrow}</b></small>
        </button>
        <button class="settings"><span class="tiny-avatar">林</span><span><b>林一</b><small>研究空间</small></span>${icons.more}</button>
      </aside>

      <section class="library-panel">
        <div class="library-heading">
          <div><p>资料库</p><h1>认知科学</h1></div>
          <button class="round-add" aria-label="添加资料">${icons.plus}</button>
        </div>
        <div class="filter-row"><button class="filter active">全部</button><button class="filter">论文</button><button class="filter">笔记</button><button class="filter">网页</button></div>
        <label class="library-search">${icons.search}<input placeholder="在资料库中搜索" /></label>
        <div class="paper-list">
          <p class="list-label">最近阅读 <span>4</span></p>
          ${papers.map(renderPaper).join("")}
          <p class="list-label secondary">更早 <span>3</span></p>
          ${[
            { type:"PDF", title:"Situated Learning", meta:"Lave & Wenger · 1991", tone:"sage" },
            { type:"PDF", title:"Mind in Society", meta:"Vygotsky · 1978", tone:"blue" },
            { type:"DOC", title:"第 4 周课程梳理", meta:"我的笔记 · 5月12日", tone:"sand" }
          ].map(renderPaper).join("")}
        </div>
      </section>

      <section class="reader">
        <header class="reader-toolbar">
          <div class="document-title">
            <span class="tiny-file">PDF</span>
            <div><b>Attention Is All You Need</b><small>Vaswani et al. · 2017 · 15 pages</small></div>
          </div>
          <div class="reader-actions">
            <button class="tool selected tooltip" aria-label="高亮" data-tip="高亮">${icons.pen}</button>
            <button class="tool tooltip" aria-label="书签" data-tip="书签">${icons.bookmark}</button>
            <button class="tool tooltip" aria-label="添加引用" data-tip="添加引用">${icons.quote}</button>
            <span></span>
            <button class="tool tooltip" data-tip="更多">${icons.more}</button>
          </div>
        </header>
        <div class="document-wrap">
          <article class="paper">
            <div class="paper-topline"><span>NEURAL INFORMATION PROCESSING SYSTEMS</span><span>2017</span></div>
            <h2>Attention Is All You Need</h2>
            <div class="authors">Ashish Vaswani · Noam Shazeer · Niki Parmar · Jakob Uszkoreit</div>
            <p class="abstract"><b>Abstract</b> The dominant sequence transduction models are based on complex recurrent or convolutional neural networks that include an encoder and a decoder. The best performing models also connect the encoder and decoder through an attention mechanism.</p>
            <h3>1 &nbsp; Introduction</h3>
            <p>Recurrent neural networks, long short-term memory and gated recurrent neural networks in particular, have been firmly established as state of the art approaches in sequence modeling and transduction problems such as language modeling and machine translation.</p>
            <div class="highlight-block">
              <p>We propose a new simple network architecture, the <mark>Transformer</mark>, based solely on attention mechanisms, dispensing with recurrence and convolutions entirely.</p>
              <button class="annotation-pin" data-note="Transformer 的核心定义：完全依赖注意力机制，不再使用循环和卷积结构。">1</button>
            </div>
            <p>Experiments on two machine translation tasks show these models to be superior in quality while being more parallelizable and requiring significantly less time to train.</p>
            <h3>2 &nbsp; Background</h3>
            <p>The goal of reducing sequential computation also forms the foundation of the Extended Neural GPU, ByteNet and ConvS2S, all of which use convolutional neural networks as basic building block, computing hidden representations in parallel for all input and output positions.</p>
            <div class="highlight-block soft">
              <p>Self-attention, sometimes called intra-attention, is an attention mechanism relating different positions of a single sequence in order to compute a representation of the sequence.</p>
              <button class="annotation-pin" data-note="自注意力让单一序列中的不同位置彼此建立关系，并生成整段序列的表示。">2</button>
            </div>
            <h3>3 &nbsp; Model Architecture</h3>
            <p>Most competitive neural sequence transduction models have an encoder-decoder structure. Here, the encoder maps an input sequence of symbol representations to a sequence of continuous representations.</p>
          </article>
          <footer class="page-nav"><button>‹</button><span><b>3</b> / 15</span><button>›</button></footer>
        </div>
      </section>

      <aside class="insight-panel">
        <div class="insight-tabs"><button class="active" data-tab="ai">${icons.spark} AI 助手</button><button data-tab="notes">${icons.pen} 笔记 <b>3</b></button></div>
        <section class="tab-content ai-view active">
          <div class="ai-intro">
            <span class="ai-orb">${icons.spark}</span>
            <div><h3>阅读助手</h3><p>已关联当前论文与 18 项资料</p></div>
          </div>
          <div class="summary-card">
            <div class="summary-title"><span>${icons.spark} AI 速读</span><button>重新生成</button></div>
            <p>本文提出了 <b>Transformer</b> 架构，以自注意力机制替代传统的循环和卷积结构，显著提高了并行计算能力。</p>
            <div class="concepts"><span>自注意力</span><span>Transformer</span><span>序列建模</span></div>
          </div>
          <div class="ai-section">
            <p class="aside-label">推荐问题</p>
            <button class="question">为什么 Transformer 不需要循环结构？<span>${icons.chevron}</span></button>
            <button class="question">对比本文与我的课程笔记<span>${icons.chevron}</span></button>
            <button class="question">整理本文的论证结构<span>${icons.chevron}</span></button>
          </div>
          <div class="ai-thread" id="aiThread"></div>
          <div class="ask-box">
            <textarea rows="2" placeholder="针对当前资料提问..."></textarea>
            <div><span>引用范围：当前资料</span><button id="sendQuestion" aria-label="发送问题">${icons.send}</button></div>
          </div>
        </section>
        <section class="tab-content notes-view">
          <div class="note-header"><div><h3>阅读笔记</h3><p>3 条笔记 · 自动保存</p></div><button>${icons.plus}</button></div>
          <div class="note-card"><span class="note-index">01</span><p>Transformer 的核心定义：完全依赖注意力机制，不再使用循环和卷积结构。</p><small>第 3 页 · 刚刚</small></div>
          <div class="note-card"><span class="note-index">02</span><p>自注意力让单一序列中的不同位置彼此建立关系，并生成整段序列的表示。</p><small>第 3 页 · 2 分钟前</small></div>
          <div class="note-card plain"><span class="note-index">03</span><p>可以和课程中“分布式表征”部分建立连接。后续需要整理一张模型演变图。</p><small>第 2 页 · 12 分钟前</small></div>
          <button class="export-notes">${icons.quote}<span>添加到论文素材库</span></button>
        </section>
      </aside>
    </div>
  </main>

  <div class="graph-modal" id="graphModal">
    <div class="graph-dialog">
      <header><div><p>认知科学 · 知识网络</p><h2>从资料，生长为结构</h2></div><button id="closeGraph" aria-label="关闭知识网络">${icons.close}</button></header>
      <div class="network">
        <svg viewBox="0 0 980 530">
          <path d="M480 250 275 165M480 250 710 135M480 250 742 346M480 250 288 370M480 250 490 75M275 165 125 225M275 165 250 55M710 135 845 90M710 135 840 225M742 346 878 398M742 346 600 430M288 370 150 430M288 370 405 468"/>
        </svg>
        <button class="node core" style="left:42%;top:42%">Transformer<small>核心概念</small></button>
        <button class="node" style="left:21%;top:25%">自注意力<small>12 条关联</small></button>
        <button class="node" style="left:69%;top:19%">序列建模<small>8 条关联</small></button>
        <button class="node" style="left:73%;top:65%">并行计算<small>5 条关联</small></button>
        <button class="node" style="left:23%;top:70%">认知架构<small>7 条关联</small></button>
        <button class="node small" style="left:45%;top:7%">注意力机制</button>
        <button class="node small" style="left:8%;top:39%">工作记忆</button>
        <button class="node small" style="left:14%;top:6%">编码器</button>
        <button class="node small" style="left:82%;top:9%">语言模型</button>
        <button class="node small" style="left:83%;top:39%">机器翻译</button>
        <button class="node small" style="left:86%;top:76%">训练效率</button>
        <button class="node small" style="left:58%;top:83%">GPU</button>
        <button class="node small" style="left:8%;top:82%">具身认知</button>
        <button class="node small" style="left:37%;top:90%">分布式表征</button>
      </div>
      <footer><span><i></i> 128 个知识点 <i></i> 246 条连接</span><button>进入完整图谱 ${icons.arrow}</button></footer>
    </div>
  </div>
`;

const tabs = document.querySelectorAll(".insight-tabs button");
tabs.forEach((tab) => tab.addEventListener("click", () => {
  tabs.forEach((item) => item.classList.remove("active"));
  document.querySelectorAll(".tab-content").forEach((item) => item.classList.remove("active"));
  tab.classList.add("active");
  document.querySelector(`.${tab.dataset.tab}-view`).classList.add("active");
}));

const modal = document.querySelector("#graphModal");
document.querySelector("#openGraph").addEventListener("click", () => modal.classList.add("show"));
document.querySelector("#closeGraph").addEventListener("click", () => modal.classList.remove("show"));
modal.addEventListener("click", (event) => {
  if (event.target === modal) modal.classList.remove("show");
});

document.querySelectorAll(".annotation-pin").forEach((pin) => pin.addEventListener("click", () => {
  document.querySelector('[data-tab="notes"]').click();
  document.querySelector(".notes-view").scrollTop = 0;
}));

document.querySelectorAll(".question").forEach((question) => question.addEventListener("click", () => {
  const thread = document.querySelector("#aiThread");
  thread.innerHTML = `<div class="user-msg">${question.textContent.trim()}</div><div class="ai-msg"><span>${icons.spark}</span><p>Transformer 通过自注意力机制直接建立序列中任意位置之间的联系，因此无需逐步传递隐藏状态。这样既保留了上下文关系，也让训练可以高度并行化。<small>来源：当前论文 · 第 3 页</small></p></div>`;
  thread.scrollIntoView({ behavior: "smooth", block: "end" });
}));

document.querySelector("#sendQuestion").addEventListener("click", () => {
  const input = document.querySelector(".ask-box textarea");
  if (!input.value.trim()) return;
  document.querySelector("#aiThread").innerHTML = `<div class="user-msg">${input.value}</div><div class="ai-msg"><span>${icons.spark}</span><p>我会结合当前论文与资料库中的相关笔记，为你整理这部分内容。<small>已检索：当前论文与 18 项关联资料</small></p></div>`;
  input.value = "";
});

document.querySelectorAll(".paper-card").forEach((card) => card.addEventListener("click", () => {
  document.querySelectorAll(".paper-card").forEach((item) => item.classList.remove("selected"));
  card.classList.add("selected");
}));
