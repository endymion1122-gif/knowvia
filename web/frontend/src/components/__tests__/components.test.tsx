import { describe, it, expect } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { EvidenceChain } from "../pathway/EvidenceChain";
import { ComparisonMatrix } from "../pathway/ComparisonMatrix";

const sampleNodes = [
  { id: "1", title: "概念A", card_type: "concept", content: "概念A的内容", confidence_score: 0.9, user_confirmed: true, user_summary: "我的理解A" },
  { id: "2", title: "观点B", card_type: "claim", content: "观点B的内容", confidence_score: 0.85, user_confirmed: false, user_summary: "" },
  { id: "3", title: "证据C", card_type: "evidence", content: "证据C的内容", confidence_score: 0.7, user_confirmed: true, user_summary: "" },
];

const sampleRelations = [
  { id: "r1", source_card_id: "1", target_card_id: "2", relation_type: "support" },
  { id: "r2", source_card_id: "3", target_card_id: "2", relation_type: "support" },
];

describe("EvidenceChain", () => {
  it("renders claims with evidence links", () => {
    render(
      <MemoryRouter>
        <EvidenceChain nodes={sampleNodes} relations={sampleRelations} />
      </MemoryRouter>
    );
    expect(screen.getByText("观点B")).toBeTruthy();
    expect(screen.getByText("1 条证据")).toBeTruthy();
  });

  it("shows empty state when no claims", () => {
    const conceptOnly = [sampleNodes[0]];
    render(
      <MemoryRouter>
        <EvidenceChain nodes={conceptOnly} relations={[]} />
      </MemoryRouter>
    );
    expect(screen.getByText(/暂无观点节点/)).toBeTruthy();
  });

  it("expands evidence on click", () => {
    render(
      <MemoryRouter>
        <EvidenceChain nodes={sampleNodes} relations={sampleRelations} />
      </MemoryRouter>
    );
    const claim = screen.getByText("观点B");
    fireEvent.click(claim);
    expect(screen.getByText("证据C")).toBeTruthy();
  });
});

describe("ComparisonMatrix", () => {
  it("renders node comparison table", () => {
    render(
      <MemoryRouter>
        <ComparisonMatrix nodes={sampleNodes} relations={sampleRelations} />
      </MemoryRouter>
    );
    expect(screen.getByText("概念A")).toBeTruthy();
    expect(screen.getByText("观点B")).toBeTruthy();
  });

  it("shows empty state for insufficient nodes", () => {
    render(
      <MemoryRouter>
        <ComparisonMatrix nodes={[sampleNodes[0]]} relations={[]} />
      </MemoryRouter>
    );
    expect(screen.getByText(/节点数量不足/)).toBeTruthy();
  });
});

