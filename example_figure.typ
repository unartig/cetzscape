#import "@preview/cetz:0.5.3": canvas, draw

// =====================================================================
//  Concept figure: one time-aware outcome model (mu +- sigma, trained on
//  UPDRS-III), queried in two modes, used to optimise position and
//  settings, watch drift and retrieve similar patients, plus the LLM
//  clinical assistant. The optimisation itself is detailed in
//  retune-optimisation.typ.
//
//  Where to edit
//    1. DATA      what is measured, and once (snapshot) or repeatedly (recurring)
//    2. TIMELINE  which measurements exist at which month after surgery
//    3. TEXT      cards, ports, notes, LLM features
//    4. LAYOUT    positions in mm (only needed when adding new boxes)
//
//  Coordinates inside the canvas are measured from the bottom-left corner
//  of the Data box, with y pointing DOWN. If the Data box grows, everything
//  below it moves with it.
// =====================================================================

#set page(width: auto, height: auto, margin: 8mm, fill: rgb("#262226"))
#set text(size: 8pt, font: ("Liberation Sans", "Arial", "Helvetica", "DejaVu Sans"), fill: white)

// ---------------------------------------------------------------------
// Colours
// ---------------------------------------------------------------------
#let c-snap = rgb("#0055d4") // snapshot: measured once (before surgery)
#let c-rec = rgb("#ff7f2a") // recurring: measured repeatedly (after surgery)
#let c-enc = rgb("#254245") // model box
#let c-box = rgb("#422545") // outline of plain boxes
#let c-card = rgb("#2b1e30") // use cards
#let c-ok = rgb("#00d4aa") // good / predicted
#let c-bad = rgb("#ff4f4f") // drift / untrusted / infeasible
#let c-a = rgb("#c9a0ff") // Mode A
#let c-b = rgb("#ffd166") // Mode B
#let kind-color = (snapshot: c-snap, recurring: c-rec, query: gray)

// ---------------------------------------------------------------------
// 1. DATA
//    item = (label, kind); kind = "snapshot", "recurring" or an array of both
// ---------------------------------------------------------------------
#let data-groups = (
  (
    title: "DBS stimulation parameters",
    items: (
      ("all stimulation parameters (every year)", "recurring"),
      ("side effects (3 to 6 months after surgery)", "recurring"),
      ("impedance measurements (optional)", "recurring"),
    ),
  ),
  (
    title: "Biomaterial",
    items: (
      ("cerebrospinal fluid (CSF)", "snapshot"),
      ("EDTA whole blood", "snapshot"),
      ("neurofilament light chain (NfL)", "snapshot"),
      ("alpha-synuclein", "snapshot"),
      ("gene mutations", "snapshot"),
    ),
  ),
  (
    title: "Imaging",
    items: (
      ("MRI (structure)", "snapshot"),
      ("FDG-PET (function)", "snapshot"),
    ),
  ),
  (
    title: "Electrophysiological data",
    items: (
      ("local field potential (LFP)", ("snapshot", "recurring")),
    ),
  ),
  (
    title: "Disease progression milestones",
    items: (
      ("e.g. falls, movement patterns, need for care", "recurring"),
      ("self-reported questionnaires (dotlink)", "recurring"),
    ),
  ),
)

// ---------------------------------------------------------------------
// 2. TIMELINE (months after surgery; one column of squares per stream)
//    The blue row at t = 0 is the snapshot; the orange squares are the
//    trajectory. Both enter the same predictor as one patient record.
// ---------------------------------------------------------------------
#let snap-row = (0, 1, 2) // columns carrying the baseline snapshot at t = 0
#let streams = (
  (col: 0, months: range(1, 13).map(i => i / 2)), // every two weeks
  (col: 1, months: (2, 3, 5)),
  (col: 2, months: (2, 5)),
)
#let time-labels = (
  (0, [time of \ surgery]),
  (3, [3 months \ after surgery]),
  (6, [6 months \ after surgery]),
)

// ---------------------------------------------------------------------
// 3. TEXT
// ---------------------------------------------------------------------
// output ports of the model: one outcome head (feeds three cards), one embedding
#let port-out = [
  *Output*\ \
  Patient outcome \ $mu plus.minus sigma$ \ \
  // #text(fill: c-a)[*A* settings masked] \
  // #text(fill: c-b)[*B* settings given] \
  Energy:\ $E = -(mu - beta sigma)$, differentiable in electrode:
  - position $p$
  - settings $s$
]
#let port-z = [*Embedding $z$* \ intermediate \ representation]

