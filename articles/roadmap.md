# Roadmap: from an inherited database to control and value

You have inherited a large database: several schemas, hundreds of
tables, tens of thousands of columns, no documentation, and reports that
disagree. This is the order of work from there to a database that is
under control and useful to the business. Each phase answers one
question and produces a small number of things; each has a gate that the
next phase depends on.

## The six phases

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgOTYwIDMwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiBzdHlsZT0id2lkdGg6MTAwJTttYXgtd2lkdGg6OTYwcHg7Zm9udC1mYW1pbHk6c2Fucy1zZXJpZiI+PGRlZnM+PG1hcmtlciBpZD0iYXJyb3ciIHZpZXdib3g9IjAgMCAxMCAxMCIgcmVmeD0iOSIgcmVmeT0iNSIgbWFya2Vyd2lkdGg9IjgiIG1hcmtlcmhlaWdodD0iOCIgb3JpZW50PSJhdXRvLXN0YXJ0LXJldmVyc2UiPjxwYXRoIGQ9Ik0gMCAwIEwgMTAgNSBMIDAgMTAgeiIgZmlsbD0iIzU1NSIgLz48L21hcmtlcj48L2RlZnM+PGcgZm9udC1zaXplPSIxMyIgZmlsbD0iIzIyMiI+PCEtLSBwaGFzZSBib3hlcyAtLT48Zz48cmVjdCB4PSIxMCIgeT0iNjAiIHdpZHRoPSIxNDAiIGhlaWdodD0iOTAiIHJ4PSI4IiBmaWxsPSIjZGJlN2YzIiBzdHJva2U9IiMxZjRlNzkiIC8+PHRleHQgeD0iODAiIHk9Ijg1IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iYm9sZCI+MS4gS25vdyB3aGF0CmV4aXN0czwvdGV4dD48dGV4dCB4PSI4MCIgeT0iMTA4IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXNpemU9IjEyIj5XaGF0IGlzCnRoZXJlLDwvdGV4dD48dGV4dCB4PSI4MCIgeT0iMTI0IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXNpemU9IjEyIj5ob3cgYmlnLCBob3cKZnJlc2g/PC90ZXh0PjwvZz48Zz48cmVjdCB4PSIxNzAiIHk9IjYwIiB3aWR0aD0iMTQwIiBoZWlnaHQ9IjkwIiByeD0iOCIgZmlsbD0iI2RiZTdmMyIgc3Ryb2tlPSIjMWY0ZTc5IiAvPjx0ZXh0IHg9IjI0MCIgeT0iODUiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtd2VpZ2h0PSJib2xkIj4yLiBGaW5kIHRoZQpyZWFsIHRhYmxlczwvdGV4dD48dGV4dCB4PSIyNDAiIHk9IjEwOCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSIxMiI+V2hpY2ggZmV3CnRhYmxlcyBhcmU8L3RleHQ+PHRleHQgeD0iMjQwIiB5PSIxMjQiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc2l6ZT0iMTIiPnRoZSBzb3VyY2VzLApub3QgY29waWVzPzwvdGV4dD48L2c+PGc+PHJlY3QgeD0iMzMwIiB5PSI2MCIgd2lkdGg9IjE0MCIgaGVpZ2h0PSI5MCIgcng9IjgiIGZpbGw9IiNkYmU3ZjMiIHN0cm9rZT0iIzFmNGU3OSIgLz48dGV4dCB4PSI0MDAiIHk9Ijg1IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iYm9sZCI+My4gS2V5cyBhbmQKc3RydWN0dXJlPC90ZXh0Pjx0ZXh0IHg9IjQwMCIgeT0iMTA4IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXNpemU9IjEyIj5XaGF0IGlzIG9uZQpyb3csIGFuZDwvdGV4dD48dGV4dCB4PSI0MDAiIHk9IjEyNCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSIxMiI+aG93IGRvIHRhYmxlcwpqb2luPzwvdGV4dD48L2c+PGc+PHJlY3QgeD0iNDkwIiB5PSI2MCIgd2lkdGg9IjE0MCIgaGVpZ2h0PSI5MCIgcng9IjgiIGZpbGw9IiNkYmU3ZjMiIHN0cm9rZT0iIzFmNGU3OSIgLz48dGV4dCB4PSI1NjAiIHk9Ijg1IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iYm9sZCI+NC4KRG9jdW1lbnQ8L3RleHQ+PHRleHQgeD0iNTYwIiB5PSIxMDgiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc2l6ZT0iMTIiPldoYXQgZG9lcyBlYWNoCnRhYmxlPC90ZXh0Pjx0ZXh0IHg9IjU2MCIgeT0iMTI0IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXNpemU9IjEyIj5hbmQgdGVybQptZWFuPzwvdGV4dD48L2c+PGc+PHJlY3QgeD0iNjUwIiB5PSI2MCIgd2lkdGg9IjE0MCIgaGVpZ2h0PSI5MCIgcng9IjgiIGZpbGw9IiNkYmU3ZjMiIHN0cm9rZT0iIzFmNGU3OSIgLz48dGV4dCB4PSI3MjAiIHk9Ijg1IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iYm9sZCI+NS4KQ29udHJvbDwvdGV4dD48dGV4dCB4PSI3MjAiIHk9IjEwOCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSIxMiI+V2hvIG93bnMgaXQsCndoYXQgaXM8L3RleHQ+PHRleHQgeD0iNzIwIiB5PSIxMjQiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc2l6ZT0iMTIiPnRlc3RlZCwgaG93IHRvCmNoYW5nZSBpdD88L3RleHQ+PC9nPjxnPjxyZWN0IHg9IjgxMCIgeT0iNjAiIHdpZHRoPSIxNDAiIGhlaWdodD0iOTAiIHJ4PSI4IiBmaWxsPSIjZmJlNWM4IiBzdHJva2U9IiNiMzZiMDAiIC8+PHRleHQgeD0iODgwIiB5PSI4NSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC13ZWlnaHQ9ImJvbGQiPjYuClZhbHVlPC90ZXh0Pjx0ZXh0IHg9Ijg4MCIgeT0iMTA4IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXNpemU9IjEyIj5PbmUgYWdyZWVkCm1vZGVsIHRoZTwvdGV4dD48dGV4dCB4PSI4ODAiIHk9IjEyNCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSIxMiI+YnVzaW5lc3MgY2FuCnF1ZXJ5PC90ZXh0PjwvZz48IS0tIGFycm93cyAtLT48ZyBzdHJva2U9IiM1NTUiIHN0cm9rZS13aWR0aD0iMiIgbWFya2VyLWVuZD0idXJsKCNhcnJvdykiPjxsaW5lIHgxPSIxNTAiIHkxPSIxMDUiIHgyPSIxNjgiIHkyPSIxMDUiPjwvbGluZT48bGluZSB4MT0iMzEwIiB5MT0iMTA1IiB4Mj0iMzI4IiB5Mj0iMTA1Ij48L2xpbmU+PGxpbmUgeDE9IjQ3MCIgeTE9IjEwNSIgeDI9IjQ4OCIgeTI9IjEwNSI+PC9saW5lPjxsaW5lIHgxPSI2MzAiIHkxPSIxMDUiIHgyPSI2NDgiIHkyPSIxMDUiPjwvbGluZT48bGluZSB4MT0iNzkwIiB5MT0iMTA1IiB4Mj0iODA4IiB5Mj0iMTA1Ij48L2xpbmU+PC9nPjwhLS0gd2hvIC0tPjxnIGZvbnQtc2l6ZT0iMTIiIGZpbGw9IiM0NDQiPjx0ZXh0IHg9IjgwIiB5PSIxODAiIHRleHQtYW5jaG9yPSJtaWRkbGUiPkNvZGU8L3RleHQ+PHRleHQgeD0iMjQwIiB5PSIxODAiIHRleHQtYW5jaG9yPSJtaWRkbGUiPkNvZGUgcHJvcG9zZXMsPC90ZXh0Pjx0ZXh0IHg9IjI0MCIgeT0iMTk2IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIj5vd25lcnMgY29uZmlybTwvdGV4dD48dGV4dCB4PSI0MDAiIHk9IjE4MCIgdGV4dC1hbmNob3I9Im1pZGRsZSI+Q29kZSB0ZXN0cyw8L3RleHQ+PHRleHQgeD0iNDAwIiB5PSIxOTYiIHRleHQtYW5jaG9yPSJtaWRkbGUiPnRlYW0gZGVjaWRlczwvdGV4dD48dGV4dCB4PSI1NjAiIHk9IjE4MCIgdGV4dC1hbmNob3I9Im1pZGRsZSI+RHJhZnRlZCBieSBjb2RlLDwvdGV4dD48dGV4dCB4PSI1NjAiIHk9IjE5NiIgdGV4dC1hbmNob3I9Im1pZGRsZSI+cmV2aWV3ZWQgYnkgcGVvcGxlPC90ZXh0Pjx0ZXh0IHg9IjcyMCIgeT0iMTgwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIj5UaHJlZSB0ZWFtcyBhZ3JlZTwvdGV4dD48dGV4dCB4PSI4ODAiIHk9IjE4MCIgdGV4dC1hbmNob3I9Im1pZGRsZSI+TW9kZWxsZXI8L3RleHQ+PC9nPjwhLS0gZ2F0ZXMgLS0+PGcgZm9udC1zaXplPSIxMiIgZmlsbD0iIzFmNGU3OSI+PHRleHQgeD0iODAiIHk9IjI0MCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zdHlsZT0iaXRhbGljIj5HYXRlOgpldmVyeXRoaW5nPC90ZXh0Pjx0ZXh0IHg9IjgwIiB5PSIyNTYiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc3R5bGU9Iml0YWxpYyI+cHJvZmlsZWQ8L3RleHQ+PHRleHQgeD0iMjQwIiB5PSIyNDAiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc3R5bGU9Iml0YWxpYyI+R2F0ZToKY2Fub25pY2FsIGxpc3Q8L3RleHQ+PHRleHQgeD0iMjQwIiB5PSIyNTYiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc3R5bGU9Iml0YWxpYyI+YWdyZWVkPC90ZXh0Pjx0ZXh0IHg9IjQwMCIgeT0iMjQwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXN0eWxlPSJpdGFsaWMiPkdhdGU6CmdyYWluIHN0YXRlZCw8L3RleHQ+PHRleHQgeD0iNDAwIiB5PSIyNTYiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc3R5bGU9Iml0YWxpYyI+a2V5cwp0ZXN0ZWQ8L3RleHQ+PHRleHQgeD0iNTYwIiB5PSIyNDAiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc3R5bGU9Iml0YWxpYyI+R2F0ZToKZGljdGlvbmFyeTwvdGV4dD48dGV4dCB4PSI1NjAiIHk9IjI1NiIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zdHlsZT0iaXRhbGljIj5yZXZpZXdlZDwvdGV4dD48dGV4dCB4PSI3MjAiIHk9IjI0MCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zdHlsZT0iaXRhbGljIj5HYXRlOgpzdGV3YXJkcyBuYW1lZCw8L3RleHQ+PHRleHQgeD0iNzIwIiB5PSIyNTYiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc3R5bGU9Iml0YWxpYyI+dGVzdHMKZ3JlZW48L3RleHQ+PC9nPjx0ZXh0IHg9IjEwIiB5PSIzMCIgZm9udC1zaXplPSIxMiIgZmlsbD0iIzQ0NCI+QmVmb3JlCmFueSBvZiB0aGlzOiBhIHJlYWQtb25seSBsb2dpbiwgYW5kIGEgaG9tZSBmb3IgdGhlIG91dHB1dHMgdGhhdCBob2xkcyBubwpwYXRpZW50IGRhdGEuPC90ZXh0PjwvZz48L3N2Zz4=)

