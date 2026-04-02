# Graph Generation Prompt

This document contains the prompt used to generate `data/graph.json`. To regenerate or update the knowledge graph, feed this prompt to an AI assistant with web access, then replace `data/graph.json` with the output.

## How to use

1. Copy the prompt below into an AI assistant (Claude, ChatGPT, etc.) that can browse the web
2. The assistant will research current Cardano governance documentation and produce an updated `graph.json`
3. Validate the output: `node -e "const d=require('./data/graph.json'); console.log(d.nodes.length + ' nodes, ' + d.edges.length + ' edges')"`
4. Copy the output to both `data/graph.json` and `dist/data/graph.json`
5. Build and verify: `nix develop -c just ci`

## When to regenerate

- After a hard fork that changes governance rules
- When new governance action types or parameters are added
- When CIP-1694 is superseded or amended
- When protocol parameter values change significantly
- When links go stale (docs.cardano.org restructures periodically)

---

## Prompt

You are building a knowledge graph of Cardano's on-chain governance system for an interactive browser-based explorer. The graph must be output as a single JSON file with `nodes` and `edges` arrays.

### Sources

Research these sources IN ORDER OF AUTHORITY. When sources conflict, prefer earlier sources:

1. **CIP-1694 specification**: https://cips.cardano.org/cip/CIP-1694 — the canonical governance spec
2. **Cardano Foundation governance page**: https://cardanofoundation.org/governance — CF's educational materials
3. **docs.cardano.org governance overview**: https://docs.cardano.org/about-cardano/governance-overview
4. **developers.cardano.org governance model**: https://developers.cardano.org/docs/governance/cardano-governance/governance-model/
5. **developers.cardano.org governance actions**: https://developers.cardano.org/docs/governance/cardano-governance/governance-actions/
6. **developers.cardano.org constitutional committee guide**: https://developers.cardano.org/docs/governance/cardano-governance/constitutional-committee-guide/
7. **Cardano Foundation blog posts on governance**: https://cardanofoundation.org/blog/understanding-cardano-governance-actions, https://cardanofoundation.org/blog/strengthens-commitment-governance-drep
8. **GovTool documentation**: https://docs.gov.tools/overview/what-is-cardano-govtool
9. **Plutus cost model generation**: https://github.com/IntersectMBO/plutus/blob/master/plutus-core/cost-model/CostModelGeneration.md

### Important rules

- **Verify every URL** you include in the output. Fetch each URL and confirm it returns 200. Do not include broken links.
- **Use Cardano Foundation terminology and framing**. The CF is authoritative on how governance concepts are explained to the community.
- **Be substantive in descriptions**. Each node description should be 3-6 sentences explaining what the concept IS and WHY it matters. Each edge description should explain WHY the relationship exists, not just restate the label.
- **Include current parameter values** where relevant (e.g., govActionDeposit = 100,000 ada, dRepActivity = 20 epochs). Note these may change — the regenerator should look up current values.
- **Include voting thresholds** in action type descriptions and threshold mechanism descriptions.

### Node schema

Each node must have these fields:

```json
{
  "id": "kebab-case-unique-id",
  "label": "Human Readable Name",
  "kind": "one of: actor, action-type, process, mechanism, artifact, concept, param-group, parameter, tool",
  "group": "logical grouping: core, actors, actions, lifecycle, parameters, thresholds, framework, ecosystem",
  "description": "3-6 sentence description sourced from CF materials and CIP-1694. Explain what it IS and WHY it matters.",
  "links": [
    { "label": "Link display text", "url": "https://verified-working-url" }
  ]
}
```

### Edge schema

Each edge must have these fields:

```json
{
  "source": "source-node-id",
  "target": "target-node-id",
  "label": "short relationship label (2-5 words)",
  "description": "2-4 sentence explanation of WHY this relationship exists. Reference specific governance mechanics, thresholds, or rules."
}
```

### Required node kinds and what they cover

**actors** (kind: "actor") — entities that participate in governance:
- Ada holders, DReps, SPOs, Constitutional Committee
- Pre-defined voting options: Abstain, No Confidence
- Ecosystem entities: Intersect, Cardano Foundation

**action-type** (kind: "action-type") — the 7 governance action types:
- Motion of No-Confidence
- Update Committee / Threshold
- New Constitution / Guardrails Script
- Hard Fork Initiation
- Protocol Parameter Changes
- Treasury Withdrawal
- Info Action

**process** (kind: "process") — governance lifecycle stages:
- Voting, Ratification, Enactment, Bootstrap Phase

**mechanism** (kind: "mechanism") — rules and structures:
- Action Chaining, Deposit Mechanism, Security-Relevant Parameters
- DRep Voting Thresholds, SPO Voting Thresholds, CC Voting Threshold
- Hot/Cold Key System

**artifact** (kind: "artifact") — documents and scripts:
- Cardano Constitution, Guardrails Script, CIP-1694, Governance Metadata Standards

**concept** (kind: "concept") — abstract governance concepts:
- Cardano Governance (top-level), Liquid Democracy, Conway Ledger Era

**param-group** (kind: "param-group") — parameter categories:
- Network, Economic, Technical, Governance parameter groups

**parameter** (kind: "parameter") — specific notable parameters:
- Plutus Cost Models

**tool** (kind: "tool") — governance tooling:
- GovTool, SanchoNet

### Required edges

At minimum, include edges for:

- Ada holder → DRep (delegates voting power), Ada holder → SPO (delegates stake), Ada holder → Governance Action (submits), Ada holder → DRep (can register as)
- Ada holder → Abstain (can delegate to), Ada holder → No Confidence (can delegate to)
- Each governance body → the action types it votes on (with specific edges per action type, NOT a generic "votes on governance actions")
- CC → Constitution (evaluates actions against), CC → Hot/Cold Keys (uses)
- Each action type → Governance Action (is a type of)
- Governance Action → Ratification → Enactment (lifecycle flow)
- Governance Action → Voting, Voting → Ratification
- Governance Action → Action Chaining, Governance Action → Deposit Mechanism, Governance Action → Metadata Standards
- Action types that modify things → their targets (No-Confidence → CC, Update Committee → CC, New Constitution → Constitution, New Constitution → Guardrails Script)
- Protocol Parameter Changes → each parameter group
- Each parameter group → Security-Relevant Parameters (where applicable)
- Technical params → Cost Models
- Guardrails Script → Parameter Changes (constrains), Guardrails Script → Treasury (constrains)
- Constitution → Guardrails Script (codified in)
- Governance Model → each governance body, Governance Model → Liquid Democracy
- CIP-1694 → Governance Model (specifies), CIP-1694 → Conway Era (implemented in)
- Conway Era → Bootstrap Phase
- Each body → its threshold mechanism
- DRep/Governance Action → Deposit Mechanism
- Ecosystem entities → their roles
- Tools → what they enable

### Output format

Output a single JSON object:

```json
{
  "nodes": [ ... ],
  "edges": [ ... ]
}
```

No markdown wrapping, no commentary — just the JSON. Validate that:
- Every edge references existing node IDs
- No duplicate node IDs
- Every node has all required fields
- Every edge has all required fields including description
- All URLs are verified working
