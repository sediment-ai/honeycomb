# Writing style — Google developer documentation style

The [Google developer documentation style
guide](https://developers.google.com/style) governs every word an agent
writes here: chat replies to the builder, PR descriptions, issue comments,
commit message bodies, `README.md`, and every page under `docs/`. Treat it as the
authority and follow it wherever this page is silent.

This page doesn't restate the guide. It pins the rules that drafts break by
default, the swaps worth memorizing, and the places this repo narrows or
overrides Google's guidance.

This repo's pages come in two kinds. `README.md` and
`docs/fleet-design.md` are explanation. `docs/operations.md` and
`docs/join-the-fleet.md` are how-to. A rule that fits a how-to is wrong
in explanation. Agent docs, this one included, sit outside both.

Contributor doc. Imported from sediment-v2, adapted for this repo.

## The defaults every draft breaks

Check these first. A draft that clears all five is most of the way there.

1. **Timeless.** Cut *currently*, *now*, *new*, *recently*, *soon*, *at this
   time*, *as of this writing*, *does not yet*. Write "the exporter doesn't
   support X", never "doesn't currently support X". A dated record is the
   exception — it carries its date, so *new* means something there.
2. **The reader is *you*; the software is never *we*.** Name the actor: "the
   conductor routes work", "you set `CLUSTER_HOST`" — never "we then render
   the pod". *We* is the project speaking as author about its own choices
   and measurements ("we rejected X", "we run a single-node cluster"),
   which `README.md` and an explanation page such as
   [Agent fleet — design](../fleet-design.md) are the place for. It never
   stands in for what the code does.
3. **Conditions before instructions.** "If you run your own gateway, set
   the provider key" — not "Set the provider key if you run your own
   gateway". A reader who acts on the first clause has already acted.
4. **No *simply*, *just*, *easy*, *quickly*.** What's easy for you may not be
   easy for the reader. The word costs their trust the moment the step
   fails. Delete it, or swap it for the concrete thing: "about five
   minutes".
5. **No *please note*, *note that*, *it is worth noting*.** State the fact.
   A `Note:` block is for information that is useful and skippable — never
   for a prerequisite, which belongs in the step that needs it.

## Sentences

- **Active voice, named actor.** "The test caught the error", not "the error
  was caught by the test". Scan a draft for was/were/is/are + participle +
  *by*. Passive stays only where the actor is unknown ("the ref was
  force-pushed") or irrelevant ("errors are logged automatically").
- **Present tense.** "The server sends an acknowledgment", not "will send".
  Future tense is for events that genuinely come later: "the file is
  archived the next time the backup runs".
- **One idea per sentence.** Split a sentence that carries a second idea
  across *and*, *but*, or *because*. Past three parallel items, switch to a
  list.
- **Contract a negation.** *isn't*, *don't*, *can't*, *doesn't*. A reader who
  is skimming misses a bare *not*. Other two-word contractions are welcome
  but optional; three-word ones and invented ones are not.
- **Keep the helper words.** *That*, *then*, and *of* get dropped in
  conversational English, and their absence is what makes a sentence read
  twice: "the rules that drafts break", not "the rules drafts break".
- **Say the concrete thing.** "About five minutes", not "quickly". "Three
  retries", not "a few".
- **American spelling** — *labeled*, *normalize*, *behavior*. A literal name
  keeps its own spelling: the file `labelled_cases.json` and the CI result
  value `cancelled` stay as they are.
- **No idioms, humor, or culture-bound references.** They fail the reader
  whose first language isn't English, and they fail in translation.

## Words to swap

| Instead of | Write |
| --- | --- |
| utilize, leverage | use |
| in order to | to |
| allows you to, enables you to | lets you |
| execute (a command) | run |
| facilitate | help, let |
| desired | the one you want |
| e.g., i.e. | for example, that is |
| etc., and so on | finish the list, or name what bounds it |
| above, below (within a page) | earlier, preceding, later, following |
| make a decision, perform an analysis | decide, analyze |
| end result, past history, advance planning | result, history, planning |
| very, really, actually, basically | delete the word |
| sanity check, dummy value | completeness check, placeholder |
| kill, abort (a process) | stop, cancel, end |
| blacklist, whitelist | blocklist, allowlist |

A literal name stays literal. `git rebase --abort`, `SIGKILL`, and a
vendor's `whitelist` field keep their spelling — the table governs your
prose, never an identifier you're quoting.

Extend the table by shape, not by lookup: a verb buried in a noun (*do a
rewrite* → *rewrite*), a doubled word, an intensifier propping up a weak
claim, a metaphor of violence or disability standing in for a precise term.

## Terms

`README.md`, [Agent fleet — design](../fleet-design.md), and
[Operate the fleet](../operations.md) carry this repo's terms: agent, fleet, role, pod, relay, conductor, specialist, the
apply loop. They outrank Google's word list on any term they define. Use
them exactly, with their capitalization, and never rotate synonyms — a
second name for one concept reads as a second concept. Don't call the
relay "the server" in one paragraph and "the relay" in the next.

A term those pages define stays bare on first use. Spell out anything
else once — ACP (agent client protocol) — or give it a short inline
definition, or leave it out.

## Pages

- **Sentence case headings.** A task heading takes the bare infinitive:
  "Create an instance", not "Creating an instance". A concept heading takes
  a noun phrase: "Correlation semantics". Keep code font out of a heading
  unless the heading names a literal — an event, a file, a command, a flag —
  where the backticks are what mark it as one: "DPO — `dpo.jsonl`".
- **Descriptive link text** — the destination's title, capitalized as part
  of the sentence. Never *here*, *this page*, *click here*, or a bare URL.
  Punctuation goes outside the link.
- **One action per numbered step**, imperative verb first, result in the
  same step: "Click **Run**. The query results appear." Prefix an optional
  step with `Optional:`. A procedure with one step is a bullet, not a
  numbered list of one.
- **Bold for UI element names**, code font for code, paths, flags, and
  literal values. Don't name the element type: "Click **Save**", not "click
  the Save button".
- **No directional language** — *above*, *below*, *the left-hand side*. It
  breaks for screen readers and for any layout that reflows. Name or link
  the section instead.
- **Alt text on every image**, and a warning at the point of danger rather
  than in a preamble.
- **Draw the flow** when prose needs three tries. One diagram beats a
  paragraph describing a pipeline.

## Prose to the builder

Chat replies, PR descriptions, issue comments, commit message bodies, and
decision asks obey everything on this page. Answer first, and state
uncertainty plainly.