## How the problem shrinks

Each phase makes the next one smaller. Profiling shows which tables are
copies; choosing the real ones leaves a few dozen to document;
documenting those states the keys; the keys are what the model is built
from.

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgOTYwIDIzMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiBzdHlsZT0id2lkdGg6MTAwJTttYXgtd2lkdGg6OTYwcHg7Zm9udC1mYW1pbHk6c2Fucy1zZXJpZiI+PGcgZm9udC1zaXplPSIxMyIgZmlsbD0iIzIyMiI+PHBvbHlnb24gcG9pbnRzPSIyMCwzMCA5NDAsMzAgNzAwLDIwMCAyNjAsMjAwIiBmaWxsPSIjZWVmM2Y4IiBzdHJva2U9IiMxZjRlNzkiPjwvcG9seWdvbj48bGluZSB4MT0iMTUwIiB5MT0iMzAiIHgyPSIzMDAiIHkyPSIyMDAiIHN0cm9rZT0iIzFmNGU3OSIgc3Ryb2tlLWRhc2hhcnJheT0iNCA0Ij48L2xpbmU+PGxpbmUgeDE9IjgxMCIgeTE9IjMwIiB4Mj0iNjYwIiB5Mj0iMjAwIiBzdHJva2U9IiMxZjRlNzkiIHN0cm9rZS1kYXNoYXJyYXk9IjQgNCI+PC9saW5lPjx0ZXh0IHg9IjQ4MCIgeT0iNjAiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtd2VpZ2h0PSJib2xkIj43MDAgdGFibGVzLAoyOCwwMDAgY29sdW1uczwvdGV4dD48dGV4dCB4PSI0ODAiIHk9IjgwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXNpemU9IjEyIj5hbGwgcHJvZmlsZWQgYnkKY29kZSAocGhhc2UgMSk8L3RleHQ+PHRleHQgeD0iNDgwIiB5PSIxMjAiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtd2VpZ2h0PSJib2xkIj40MCB0byA4MApjYW5vbmljYWwgdGFibGVzPC90ZXh0Pjx0ZXh0IHg9IjQ4MCIgeT0iMTQwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXNpemU9IjEyIj50aGUgcmVzdAptYXJrZWQgYXMgY29waWVzLCBhZ2dyZWdhdGVzIG9yIHN1YnNldHMgKHBoYXNlIDIpPC90ZXh0Pjx0ZXh0IHg9IjQ4MCIgeT0iMTc1IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iYm9sZCI+QSBkb3plbgplbnRpdGllcywgdGhlaXIga2V5cyBhbmQgam9pbnM8L3RleHQ+PHRleHQgeD0iNDgwIiB5PSIxOTIiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc2l6ZT0iMTIiPmRvY3VtZW50ZWQsCnRlc3RlZCBhbmQgb3duZWQgKHBoYXNlcyAzIHRvIDUpPC90ZXh0PjwvZz48L3N2Zz4=)