#let cards = (
  (
    title: "Pre-op: optimise position",
    body: [#text(fill: c-a)[*Mode A*], \ Predictor frozen, patient fixed: \ $p^* = arg min_p E_A (p)$],
  ),
  (
    title: "Post-op: optimise settings",
    body: [#text(fill: c-b)[*Mode B*], \ Implanted position fixed: \ $s^* = arg min_s E_B (s)$.],
  ),
  (
    title: "Drift watch",
    body: [Outcome $mu plus.minus sigma$ at the current settings vs the observed UPDRS-III. A sustained residual raises an alert.],
  ),
  (
    title: "Retrieval: similar patients",
    body: [Query the an intermediate representation $z$: which similar patients and trajectories responded, and with which settings?],
  ),
)

#let llm-features = (
  [Run what-if optimisations through tool calls (positions, settings)],
  [Explain retrieved similar patients and trajectories],
  [Provide visualizations],
  [Give patients and clinicians access to information],
)

// ---------------------------------------------------------------------
// 4. LAYOUT (mm)
// ---------------------------------------------------------------------
#let x-shift = 100
#let y-shift = -130
#let sq = 2.6 // square size
#let pitch = 3.0 // distance between squares
#let mpm = 6.0 // mm per month on the time axis
#let axis-x = 21 + x-shift // time axis
#let mat-x = 24 + x-shift // left edge of the first square column
#let enc-x = 40 + x-shift // model box
#let enc-w = 62
#let pred-w = (enc-w / 2) * 0.90
#let model-top = 10 + y-shift
#let model-bot = 126 + y-shift
#let card-geom = ((24 + y-shift, 28), (55 + y-shift, 28), (85 + y-shift, 26), (114 + y-shift, 26)) // (centre y, height) of the four use cards
#let rows = card-geom.map(g => g.first())
#let card-x = 110 + x-shift
#let card-w = 90
#let vis-x = card-x + 50 // left edge of the visual area inside a card
#let bus-x = card-x + card-w + 6 // vertical line towards the LLM
#let llm-x = bus-x + 24
#let llm-w = 56
#let t0-y = 50 + y-shift // y of "time of surgery"
#let y-low = 134 + y-shift // top of the bottom row (inputs per mode, steering loop)
#let llm-link = (start: ">", end: ">", fill: black) // two-way: the LLM calls the model and reads results

// derived values
#let n-cols = calc.max(..streams.map(s => s.col), ..snap-row) + 1
#let t-max = calc.max(..streams.map(s => calc.max(..s.months)))
#let mat-top = t0-y - sq / 2
#let mat-bot = t0-y + t-max * mpm + sq / 2
#let mat-right = mat-x + n-cols * pitch - (pitch - sq)
#let y-post = (mat-top + mat-bot) / 2
#let y-llm = (rows.first() + rows.last()) / 2
#let axis-len = t-max * mpm + 9

// =====================================================================
// Content building blocks (plain Typst, no canvas needed)
// =====================================================================
#let marker(kinds) = {
  let ks = if type(kinds) == str { (kinds,) } else { kinds }
  box(width: 4.4mm, ks.map(k => box(width: 1.7mm, height: 1.7mm, fill: kind-color.at(k))).join(h(0.5mm)))
}