Documentation effort goes only to the canonical set. Nothing is
described by hand at the scale of 28,000 columns.

## What each phase produces

The artefacts, numbered as in the original plan. “Needs” is the artefact
each one depends on, which is why the order is what it is.

### Phase 1: know what exists

Built: one run of
[`inventory_run()`](https://thomuk.github.io/DBinventory/reference/inventory_run.md)
produces both.

| \# | Artefact | What it holds | Where it lives | Who writes it | Needs |
|----|----|----|----|----|----|
| 1 | **Inventory** | Every table and column: schema, name, type, row count, size, newest datetime, when profiled | A SQLite store, exported as CSV or Parquet | Code, re-run on a schedule | Read access only |
| 2 | **Column profile** | Per column: null rate, distinct count, min and max, top values, inferred type (identifier, date, code, free text, flag), uniqueness, fingerprint | Same store, one row per column | Code | 1 |

The first run already answers questions people ask: which tables are
stale, which are empty, where the volume is, which columns hold personal
data.

### Phase 2: find the real tables

| \# | Artefact | What it holds | Where it lives | Who writes it | Needs |
|----|----|----|----|----|----|
| 3 | **Duplicate and lineage map** | Groups of tables and columns that hold the same thing; for each group the canonical member, the others marked copy, aggregate, filtered subset or unknown | Same store, plus a short rationale per group | Code proposes, a person confirms | 2 |
| 4 | **Naming and classification standard** | Table classes (source, reference, derived, scratch); status values (canonical, duplicate, deprecated); sensitivity classes; naming rules for anything new | Two pages of Markdown in the repository | The team, agreed with the warehouse owners | Written alongside 3 |

This is the first phase that needs the warehouse owners in the room. The
canonical list is a claim about which copy is right, and they know
things the profile cannot show.

### Phase 3: keys and structure

Started: the profile marks primary key candidates and proposes foreign
keys. Confirming them is the key register’s job.

| \# | Artefact | What it holds | Where it lives | Who writes it | Needs |
|----|----|----|----|----|----|
| 7 | **Conceptual entity model** | The dozen core entities (patient, pathway, referral, spell, episode, attendance, ward stay) and how they nest; the shared dimensions (patient, date, site, specialty, consultant, ward) | One diagram plus a table pointing each entity at its canonical table | The team | 5, 6 (begins alongside them) |
| 8 | **Key register** | Per entity: the identifier columns, every table carrying them, tests of uniqueness, nulls and match rate against the canonical table | Table in the store, tests in code | Code tests, a person interprets | 5, 7 |

The one field that matters most is **grain**: one row is one what. Every
later decision about what can be added up and which joins multiply rows
depends on it.

### Phase 4: document the canonical set

| \# | Artefact | What it holds | Where it lives | Who writes it | Needs |
|----|----|----|----|----|----|
| 5 | **Data dictionary** | For each canonical table: description, grain, keys, owner, source system, refresh cadence, known quirks; for each column: description, valid values, nullability, sensitivity | One file per table, rendered to a browsable site; shape borrowed from the Open Data Contract Standard | Drafted by code from the profile, reviewed by people; each row marked drafted or reviewed | 3, 4 |
| 6 | **Business glossary** | Terms, not columns: referral, clock start, spell, episode, attendance, DNA, breach; each with a definition, the NHS Data Dictionary reference, local variations, and which columns carry it | One entry per term | The team drafts; the definitions team is invited to correct | 5 exposes the terms |

### Phase 5: control

| \# | Artefact | What it holds | Where it lives | Who writes it | Needs |
|----|----|----|----|----|----|
| 9 | **Metric definition register** | Each metric as observed: name, where seen, apparent numerator, denominator, filters, grain, owner, date observed, agreement or disagreement with other observations | One file per metric; provenance required, SQL optional | The team records; the definitions team owns the content | 6, 8 |
| 10 | **Data quality baseline** | Automated tests on the canonical set: key uniqueness, referential integrity, freshness, row-count drift; run on a schedule, results logged | Test suite in code | Code | 8 |
| 11 | **Stewardship and change control** | Who owns each canonical table and term; how a change is proposed, reviewed and logged; what “certified” means and who grants it | One page plus a change log | Agreed between the three teams | 4 |

The metric register records what was seen and never asserts a correct
answer. Two definitions of the same metric sit side by side with where
each was seen. That is what people are asking for when they ask for
numbers that agree.

### Phase 6: value

With the gates passed, the semantic model is assembled rather than
invented: entities from 7, relationships from 8, dimensions and
descriptions from 5 and 6, metrics from 9. The business queries one
agreed model; the duplicate tables can be retired because the canonical
set is known, tested and owned.

## How the artefacts depend on each other

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgOTYwIDI1MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiBzdHlsZT0id2lkdGg6MTAwJTttYXgtd2lkdGg6OTYwcHg7Zm9udC1mYW1pbHk6c2Fucy1zZXJpZiI+PGRlZnM+PG1hcmtlciBpZD0iYXJyb3cyIiB2aWV3Ym94PSIwIDAgMTAgMTAiIHJlZng9IjkiIHJlZnk9IjUiIG1hcmtlcndpZHRoPSI3IiBtYXJrZXJoZWlnaHQ9IjciIG9yaWVudD0iYXV0by1zdGFydC1yZXZlcnNlIj48cGF0aCBkPSJNIDAgMCBMIDEwIDUgTCAwIDEwIHoiIGZpbGw9IiM1NTUiIC8+PC9tYXJrZXI+PC9kZWZzPjxnIGZvbnQtc2l6ZT0iMTIiIGZpbGw9IiMyMjIiPjxnPjxyZWN0IHg9IjEwIiB5PSIxMDAiIHdpZHRoPSIxMTAiIGhlaWdodD0iNDAiIHJ4PSI2IiBmaWxsPSIjZGJlN2YzIiBzdHJva2U9IiMxZjRlNzkiIC8+PHRleHQgeD0iNjUiIHk9IjEyNCIgdGV4dC1hbmNob3I9Im1pZGRsZSI+MQpJbnZlbnRvcnk8L3RleHQ+PHJlY3QgeD0iMTUwIiB5PSIxMDAiIHdpZHRoPSIxMTAiIGhlaWdodD0iNDAiIHJ4PSI2IiBmaWxsPSIjZGJlN2YzIiBzdHJva2U9IiMxZjRlNzkiIC8+PHRleHQgeD0iMjA1IiB5PSIxMjQiIHRleHQtYW5jaG9yPSJtaWRkbGUiPjIKUHJvZmlsZTwvdGV4dD48cmVjdCB4PSIyOTAiIHk9IjEwMCIgd2lkdGg9IjExMCIgaGVpZ2h0PSI0MCIgcng9IjYiIGZpbGw9IiNkYmU3ZjMiIHN0cm9rZT0iIzFmNGU3OSIgLz48dGV4dCB4PSIzNDUiIHk9IjEyNCIgdGV4dC1hbmNob3I9Im1pZGRsZSI+MwpEdXBsaWNhdGUgbWFwPC90ZXh0PjxyZWN0IHg9IjI5MCIgeT0iMTcwIiB3aWR0aD0iMTEwIiBoZWlnaHQ9IjQwIiByeD0iNiIgZmlsbD0iI2VlZWVlZSIgc3Ryb2tlPSIjNzc3IiAvPjx0ZXh0IHg9IjM0NSIgeT0iMTk0IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIj40ClN0YW5kYXJkPC90ZXh0PjxyZWN0IHg9IjQzMCIgeT0iMTAwIiB3aWR0aD0iMTEwIiBoZWlnaHQ9IjQwIiByeD0iNiIgZmlsbD0iI2RiZTdmMyIgc3Ryb2tlPSIjMWY0ZTc5IiAvPjx0ZXh0IHg9IjQ4NSIgeT0iMTI0IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIj41CkRpY3Rpb25hcnk8L3RleHQ+PHJlY3QgeD0iNDMwIiB5PSIzMCIgd2lkdGg9IjExMCIgaGVpZ2h0PSI0MCIgcng9IjYiIGZpbGw9IiNkYmU3ZjMiIHN0cm9rZT0iIzFmNGU3OSIgLz48dGV4dCB4PSI0ODUiIHk9IjU0IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIj42Ckdsb3NzYXJ5PC90ZXh0PjxyZWN0IHg9IjU3MCIgeT0iMTAwIiB3aWR0aD0iMTEwIiBoZWlnaHQ9IjQwIiByeD0iNiIgZmlsbD0iI2RiZTdmMyIgc3Ryb2tlPSIjMWY0ZTc5IiAvPjx0ZXh0IHg9IjYyNSIgeT0iMTI0IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIj43CkVudGl0eSBtb2RlbDwvdGV4dD48cmVjdCB4PSI1NzAiIHk9IjE3MCIgd2lkdGg9IjExMCIgaGVpZ2h0PSI0MCIgcng9IjYiIGZpbGw9IiNkYmU3ZjMiIHN0cm9rZT0iIzFmNGU3OSIgLz48dGV4dCB4PSI2MjUiIHk9IjE5NCIgdGV4dC1hbmNob3I9Im1pZGRsZSI+OApLZXkgcmVnaXN0ZXI8L3RleHQ+PHJlY3QgeD0iNzEwIiB5PSIzMCIgd2lkdGg9IjExMCIgaGVpZ2h0PSI0MCIgcng9IjYiIGZpbGw9IiNkYmU3ZjMiIHN0cm9rZT0iIzFmNGU3OSIgLz48dGV4dCB4PSI3NjUiIHk9IjU0IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIj45Ck1ldHJpYyByZWdpc3RlcjwvdGV4dD48cmVjdCB4PSI3MTAiIHk9IjE3MCIgd2lkdGg9IjExMCIgaGVpZ2h0PSI0MCIgcng9IjYiIGZpbGw9IiNkYmU3ZjMiIHN0cm9rZT0iIzFmNGU3OSIgLz48dGV4dCB4PSI3NjUiIHk9IjE5NCIgdGV4dC1hbmNob3I9Im1pZGRsZSI+MTAKUXVhbGl0eSB0ZXN0czwvdGV4dD48cmVjdCB4PSI0MzAiIHk9IjE5MCIgd2lkdGg9IjExMCIgaGVpZ2h0PSI0MCIgcng9IjYiIGZpbGw9IiNlZWVlZWUiIHN0cm9rZT0iIzc3NyIgLz48dGV4dCB4PSI0ODUiIHk9IjIxNCIgdGV4dC1hbmNob3I9Im1pZGRsZSI+MTEKU3Rld2FyZHNoaXA8L3RleHQ+PHJlY3QgeD0iODUwIiB5PSIxMDAiIHdpZHRoPSIxMDAiIGhlaWdodD0iNDAiIHJ4PSI2IiBmaWxsPSIjZmJlNWM4IiBzdHJva2U9IiNiMzZiMDAiIC8+PHRleHQgeD0iOTAwIiB5PSIxMjQiIHRleHQtYW5jaG9yPSJtaWRkbGUiPlNlbWFudGljCm1vZGVsPC90ZXh0PjwvZz48ZyBzdHJva2U9IiM1NTUiIHN0cm9rZS13aWR0aD0iMS41IiBmaWxsPSJub25lIiBtYXJrZXItZW5kPSJ1cmwoI2Fycm93MikiPjxsaW5lIHgxPSIxMjAiIHkxPSIxMjAiIHgyPSIxNDgiIHkyPSIxMjAiPjwvbGluZT48bGluZSB4MT0iMjYwIiB5MT0iMTIwIiB4Mj0iMjg4IiB5Mj0iMTIwIj48L2xpbmU+PGxpbmUgeDE9IjQwMCIgeTE9IjEyMCIgeDI9IjQyOCIgeTI9IjEyMCI+PC9saW5lPjxsaW5lIHgxPSIzNDUiIHkxPSIxNzAiIHgyPSIzNDUiIHkyPSIxNDIiPjwvbGluZT48bGluZSB4MT0iNDAwIiB5MT0iMTkwIiB4Mj0iNDI4IiB5Mj0iMjAwIj48L2xpbmU+PGxpbmUgeDE9IjQ4NSIgeTE9IjEwMCIgeDI9IjQ4NSIgeTI9IjcyIj48L2xpbmU+PGxpbmUgeDE9IjU0MCIgeTE9IjEyMCIgeDI9IjU2OCIgeTI9IjEyMCI+PC9saW5lPjxsaW5lIHgxPSI1NDAiIHkxPSIxMzAiIHgyPSI1NjgiIHkyPSIxODAiPjwvbGluZT48bGluZSB4MT0iNjI1IiB5MT0iMTQyIiB4Mj0iNjI1IiB5Mj0iMTY4Ij48L2xpbmU+PGxpbmUgeDE9IjU0MCIgeTE9IjUwIiB4Mj0iNzA4IiB5Mj0iNTAiPjwvbGluZT48bGluZSB4MT0iNjgwIiB5MT0iMTgwIiB4Mj0iNzA4IiB5Mj0iMTkwIj48L2xpbmU+PGxpbmUgeDE9IjY4MCIgeTE9IjE3NSIgeDI9IjcyMCIgeTI9IjcyIj48L2xpbmU+PGxpbmUgeDE9IjY4MCIgeTE9IjEyMCIgeDI9Ijg0OCIgeTI9IjEyMCI+PC9saW5lPjxsaW5lIHgxPSI4MjAiIHkxPSI2MCIgeDI9Ijg2MCIgeTI9Ijk4Ij48L2xpbmU+PGxpbmUgeDE9IjgyMCIgeTE9IjE4MCIgeDI9Ijg2MCIgeTI9IjE0MiI+PC9saW5lPjwvZz48dGV4dCB4PSIxMCIgeT0iMjQwIiBmb250LXNpemU9IjEyIiBmaWxsPSIjNDQ0Ij5CbHVlOiBwcm9kdWNlZCBtb3N0bHkgYnkKY29kZS4gR3JleTogd3JpdHRlbiBieSBwZW9wbGUuIE9yYW5nZTogdGhlIGdvYWwuPC90ZXh0PjwvZz48L3N2Zz4=)

## Three rules that run through all of it

- **Triage, do not document.** Find the few real sources; mark the rest
  as copies.
- **Generate, then review.** Code drafts; a person approves before
  anything is called reviewed.
- **Record what was seen, not who is right.** Definitions are logged
  with their provenance; disagreement is made visible, not settled by
  the register.

## Where we are

- **Built**: phase 1 in full, and the candidate half of phase 3 (primary
  and foreign key candidates with evidence and confidence).
- **Next**: table clustering with a proposed canonical member (phase 2),
  then confirming the keys with match-rate tests (phase 3), then
  dictionary drafts from the profile (phase 4).
- **Not code**: the standard, the glossary, the metric register and
  stewardship are pages and agreements between teams. The package keeps
  the inventory and tests current so that what the stewards sign off
  stays true.

## Ready for the semantic model when

- A canonical table exists for every core entity, agreed with the
  warehouse owners.
- Every canonical table has a reviewed grain and a tested primary key.
- Joins between core entities are in the key register with passing
  tests.
- The glossary covers the terms the first metrics use.
- The metric register holds the first few metrics with provenance.
- Someone is named as steward for each canonical table.