#let group-block(g) = stack(
  dir: ttb,
  spacing: 1.1mm,
  text(weight: "bold")[#g.title],
  ..g.items.map(((label, kind)) => pad(left: 2mm)[#marker(kind)#label]),
)

#let legend = stack(
  dir: ttb,
  spacing: 1.2mm,
  [#marker("recurring") Recurring],
  [#marker("snapshot") Snapshot],
)

#let data-box = block(
  width: 92mm,
  inset: 3mm,
  fill: c-box,
  stroke: 0.25mm + c-box,
  {
    grid(
      columns: (1fr, auto, 1fr),
      align: horizon,
      [], text(size: 12pt, weight: "bold")[Data], align(right, legend),
    )
    v(2mm)
    stack(dir: ttb, spacing: 2mm, ..data-groups.map(group-block))
  },
)

#let note(title, items, height: auto, stroke: 0.25mm + c-box) = block(
  width: 90mm,
  height: height,
  inset: 2.5mm,
  fill: c-box,
  stroke: stroke,
  {
    text(size: 12pt, weight: "bold", title)
    v(1mm)
    set text(size: 12pt)
    set list(marker: [•], body-indent: 1.2mm, spacing: 1.1mm)
    list(..items)
  },
)

// which inputs does each mode see?
#let dot(used) = if used { text(fill: white)[●] } else { text(fill: gray)[–] }
#let query-box = block(
  width: enc-w * 1mm,
  inset: 1mm,
  fill: c-box,
  stroke: 0.25mm + c-box,
  {
    text(size: 10pt, weight: "bold")[Inputs per mode]
    set text(size: 8pt)
    grid(
      columns: (5mm, 1fr, 4.5mm, 4.5mm),
      column-gutter: 0.8mm,
      row-gutter: 1.2mm,
      align: (left + top, left + top, center + top, center + top),
      [], [], text(fill: c-a, weight: "bold")[A], text(fill: c-b, weight: "bold")[B],
      marker("snapshot"), [*patient state*], dot(true), dot(true),
      marker(("snapshot", "recurring")), [*patient history*], dot(false), dot(true),
      marker("snapshot"), [*position $p$*: target, contact, depth, LFP features, region imaging], dot(false), dot(true),
      marker("recurring"), [*settings $s$*: amplitude, frequency, pulse width, contacts], dot(false), dot(true),
      marker("query"), [*time $t$*: horizon after surgery], dot(true), dot(true),
    )
  },
)

#let llm-box = block(
  width: llm-w * 1mm,
  inset: 3mm,
  fill: c-box,
  stroke: 0.25mm + c-box,
  {
    align(center, text(size: 9pt, weight: "bold")[LLM – Clinical Assistant \ (NORA)])
    v(1.5mm)
    text(size: 8pt, list(marker: [•], body-indent: 1.5mm, spacing: 1.6mm, ..llm-features))
  },
)

// =====================================================================
// Drawing
// =====================================================================
#let sketch-fig-v2 = canvas(length: 1mm, {
  import draw: *
  set-style(stroke: 0.75pt)
  let P(x, y) = (rel: (x, -y), to: "data.south-west")
  let square(x, yc, color) = rect(
    P(x, yc - sq / 2),
    P(x + sq, yc + sq / 2),
    fill: color,
    stroke: none,
  )
  let c-arrow = gray
  let arrow = (end: ">", fill: c-arrow)
  let thin = (paint: gray, thickness: 0.3pt)
  let dashed = (paint: white, dash: "dashed", thickness: 0.3pt)
  // small arrow between the panels of a visual
  let parrow(x1, x2, y) = line(
    P(x1, y),
    P(x2, y),
    mark: (end: ">", fill: c-arrow, scale: 0.6),
    stroke: (paint: c-arrow, thickness: 0.4pt),
  )
  // caption below a panel (y = bottom edge of the panel)
  let cap(x, y, s) = content(P(x, y + 1.2), text(size: 8pt, fill: gray, s), anchor: "north")
  // ---- energy profile: the optimisation in one dimension ---------------
  // kind "pos": two basins, gradient descent from the left slope
  // kind "set": one basin, gradient descent from the left
  let profile(ox, oy, kind) = {
    let w = 35
    let h = 18
    let Q(x, y) = P(ox + x, oy - y)
    let ef(x) = if kind == "pos" {
      1 - calc.max(calc.exp(-calc.pow((x - 0.65) / 0.14, 2)), 0.55 * calc.exp(-calc.pow((x - 0.2) / 0.1, 2)))
    } else {
      1 - calc.exp(-calc.pow((x - 0.7) / 0.25, 2))
    }
    let xs = range(0, 71).map(i => i / 70)
    line(Q(0, 0), Q(w, 0), stroke: thin)
    line(..xs.map(x => Q(x * w, ef(x) * (h - 3))), stroke: (paint: c-ok, thickness: 0.7pt))
    content(Q(0, h), text(size: 8pt, fill: gray)[$E$], anchor: "north-west")
    content(Q(w, 0.4), text(size: 8pt, fill: gray)[#if kind == "pos" [$p$] else [$s$]], anchor: "south-east")
    // gradient descent steps (backtracking, normalised)
    let xc = if kind == "pos" { 0.42 } else { 0.08 }
    let pts = (xc,)
    let s = 0.11
    for k in range(10) {
      let g = (ef(xc + 0.005) - ef(xc - 0.005)) / 0.01
      let cand = calc.clamp(xc - s * g / calc.max(1e-9, calc.abs(g)), 0.0, 1.0)
      if ef(cand) < ef(xc) - 1e-9 {
        xc = cand
        pts.push(xc)
      } else {
        s = s * 0.5
      }
      s = s * 0.9
    }
    let cs = pts.map(x => Q(x * w, ef(x) * (h - 3)))
    line(..cs, mark: (end: ">", fill: white, scale: 0.5), stroke: (paint: white, thickness: 0.5pt))
    for q in cs.slice(1) {
      circle(q, radius: 0.5, fill: white, stroke: none)
    }
    circle(cs.first(), radius: 0.8, fill: none, stroke: (paint: white, thickness: 0.4pt))
    circle(cs.last(), radius: 1.1, fill: none, stroke: (paint: white, thickness: 0.5pt))
    if kind == "pos" {
      circle(Q(0.2 * w, ef(0.2) * (h - 3)), radius: 1.0, fill: none, stroke: (paint: gray, thickness: 0.4pt))
      content(Q(0.2 * w, ef(0.2) * (h - 3) - 1.4), text(size: 6pt, fill: gray)[local minimum], anchor: "north")
    }
    cap(ox + w / 2, oy, if kind
      == "pos" [energy $E$ along $p$: find the minimum] else [energy $E$ along $s$: find the minimum])
  }
  // ---- Drift: outcome vs predicted band, residual vs threshold ---------
  let drift-vis(ox, oy) = {
    let Q(x, y) = P(ox + x, oy - y)
    let pred(x) = 10 - 0.04 * x
    let xs = range(0, 31)
    let noise = (0.3, -0.4, 0.2, -0.3, 0.4, -0.8, -1.9, -3.1, -4.2, -5.0)
    // panel 1: observed outcome leaves the predicted band
    line(
      ..xs.map(x => Q(x, pred(x) + 1.6)),
      ..xs.rev().map(x => Q(x, pred(x) - 1.6)),
      close: true,
      fill: c-ok.transparentize(70%),
      stroke: none,
    )
    line(..xs.map(x => Q(x, pred(x))), stroke: (paint: c-ok, thickness: 0.6pt))
    for (k, x) in range(2, 30, step: 3).enumerate() {
      circle(Q(x, pred(x) + noise.at(k)), radius: 0.55, fill: if k < 6 { c-rec } else { c-bad }, stroke: none)
    }
    line(Q(0, 0), Q(30, 0), stroke: thin)
    cap(ox + 15, oy, [1 outcome vs predicted band])
  }
  // ---- Retrieval: neighbours in embedding space, their trajectories ----
  let retr-vis(ox, oy) = {
    let Q(x, y) = P(ox + x, oy - y)
    let cloud = (
      (3, 3),
      (6, 9),
      (9, 4),
      (12, 12),
      (15, 3),
      (19, 11),
      (22, 4),
      (26, 8),
      (5, 14),
      (11, 15),
      (18, 14),
      (25, 13),
      (28, 3),
      (2, 9),
      (8, 7),
      (23, 10),
    )
    for p in cloud {
      circle(Q(..p), radius: 0.35, fill: gray.lighten(30%), stroke: none)
    }
    let q = (15, 8)
    circle(
      Q(..q),
      radius: 4.5,
      fill: c-snap.transparentize(80%),
      stroke: (paint: c-snap.lighten(30%), dash: "dashed", thickness: 0.4pt),
    )
    for (x, y, good) in ((13, 7, true), (17, 9, true), (14, 11, true), (16.5, 5.5, false)) {
      line(Q(..q), Q(x, y), stroke: (paint: white.transparentize(60%), thickness: 0.3pt))
      circle(Q(x, y), radius: 0.6, fill: if good { c-ok } else { c-bad }, stroke: none)
    }
    circle(Q(..q), radius: 0.9, fill: c-snap, stroke: (paint: white, thickness: 0.4pt))
    cap(ox + 15, oy, [embedding $z$, k nearest])
  }
  // ---- data box and notes beside it ----------------------------------
  content((0, 0), data-box, anchor: "north-west", name: "data")
  // ---- patient record: snapshot + trajectory in one input -------------
  line(P(axis-x, t0-y), P(axis-x, t0-y + axis-len), mark: arrow, stroke: c-arrow)
  for k in range(int(axis-len / pitch)) {
    let major = calc.rem(k, 6) == 0
    let w = if major { 1.0 } else { 0.5 }
    line(P(axis-x - w, t0-y + k * pitch), P(axis-x + w, t0-y + k * pitch), stroke: c-arrow)
  }
  for (m, lbl) in time-labels {
    content(P(axis-x - 3, t0-y + m * mpm), anchor: "east", align(right, lbl))
  }
  content(P(axis-x - 3, t0-y + axis-len + 1.5), anchor: "north")[time]
  for c in snap-row { square(mat-x + c * pitch, t0-y, c-snap) }
  for s in streams {
    for t in s.months { square(mat-x + s.col * pitch, t0-y + t * mpm, c-rec) }
  }
  // next visit: new evidence arrives here (closed loop at the bottom)
  rect(
    P(mat-x + pitch - 3, t0-y + 7 * mpm - sq / 2 - 2),
    P(mat-x + pitch + sq - 3, t0-y + 7 * mpm + sq / 2 - 2),
    fill: none,
    stroke: (paint: c-rec, dash: "dashed", thickness: 0.4pt),
  )
  content(
    P(mat-x + (mat-right - mat-x) / 2 + 1, mat-top - 1.5),
    anchor: "south",
    align(center, text(
      size: 8pt,
    )[Patient record \ #text(fill: c-snap)[snapshot] \ #text(fill: c-rec)[\+ trajectory]]),
  )
  line(P(mat-right + 1.5, y-post), P(enc-x, y-post), mark: arrow, stroke: c-arrow)
  // ---- the model ------------------------------------------------------
  rect(P(enc-x, model-top), P(enc-x + enc-w, model-bot), fill: c-enc, stroke: 0.25mm + rgb("#3a6366"), radius: 1mm)
  content(
    P(enc-x + enc-w / 2, model-top + 1.5),
    anchor: "north",
    align(center)[
      #text(size: 12pt, weight: "bold")[Time-aware outcome predictor] \
    ],
  )
  rect(P(enc-x + 3, model-top + 5), P(enc-x + pred-w, model-bot - 5), fill: rgb("#1d3335"), stroke: none, radius: 0.6mm)
  content(
    P(enc-x + 16, y-llm),
    block(width: (1.7 * pred-w) / 2 * 1mm, align(left)[
      #text(size: 9pt, weight: "bold")[Shared Predictor]
      #v(1mm)
      #set text(size: 8pt)
      #set list(marker: [•], body-indent: 0.8mm, spacing: 2mm)
      - Transformer over visits/evidence tokens
      - continuous-time embeddings
      - weights frozen at use time: only $p$ and $s$ vary
    ]),
  )
  let port-box(y0, y1, body, size: 8pt) = {
    rect(P(enc-x + pred-w + 3, y0), P(enc-x + 3 + 2 * (pred-w), y1), fill: rgb("#2f5a5e"), stroke: none, radius: 0.6mm)
    content(P(enc-x + 2 + 1.5 * pred-w, (y0 + y1) / 2), block(width: 23mm, align(left, text(size: size, body))))
    line(
      P(enc-x + pred-w, (y0 + y1) / 2),
      P(enc-x + pred-w + 3, (y0 + y1) / 2),
      mark: arrow,
      stroke: c-arrow,
    )
  }
  // one outcome head feeds three cards; the embedding feeds retrieval
  port-box(rows.at(0) - 9, rows.at(2) + 9, port-out, size: 8pt)
  port-box(rows.at(3) - 6.5, rows.at(3) + 6.5, port-z)
  // UPDRS-III: ground truth for the outcome head
  rect(
    P(enc-x + 2 + pred-w, rows.at(2) + 11),
    P(enc-x + 2 + 2 * (pred-w), rows.at(2) + 20),
    fill: rgb("#1d3335"),
    stroke: (paint: c-rec, thickness: 0.4pt),
    radius: 0.6mm,
  )
  content(P(enc-x + 2 + 1.5 * pred-w, rows.at(2) + 15.5), align(center, text(size: 8pt)[*UPDRS-III* \ ground truth]))
  line(
    P(enc-x + 2 + 1.5 * pred-w, rows.at(2) + 11),
    P(enc-x + 2 + 1.5 * pred-w, rows.at(2) + 9.5),
    mark: (end: ">", fill: c-rec),
    stroke: (paint: c-rec, thickness: 0.5pt),
  )
  // ---- inputs per mode -----------------------------------------------
  content(P(enc-x, y-low), query-box, anchor: "north-west")
  line(P(enc-x + enc-w / 2, y-low), P(enc-x + enc-w / 2, model-bot + 0.5), mark: arrow, stroke: c-arrow)
  // ---- use cards, bus and LLM ----------------------------------------
  for (i, (r, h)) in card-geom.enumerate() {
    rect(P(card-x, r - h / 2), P(card-x + card-w, r + h / 2), fill: c-card, stroke: 0.25mm + c-box, radius: 0.8mm)
    content(
      P(card-x + 2, r),
      anchor: "west",
      block(width: 46mm, {
        text(size: 11pt, weight: "bold", cards.at(i).title)
        linebreak()
        text(size: 8pt, cards.at(i).body)
      }),
    )
    line(P(enc-x + enc-w, r), P(card-x, r), mark: arrow, stroke: c-arrow)
    line(P(card-x + card-w, r), P(bus-x, r), stroke: c-arrow)
  }
  profile(vis-x, rows.at(0) + 8, "pos")
  profile(vis-x, rows.at(1) + 8, "set")
  drift-vis(vis-x, rows.at(2) + 7)
  retr-vis(vis-x, rows.at(3) + 7)
  content(P(llm-x, y-llm), llm-box, anchor: "west", name: "llm")
  line(P(bus-x, rows.first()), P(bus-x, rows.last()), stroke: c-arrow)
  circle(P(bus-x, y-llm), radius: 0.5, fill: black, stroke: none)
  line(P(bus-x, y-llm), "llm.west", mark: llm-link, stroke: c-arrow)
  content(
    P((bus-x + llm-x) / 2, y-llm - 1.2),
    anchor: "south",
    text(size: 8pt)[RAG / tool calls],
  )
  // ---- closed loop: Pioneer-style steering with patient feedback -----
  rect(P(card-x, y-low), P(card-x + 1.45 * card-w, y-low + 26), fill: c-card, stroke: 0.25mm + c-box, radius: 0.8mm)
  content(
    P(card-x + (1.45 * card-w) / 2, y-low + 2),
    anchor: "north",
    text(size: 12pt, weight: "bold")[Pioneer-style steering loop],
  )
  let loop-boxes = (
    [Optimised settings or drift alert],
    [Clinician and patient app (dotlink)],
    [New evidence: visit, LFP, PROM, EMA],
  )
  for (i, lbl) in loop-boxes.enumerate() {
    let bx = card-x + 5 + i * 43
    rect(P(bx, y-low + 9), P(bx + 34, y-low + 24), fill: c-enc, stroke: none, radius: 0.6mm)
    content(P(bx + 17, y-low + 16.5), block(width: 32mm, align(center, text(size: 9pt, lbl))))
    if i < 2 {
      line(P(bx + 34, y-low + 16.5), P(bx + 43, y-low + 16.5), mark: arrow, stroke: c-arrow)
    }
  }
  let loop-end = card-x + 5 + 2 * 43 + 17
  line(
    P(loop-end, y-low + 24),
    P(loop-end, y-low + 35),
    P(mat-x + pitch + sq / 2 - 3, y-low + 35),
    P(mat-x + pitch + sq / 2 - 3, t0-y + 7 * mpm + sq / 2 - 1.3),
    mark: (end: ">", fill: c-rec),
    stroke: (paint: c-rec, dash: "dashed", thickness: 0.6pt),
  )
  content(
    P(card-x + 2, y-low + 36.5),
    anchor: "north-west",
    text(size: 9pt, fill: c-rec)[new evidence updates the trajectory and re-triggers the optimisation],
  )
})
