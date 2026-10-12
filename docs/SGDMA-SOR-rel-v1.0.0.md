# SG DMA — Statement of Requirements (SOR)

| 항목 | 내용 |
|---|---|
| 문서 ID | SGDMA-SOR-rel-v1.0.0 |
| 작성일 | 2026-10-06 |
| 작성자 | hrcho |
| 대상 DUT | `rtl/sg_dma/sgdma_top.v` (ADI `axi_dmac` 기반 SG DMA) |
| DUT 버전 | `VERSION` = `0x0004_0565` (4.05.65) |
| HDL 출처 | `analogdevicesinc/hdl` `hdl_2026_r1` / `b62abeff` |
| 검증 레벨 | **IP DV (block-level)** — SoC DV는 범위 밖 |
| 요구사항 | **61건** |
| 상태 | **검증팀 인계본 — 전 항목 미검증(⬜)** |
| 원본문서 | $repo/docs/ref_hrcho/261006-claude-sgdma_sor-002-hrcho.md |

## 관련 문서

| 문서 | 역할 |
|---|---|
| [`SGDMA-SFR-rel-v1.0.0.md`](SGDMA-SFR-rel-v1.0.0.md) | **SFR 상세** — 비트 필드, 리셋값, 근거 등급(M/R/D) |
| [`SGDMA-SANITY-rel-v1.0.0.md`](SGDMA-SANITY-rel-v1.0.0.md) | **Sanity Test** — 회귀 게이트 46 checks. [2-3](#2-3-sanity-test) |
| `$repo/docs/ref_hrcho/260930-claude-rtl_design_crosscheck-hrcho.md` | RTL 구성 교차 검증 (0-replication 패치 근거) |

> **상태 표기에 대하여.** Sanity Test(46 checks)가 이미 통과한 항목이라도 본 문서에서는
> **전부 ⬜(미검증)으로 표기한다.** Sanity는 회귀 게이트이지 요구사항 검증 근거가 아니며,
> **검증팀이 자체 환경에서 독립적으로 재검증**하는 것을 전제로 한다. Sanity가 무엇을
> 확인했는지는 [2-3](#2-3-sanity-test)의 문서를 참조한다.

---

## 목차

- [1. Introduction](#1-introduction)
  - [1-1. Purpose](#1-1-purpose)
  - [1-2. Scope](#1-2-scope)
- [2. IP Description](#2-ip-description)
  - [2-1. IP Overview](#2-1-ip-overview)
  - [2-2. SFR Map](#2-2-sfr-map)
  - [2-3. Sanity Test](#2-3-sanity-test)
- [3. Verification Requirements](#3-verification-requirements)
  - [3-1. Reset / Clock](#3-1-reset--clock)
  - [3-2. Connectivity](#3-2-connectivity)
  - [3-3. Register Access](#3-3-register-access)
  - [3-4. Interrupt](#3-4-interrupt)
  - [3-5. Low Power](#3-5-low-power)
  - [3-6. Security](#3-6-security)
  - [3-7. AXI Protocol](#3-7-axi-protocol)
  - [3-8. IP Core Function](#3-8-ip-core-function)
    - [3-8-1. DESC — Descriptor 처리](#3-8-1-desc--descriptor-처리)
    - [3-8-2. FUNC — 전송 기능](#3-8-2-func--전송-기능)
    - [3-8-3. ERR — 에러 · 예외 처리](#3-8-3-err--에러--예외-처리)
  - [3-9. Coverage Measurement (Optional)](#3-9-coverage-measurement-optional)
- [부록 A. 요구사항 ↔ 시나리오 추적성](#부록-a-요구사항--시나리오-추적성)
  - [A-1. 요구사항 분포](#a-1-요구사항-분포)
  - [A-2. 추적성 매트릭스](#a-2-추적성-매트릭스)
- [부록 B. 시나리오 목록](#부록-b-시나리오-목록)
  - [B-1. Priority A — Sanity](#b-1-priority-a--sanity)
  - [B-2. Priority B — Feature](#b-2-priority-b--feature)
  - [B-3. Priority C ~ E](#b-3-priority-c--e)
  - [B-4. 작성 우선순위](#b-4-작성-우선순위)
- [부록 C. 미확정 항목](#부록-c-미확정-항목)
- [부록 D. 가정 및 제약](#부록-d-가정-및-제약)
- [부록 E. 개정 이력](#부록-e-개정-이력)

---

# 1. Introduction

## 1-1. Purpose

본 문서는 **SG(Scatter-Gather) DMA IP의 기능 검증 요구사항**을 정의한다.

"무엇이 동작해야 하는가"를 검증 가능한 단위로 기술하고, 각 요구사항을 확인하는 **검증 시나리오를 같은 절에 함께** 둔다. 각 요구사항은 고유 ID를 가지며, Sanity Test 문서와 TB 구현이 이 ID를 참조해 추적성을 확보한다.

### 요구사항의 출처

본 SOR은 세 소스에서 도출되었다. **스펙에서 도출하고 TB로 누락을 점검**하는 순서를 따랐으며, TB에서 역산하지 않았다.

| 출처 | 역할 |
|---|---|
| **① 스펙** | AXI DMAC HDL 문서, Register Map, Theory of Operation — 기능 정의 |
| **② RTL** | `dmac_sg.v`, `axi_dmac_regmap*.v`, `axi_dmac.v` — 구현 확인, 스펙 미기재 동작 |
| **③ 실측** | Sanity Test 46 checks (2026-10-02) — 동작 확정 |
| ④ 기존 TB | 우리 bring-up TB, ADI `dma_sg` TB — **누락 점검용** (요구사항 생성 소스 아님) |

ADI가 제공하는 `dma_sg` testbench는 **분석 및 참고 자료**로 활용했다. 이식이나 재현은 목표가 아니며, 얻은 것은 시나리오 아이디어(특히 transfer queueing)와 요구사항 누락에 대한 교차 확인 두 가지다.

### 검증 상태 표기

| 표기 | 의미 |
|:--:|---|
| **⬜** | **미검증 — 검증팀 수행 대상.** 본 개정에서는 전 요구사항이 여기에 해당한다 |
| **[확인 필요]** | 동작 자체가 확정되지 않음. RTL 재확인 또는 실험으로 **먼저 확정**해야 시나리오를 쓸 수 있다 |

Sanity Test가 이미 통과한 항목도 ⬜로 둔다. **Sanity는 회귀 게이트이지 요구사항 검증
근거가 아니며, 검증팀이 자체 환경에서 독립적으로 재검증한다.** 어떤 항목이 Sanity와
겹치는지는 [부록 A-2](#a-2-추적성-매트릭스)의 시나리오 열에서 `SAN-` 접두사로 확인할 수 있다.

---

## 1-2. Scope

### 검증 대상

**SG 전송 경로 전체** — descriptor fetch부터 데이터 전송, 완료 보고까지. 이를 위해 SG 동작에 관여하는 레지스터, AXI 프로토콜 준수, 인터럽트, 에러 처리를 함께 다룬다.

DUT는 `sgdma_top` wrapper로 고정된 **MM→MM + SG, 단일 클럭, 32bit 주소** 구성이다.

### 범위 밖 (Out of Scope)

`axi_dmac`은 SG 외에도 다수의 기능을 갖는 범용 DMA이나, 아래 기능은 **SG 검증에 필요하지 않으므로** 대상이 아니다. wrapper에서 파라미터를 비활성화하여 **물리적으로도 제외**하였다(해당 RTL이 인스턴스화되지 않음).

| 기능 | 비활성 방법 | 제외 사유 |
|---|---|---|
| **AXI-Stream 인터페이스** | `DMA_TYPE_SRC/DEST = 0` | SG는 인터페이스 종류와 무관하게 동작한다. 오히려 MM→MM이어야 `DMA_LENGTH_ALIGN = 0`이 되어 **바이트 단위 길이 검증이 가능**하다 |
| **2D 전송** | `DMA_2D_TRANSFER = 0` | SG 위에 얹는 별개 기능. ADI TB도 2D=0 구성에서 SG 테스트를 수행하여 2D 없이 SG 검증이 성립함을 보인다 |
| **Cyclic 전송** | `CYCLIC = 0` | SG와 직교하는 전송 모드. cyclic은 EOT 인터럽트를 발생시키지 않아 SG 체인 완료 판정과 충돌한다 |
| **비동기 클럭 (CDC)** | `ASYNC_CLK_* = 0` (6개) | 클럭 도메인 구성은 SG 로직과 무관. **SoC 통합 시 별도 검증 대상** |
| Framelock | `FRAMELOCK = 0` | 비디오 프레임 동기화 전용 |
| AutoRun | `AUTORUN = 0` | SW 개입 없는 자동 전송 |
| External Sync | `USE_EXT_SYNC = 0` | 외부 신호 동기화 |
| Transfer Start Sync | `SYNC_TRANSFER_START = 0` | 스트림 정렬용 |
| Cache Coherent | `CACHE_COHERENT = 0` | — |
| Diagnostics IF | `ENABLE_DIAGNOSTICS_IF = 0` | 디버그 전용 |
| Asymmetric memory | `ALLOW_ASYM_MEM = 0` | src/dest 폭 비대칭 |
| **64bit 주소** | `DMA_AXI_ADDR_WIDTH = 32` | HIGH 레지스터군 미사용 — 2026-10-02 설계 결정 |
| **성능 측정** | — | 현 TB 메모리 모델이 single outstanding이라 측정이 무의미. **multiple outstanding 지원 후 별도 다룸** |
| **구성 회귀** | — | `MAX_BYTES_PER_BURST` / `FIFO_SIZE` / 데이터 폭 스윕은 **별도 회귀 빌드**로 수행 |

### 제외 판단 기준

기준은 하나다. **"SG 전송의 정확성을 확인하는 데 이 기능이 필요한가."**

필요하지 않으면 제외한다. 유용한 기능인지, 나중에 쓸 가능성이 있는지는 판단 대상이 아니다. 그런 기능은 해당 기능을 검증할 때 별도 SOR로 다룬다.

> **향후 확장 시:** SoC 통합 단계에서 비동기 클럭이, 응용에 따라 2D·Cyclic이 필요해질 수
> 있다. 그때는 본 문서를 개정하는 것이 아니라 **해당 기능에 대한 별도 SOR**을 작성한다.
> 본 문서는 SG 검증에 집중한다.

### 검증 레벨

| 레벨 | 본 문서 | 비고 |
|---|:--:|---|
| **IP DV (block-level)** | **대상** | 단일 IP를 TB에 직접 연결 |
| SoC DV (integration) | 범위 밖 | interconnect 연결, 주소 디코딩, 다중 마스터 경합 |
| Gate-level / STA | 범위 밖 | |

---

# 2. IP Description

## 2-1. IP Overview

### 기능 요약

SG DMA는 **메모리에 작성된 descriptor 체인을 따라가며 메모리→메모리 전송을 연속 수행**하는 DMA 엔진이다.

일반 DMA는 전송 1건마다 CPU가 레지스터(소스·목적지·길이)를 쓰고 완료 인터럽트를 받아야 한다. SG는 그 정보를 **메모리상의 descriptor**에 미리 써두고, CPU는 **첫 descriptor 주소 하나만** 알려준다. 이후 IP가 체인을 따라가며 전부 처리하고 **마지막에 한 번만** 인터럽트를 올린다.

| | 일반 DMA | **SG DMA** |
|---|---|---|
| 전송 N건 설정 | 레지스터 쓰기 × N회 | descriptor N개를 메모리에 작성 |
| CPU 개입 | N회 | **1회** (`SG_ADDRESS` + `TRANSFER_SUBMIT`) |
| 인터럽트 | N회 | **1회** (마지막 descriptor만 `EOT_IRQ`) |

### 시스템 연결

![Fig.1 — 시스템 연결 (IP 외부 관점)](./figs/SOR-001.png)
<!-- <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1040 512" width="100%" role="img" aria-label="시스템 연결"><rect width="1040" height="512" fill="#ffffff"/><defs><marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0,1 L9,5 L0,9 z" fill="#1f2328"/></marker><marker id="ahg" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0,1 L9,5 L0,9 z" fill="#8c959f"/></marker><marker id="ahgr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0,1 L9,5 L0,9 z" fill="#1a7f37"/></marker><marker id="ahs" viewBox="0 0 10 10" refX="1" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M9,1 L0,5 L9,9 z" fill="#1f2328"/></marker></defs><text x="16" y="26" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="15.5" font-weight="700" fill="#1f2328" text-anchor="start">Fig.1 — 시스템 연결 (IP 외부 관점)</text><text x="16" y="45" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="400" fill="#6e7781" text-anchor="start">IP DV 환경에서 System Memory 는 ad_mem.v 기반 behavioral AXI slave 3 개로 대체한다.</text><rect x="26" y="76" width="190" height="86" rx="8" fill="#ffffff" stroke="#afb8c1" stroke-width="1"/><text x="121" y="108" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="14" font-weight="700" fill="#1f2328" text-anchor="middle">CPU / SW</text><text x="121" y="128" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="400" fill="#6e7781" text-anchor="middle">driver</text><text x="121" y="145" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="middle">레지스터 제어 · ISR</text><rect x="26" y="212" width="190" height="196" rx="8" fill="#ffffff" stroke="#afb8c1" stroke-width="1"/><text x="121" y="244" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="14" font-weight="700" fill="#1f2328" text-anchor="middle">System Memory</text><text x="121" y="264" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="400" fill="#6e7781" text-anchor="middle">AXI interconnect</text><rect x="44" y="282" width="154" height="34" rx="5" fill="#f6f8fa" stroke="#afb8c1" stroke-width="1"/><text x="121" y="303" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="600" fill="#6e7781" text-anchor="middle">descriptor 체인 (48 B × N)</text><rect x="44" y="324" width="154" height="34" rx="5" fill="#f6f8fa" stroke="#afb8c1" stroke-width="1"/><text x="121" y="345" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="600" fill="#6e7781" text-anchor="middle">source 데이터</text><rect x="44" y="366" width="154" height="34" rx="5" fill="#f6f8fa" stroke="#afb8c1" stroke-width="1"/><text x="121" y="387" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="600" fill="#6e7781" text-anchor="middle">destination 버퍼</text><rect x="690" y="70" width="330" height="350" rx="8" fill="#ffffff" stroke="#24292f" stroke-width="2"/><text x="855" y="100" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="16" font-weight="700" fill="#24292f" text-anchor="middle">sgdma_top</text><text x="855" y="118" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="middle">ADI axi_dmac 기반 SG DMA</text><rect x="706" y="132" width="298" height="272" rx="6" fill="#f6f8fa" stroke="#d0d7de" stroke-width="1"/><text x="718" y="152" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="700" fill="#1f2328" text-anchor="start">DMA_SG_TRANSFER</text><text x="992" y="152" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="700" fill="#1f2328" text-anchor="end">1</text><text x="718" y="170" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">DMA_TYPE_SRC / DEST</text><text x="992" y="170" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="end">0 / 0</text><text x="718" y="188" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">DMA_DATA_WIDTH</text><text x="992" y="188" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="end">64</text><text x="718" y="206" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="700" fill="#1f2328" text-anchor="start">DMA_AXI_ADDR_WIDTH</text><text x="992" y="206" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="700" fill="#1f2328" text-anchor="end">32</text><text x="718" y="224" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">DMA_LENGTH_WIDTH</text><text x="992" y="224" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="end">24</text><text x="718" y="242" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="700" fill="#1f2328" text-anchor="start">DMA_LENGTH_ALIGN</text><text x="992" y="242" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="700" fill="#1f2328" text-anchor="end">0  ◀</text><text x="718" y="260" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">MAX_BYTES_PER_BURST</text><text x="992" y="260" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="end">128</text><text x="718" y="278" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">FIFO_SIZE</text><text x="992" y="278" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="end">8</text><text x="718" y="296" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">AXI_ID_WIDTH</text><text x="992" y="296" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="end">1</text><text x="718" y="314" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="700" fill="#1f2328" text-anchor="start">AXI_AXCACHE</text><text x="992" y="314" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="700" fill="#1f2328" text-anchor="end">4'b0000</text><text x="718" y="332" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">AXI_AXPROT</text><text x="992" y="332" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="end">3'b000</text><text x="718" y="350" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">ASYNC_CLK_*</text><text x="992" y="350" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="end">0</text><text x="718" y="368" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">DMA_2D / CYCLIC / FRAMELOCK</text><text x="992" y="368" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="end">0</text><text x="718" y="386" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">AUTORUN / USE_EXT_SYNC</text><text x="992" y="386" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="end">0</text><path d="M216,104 L690,104" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><text x="453" y="96" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="middle">s_axi   AXI4-Lite   11 b addr / 32 b data</text><path d="M690,140 L216,140" fill="none" stroke="#1a7f37" stroke-width="1.4" marker-end="url(#ahgr)"/><text x="453" y="133" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#1a7f37" text-anchor="middle">irq   level · active-high</text><path d="M690,248 L216,248" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><text x="453" y="240" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="middle">m_sg_axi   AR / R   64 b data / 32 b addr</text><text x="453" y="263" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="middle">descriptor fetch · 48 B / 6 beat INCR</text><path d="M690,312 L216,312" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><text x="453" y="304" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="middle">m_src_axi   AR / R   64 b data / 32 b addr</text><text x="453" y="327" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="middle">source read · 128 B burst</text><path d="M690,376 L216,376" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><text x="453" y="368" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="middle">m_dest_axi   AW / W / B   64 b data / 32 b addr</text><text x="453" y="391" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="middle">destination write · 128 B burst</text><rect x="760" y="432" width="190" height="46" rx="23" fill="#fff8c5" stroke="#d4a72c" stroke-width="1"/><text x="855.0" y="452" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#7d4e00" text-anchor="middle">clk / resetn</text><text x="855.0" y="467" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="middle">단일 클록 · 동기 리셋</text><path d="M855,432 L855,422" fill="none" stroke="#d4a72c" stroke-width="1.4" marker-start="url(#ahs)"/><text x="16" y="496" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">◀  DMA_LENGTH_ALIGN = 0 은 SRC·DEST 가 둘 다 AXI-MM 일 때만 성립하며, ADI 공식 testbench 가 검증하지 않는 조합이다.  바이트 단위 길이 지정이 본 검증의 고유 가치가 집중된 지점이다.</text></svg> -->

세 마스터 포트는 모두 **데이터폭 64비트 / 주소폭 32비트**이며, **AXI ID · LOCK 신호를 노출**한다. 본 IP DV에서는 사용하지 않으나 SoC interconnect 연결 시 필수다.

### DUT 내부 구조

![Fig.2 - 검증 대상 DUT 내부 블록 다이어그램](./figs/SOR-002.png)
<!-- <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1040 810" width="100%" role="img" aria-label="DUT 내부 블록 다이어그램"><rect width="1040" height="810" fill="#ffffff"/><defs><marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0,1 L9,5 L0,9 z" fill="#1f2328"/></marker><marker id="ahg" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0,1 L9,5 L0,9 z" fill="#8c959f"/></marker><marker id="ahgr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0,1 L9,5 L0,9 z" fill="#1a7f37"/></marker><marker id="ahs" viewBox="0 0 10 10" refX="1" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M9,1 L0,5 L9,9 z" fill="#1f2328"/></marker></defs><text x="16" y="26" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="15.5" font-weight="700" fill="#1f2328" text-anchor="start">Fig.2 — 검증 대상 DUT 내부 블록 다이어그램</text><text x="16" y="45" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="400" fill="#6e7781" text-anchor="start">RTL top  sgdma_top  ⊃  i_axi_dmac : axi_dmac      AXI-MM only / SG(HWDESC) / no 2D / 단일 클록 / ADDR 32 b / AXCACHE 0b0000</text><rect x="200" y="60" width="700" height="660" rx="8" fill="#ffffff" stroke="#24292f" stroke-width="2"/><text x="888" y="710" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="700" fill="#24292f" text-anchor="end">sgdma_top   ·   DUT 경계   ·   rtl/sg_dma/sgdma_top.v</text><rect x="14" y="80" width="172" height="46" rx="23" fill="#ddf4ff" stroke="#54aeff" stroke-width="1"/><text x="100.0" y="100" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#0969da" text-anchor="middle">s_axi</text><text x="100.0" y="115" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="middle">AXI4-Lite · 11 b addr</text><rect x="14" y="152" width="172" height="46" rx="23" fill="#ddf4ff" stroke="#54aeff" stroke-width="1"/><text x="100.0" y="172" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#0969da" text-anchor="middle">irq</text><text x="100.0" y="187" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="middle">level · W1C 로 clear</text><rect x="14" y="224" width="172" height="46" rx="23" fill="#ddf4ff" stroke="#54aeff" stroke-width="1"/><text x="100.0" y="244" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#0969da" text-anchor="middle">m_sg_axi</text><text x="100.0" y="259" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="middle">descriptor fetch · AR/R</text><rect x="14" y="310" width="172" height="46" rx="23" fill="#fff8c5" stroke="#d4a72c" stroke-width="1"/><text x="100.0" y="330" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#7d4e00" text-anchor="middle">clk / resetn</text><text x="100.0" y="345" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="middle">단일 클록 · 동기 리셋</text><text x="16" y="374" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">wrapper 안에서 axi_dmac 의</text><text x="16" y="386" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">모든 clk · aresetn 포트로 분배</text><rect x="912" y="428" width="112" height="46" rx="23" fill="#ddf4ff" stroke="#54aeff" stroke-width="1"/><text x="968.0" y="448" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#0969da" text-anchor="middle">m_src_axi</text><text x="968.0" y="463" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="middle">AR / R</text><rect x="912" y="608" width="112" height="46" rx="23" fill="#ddf4ff" stroke="#54aeff" stroke-width="1"/><text x="968.0" y="628" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#0969da" text-anchor="middle">m_dest_axi</text><text x="968.0" y="643" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="middle">AW / W / B</text><rect x="222" y="80" width="350" height="76" rx="6" fill="#ffffff" stroke="#afb8c1" stroke-width="1"/><text x="236" y="103" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#1f2328" text-anchor="start">i_regmap</text><text x="236" y="119" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">axi_dmac_regmap  +  axi_dmac_regmap_request</text><text x="236" y="133" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">RW / RO / W1C · IRQ_MASK · IRQ_PENDING · SG_ADDRESS</text><rect x="522" y="89" width="40" height="19" rx="9.5" fill="#fff1e5" stroke="#e16f24" stroke-width="1"/><text x="542.0" y="102.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="700" fill="#9a4a00" text-anchor="middle">REG</text><rect x="596" y="80" width="286" height="66" rx="6" fill="#f6f8fa" stroke="#afb8c1" stroke-width="1" stroke-dasharray="4 3"/><text x="610" y="103" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#6e7781" text-anchor="start">i_reset_manager</text><text x="610" y="119" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">axi_dmac_reset_manager</text><text x="610" y="133" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">3-1 Reset / Clock → 해당사항 없음</text><rect x="838" y="89" width="34" height="19" rx="9.5" fill="#f6f8fa" stroke="#afb8c1" stroke-width="1"/><text x="855.0" y="102.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="700" fill="#6e7781" text-anchor="middle">—</text><rect x="222" y="186" width="350" height="76" rx="6" fill="#ffffff" stroke="#afb8c1" stroke-width="1"/><text x="236" y="209" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#1f2328" text-anchor="start">i_dmac_sg</text><text x="236" y="225" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">dmac_sg · descriptor fetch FSM (48 B / 6 beat)</text><text x="236" y="239" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">체인 추적 · prefetch · DMA_SG_TRANSFER = 1</text><rect x="514" y="195" width="48" height="19" rx="9.5" fill="#ddf4ff" stroke="#4493f8" stroke-width="1"/><text x="538.0" y="208.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="700" fill="#0a3069" text-anchor="middle">DESC</text><rect x="222" y="288" width="660" height="400" rx="6" fill="#f6f8fa" stroke="#d0d7de" stroke-width="1"/><text x="870" y="678" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="600" fill="#6e7781" text-anchor="end">i_transfer : axi_dmac_transfer</text><rect x="238" y="312" width="628" height="348" rx="6" fill="#ffffff" stroke="#d0d7de" stroke-width="1"/><text x="854" y="650" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="600" fill="#6e7781" text-anchor="end">i_request_arb : dmac_request_arb</text><rect x="256" y="332" width="268" height="62" rx="6" fill="#ffffff" stroke="#afb8c1" stroke-width="1"/><text x="270" y="355" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#1f2328" text-anchor="start">i_req_gen</text><text x="270" y="371" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">request_generator · inc_id() Gray 증가</text><rect x="466" y="341" width="48" height="19" rx="9.5" fill="#ddf4ff" stroke="#4493f8" stroke-width="1"/><text x="490.0" y="354.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="700" fill="#0a3069" text-anchor="middle">FUNC</text><rect x="256" y="420" width="268" height="62" rx="6" fill="#ffffff" stroke="#afb8c1" stroke-width="1"/><text x="270" y="443" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#1f2328" text-anchor="start">i_src_dma_mm</text><text x="270" y="459" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">src_axi_mm + addr_gen / req_splitter · 128 B</text><rect x="474" y="429" width="40" height="19" rx="9.5" fill="#fff1e5" stroke="#e16f24" stroke-width="1"/><text x="494.0" y="442.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="700" fill="#9a4a00" text-anchor="middle">AXI</text><rect x="256" y="508" width="268" height="68" rx="6" fill="#ffffff" stroke="#afb8c1" stroke-width="1"/><text x="270" y="531" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#1f2328" text-anchor="start">i_store_and_forward</text><text x="270" y="547" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">axi_dmac_burst_memory · FIFO_SIZE 8 (1 KiB)</text><text x="270" y="561" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">0-replication 패치 지점</text><rect x="466" y="517" width="48" height="19" rx="9.5" fill="#ddf4ff" stroke="#4493f8" stroke-width="1"/><text x="490.0" y="530.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="700" fill="#0a3069" text-anchor="middle">FUNC</text><rect x="256" y="600" width="268" height="62" rx="6" fill="#ffffff" stroke="#afb8c1" stroke-width="1"/><text x="270" y="623" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#1f2328" text-anchor="start">i_dest_dma_mm</text><text x="270" y="639" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">dest_axi_mm + addr_gen / response_handler</text><rect x="474" y="609" width="40" height="19" rx="9.5" fill="#fff1e5" stroke="#e16f24" stroke-width="1"/><text x="494.0" y="622.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="700" fill="#9a4a00" text-anchor="middle">AXI</text><rect x="580" y="332" width="268" height="62" rx="6" fill="#ffffff" stroke="#afb8c1" stroke-width="1"/><text x="594" y="355" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#1f2328" text-anchor="start">throttler</text><text x="594" y="371" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">compare_id() · in-flight 한도 2**(ID_W−1) = 8</text><rect x="790" y="341" width="48" height="19" rx="9.5" fill="#ddf4ff" stroke="#4493f8" stroke-width="1"/><text x="814.0" y="354.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="700" fill="#0a3069" text-anchor="middle">FUNC</text><rect x="580" y="508" width="268" height="68" rx="6" fill="#ffffff" stroke="#afb8c1" stroke-width="1"/><text x="594" y="531" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#1f2328" text-anchor="start">i_response_manager</text><text x="594" y="547" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">axi_dmac_response_manager</text><text x="594" y="561" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">EOT 집계 → TRANSFER_DONE · DESCRIPTOR_ID</text><rect x="798" y="517" width="40" height="19" rx="9.5" fill="#fff1e5" stroke="#e16f24" stroke-width="1"/><text x="818.0" y="530.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="700" fill="#9a4a00" text-anchor="middle">IRQ</text><path d="M186,103 L222,103" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><path d="M572,100 L596,100" fill="none" stroke="#8c959f" stroke-width="1.4" stroke-dasharray="5 4" marker-end="url(#ahg)"/><text x="584" y="74" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="8.5" font-weight="400" fill="#6e7781" text-anchor="middle">CONTROL.ENABLE</text><path d="M222,131 L210,131 L210,175 L186,175" fill="none" stroke="#1a7f37" stroke-width="1.4" marker-end="url(#ahgr)"/><path d="M222,224 L210,224 L210,247 L186,247" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><path d="M186,333 L214,333" fill="none" stroke="#d4a72c" stroke-width="1.4" marker-end="url(#ah)"/><path d="M524,451 L912,451" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><path d="M524,631 L912,631" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><path d="M300,156 L300,186" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><text x="308" y="177" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">SG_ADDRESS / CONTROL.HWDESC</text><path d="M300,262 L300,332" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><text x="308" y="282" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">transfer request</text><path d="M524,352 L580,352" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><text x="552" y="371" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="middle">request_id</text><path d="M700,394 L700,406 L420,406 L420,420" fill="none" stroke="#8c959f" stroke-width="1.4" stroke-dasharray="5 4" marker-end="url(#ahg)"/><text x="428" y="402" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="start">throttle (back-pressure)</text><path d="M300,394 L300,420" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><text x="308" y="412" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="start">request_id</text><path d="M300,482 L300,508" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><text x="308" y="500" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="start">read data</text><path d="M300,576 L300,600" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><text x="308" y="593" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="start">write data</text><path d="M524,612 L552,612 L552,556 L580,556" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><text x="556" y="596" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="start">B response</text><path d="M840,146 L840,288" fill="none" stroke="#8c959f" stroke-width="1.4" stroke-dasharray="5 4" marker-end="url(#ahg)"/><text x="760" y="252" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="end">reset / enable 시퀀싱</text><path d="M848,540 L876,540 L876,174 L578,174 L578,118 L572,118" fill="none" stroke="#1a7f37" stroke-width="1.4" marker-end="url(#ahgr)"/><text x="727" y="168" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#1a7f37" text-anchor="middle">EOT → IRQ_PENDING → irq</text><rect x="16" y="720" width="1008" height="58" rx="6" fill="#f6f8fa" stroke="#d0d7de" stroke-width="1"/><rect x="260" y="725" width="40" height="19" rx="9.5" fill="#fff1e5" stroke="#e16f24" stroke-width="1"/><text x="280.0" y="738.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="700" fill="#9a4a00" text-anchor="middle">REG</text><text x="310" y="738" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">Priority A — 기본 연결성 · 레지스터 · AXI 프로토콜 · 인터럽트</text><rect x="252" y="747" width="48" height="19" rx="9.5" fill="#ddf4ff" stroke="#4493f8" stroke-width="1"/><text x="276.0" y="760.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="700" fill="#0a3069" text-anchor="middle">DESC</text><text x="310" y="760" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">Priority B — SG 핵심 기능 (descriptor · 체인 · 전송)</text><path d="M700,731 L756,731" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><text x="764" y="734" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">데이터 경로</text><path d="M700,754 L756,754" fill="none" stroke="#8c959f" stroke-width="1.4" stroke-dasharray="5 4" marker-end="url(#ahg)"/><text x="764" y="757" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">제어 · 피드백</text><path d="M880,731 L936,731" fill="none" stroke="#1a7f37" stroke-width="1.4" marker-end="url(#ahgr)"/><text x="944" y="734" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">응답 · 인터럽트</text><text x="880" y="757" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">Priority C · D 는 전 구간</text><text x="16" y="798" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">굵은 테두리 = sgdma_top (DUT 경계).  axi_dmac 파라미터 38 개를 전부 명시하고, 모든 clock / reset 포트를 clk · resetn 한 쌍에 연결한다.  사용 채널만 top 에 노출하고 나머지 포트는 wrapper 안에서 tie-off 한다.</text></svg> -->

**신호 흐름 요약**

| # | 경로 | 내용 |
|:--:|---|---|
| ① | `s_axi` → `i_regmap` | SW가 `CONTROL` · `SG_ADDRESS` · `TRANSFER_SUBMIT` 설정 |
| ② | `i_regmap` → `i_dmac_sg` | 첫 descriptor 주소 및 HWDESC 모드 전달 |
| ③ | `i_dmac_sg` ↔ `m_sg_axi` | descriptor 48 B fetch (6 beat INCR), `flags[0]=0`이면 `next_sg_addr`로 체인 이동 |
| ④ | `i_dmac_sg` → `i_req_gen` | descriptor에서 추출한 `src_addr` · `dest_addr` · `x_len` · `flags` |
| ⑤ | `i_src_dma_mm` → `i_store_and_forward` → `i_dest_dma_mm` | store-and-forward 데이터 경로, 128 B 단위 버스트 |
| ⑥ | `i_response_manager` → `i_regmap` | 완료 집계 → `TRANSFER_DONE` · `DESCRIPTOR_ID` · `irq` |

**③ ~ ⑥이 겹쳐서 동작한다.** descriptor fetch는 데이터 전송과 중첩(prefetch)되며, 3-descriptor 체인의 descriptor 3개가 **첫 데이터 전송 완료 전에 모두 fetch**되는 것이 관측되었다.

**모듈 계층**

| 계층 | 모듈 | 역할 | 요구사항 영역 |
|:--:|---|---|:--:|
| 0 | `sgdma_top` | 래퍼 — 파라미터 38개 고정, AXI 포트 노출 | — |
| 1 | `axi_dmac` | IP 본체 | — |
| 2 | `axi_dmac_regmap` (+ `_request`) | AXI4-Lite 레지스터 파일 | **REG** |
| 2 | `axi_dmac_transfer` | 전송 경로 | — |
| 3 | `dmac_request_arb` | 요청 생성 · 중재 | FUNC |
| 4 | **`dmac_sg`** | **SG 전용 — descriptor fetch / 체인 추적** | **DESC** |
| 4 | `dmac_src_axi_mm` / `dmac_dest_axi_mm` | 소스 read / 목적지 write 발행 | **AXI** |
| 4 | `axi_dmac_burst_memory` | store-and-forward FIFO — **0-replication 패치 지점** | FUNC |
| 4 | `axi_dmac_response_manager` | 완료 집계 | **IRQ** |
| 3 | `axi_dmac_reset_manager` | 리셋 시퀀싱 | — ([3-1](#3-1-reset--clock) 범위 밖) |

**`dmac_sg`가 `DMA_SG_TRANSFER = 1`일 때만 생성되는 유일한 블록**이며, `m_sg_axi` 포트와 함께 본 검증의 중심이다.

### 구성 파라미터 (확정)

| 파라미터 | 값 | 비고 |
|---|:--:|---|
| `DMA_SG_TRANSFER` | **1** | **검증 대상 기능** |
| `DMA_TYPE_SRC` / `DMA_TYPE_DEST` | 0 / 0 | AXI-MM → AXI-MM |
| `DMA_DATA_WIDTH_SRC` / `DEST` / `SG` | 64 | SG 인터페이스는 64 고정 |
| `DMA_AXI_ADDR_WIDTH` | **32** | 2026-10-02 결정 |
| `DMA_LENGTH_WIDTH` | 24 | 최대 16 MiB / descriptor |
| `MAX_BYTES_PER_BURST` | 128 | |
| `FIFO_SIZE` | 8 | = 1 KiB 버퍼, `ID_WIDTH` = 4 |
| `AXI_ID_WIDTH` | 1 | |
| **`AXI_AXCACHE`** | **`4'b0000`** | **2026-10-06 결정** — Device Non-bufferable |
| `AXI_AXPROT` | `3'b000` | 2026-10-06 명시 |
| `ASYNC_CLK_*` (6개) | 0 | 단일 클럭 |
| `DMA_2D_TRANSFER` / `CYCLIC` / `FRAMELOCK` | 0 | |
| `AUTORUN` / `USE_EXT_SYNC` | 0 | |
| `DISABLE_DEBUG_REGISTERS` | 0 | 디버그 레지스터 활성 |

**파생 localparam 중 검증에 중요한 것**

| localparam | 값 | 의미 |
|---|:--:|---|
| **`DMA_LENGTH_ALIGN`** | **0** | **MM→MM에서만 0** — 길이 정렬 제약 없음 |
| `BYTES_PER_BEAT_WIDTH_*` | 3 | 주소 하위 3비트 무시 (8B 정렬) |
| `HAS_ADDR_HIGH` | 0 | `*_ADDRESS_HIGH` 레지스터 비활성 |
| `ID_WIDTH` | 4 | 내부 Gray ID 폭 |

> **`DMA_LENGTH_ALIGN = 0`이 본 구성의 고유 특성이다.** SRC와 DEST가 **둘 다 AXI-MM**일
> 때만 0이 되며, **ADI 공식 testbench는 이 조합을 검증하지 않는다**(cfg1·cfg2 모두 한쪽이
> AXI-Stream). 바이트 단위 길이 지정([FUNC-005](#3-8-2-func--전송-기능))과
> `burst_memory.v` 0-replication 패치가 모두 여기에서 나온다. **본 검증의 고유 가치가
> 집중된 지점이다.**

### SG 전송 흐름

![Fig.3 -  SG 전송 실행 흐름](./figs/SOR-003.png)
<!-- <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1040 772" width="100%" role="img" aria-label="SG 전송 실행 흐름"><rect width="1040" height="772" fill="#ffffff"/><defs><marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0,1 L9,5 L0,9 z" fill="#1f2328"/></marker><marker id="ahg" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0,1 L9,5 L0,9 z" fill="#8c959f"/></marker><marker id="ahgr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0,1 L9,5 L0,9 z" fill="#1a7f37"/></marker><marker id="ahs" viewBox="0 0 10 10" refX="1" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M9,1 L0,5 L9,9 z" fill="#1f2328"/></marker></defs><text x="16" y="26" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="15.5" font-weight="700" fill="#1f2328" text-anchor="start">Fig.3 — SG 전송 실행 흐름</text><text x="16" y="45" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="400" fill="#6e7781" text-anchor="start">CONTROL 쓰기(③)보다 TRANSFER_SUBMIT(⑤)이 먼저 나가면 아무 일도 일어나지 않고 에러도 나지 않는다 — 순서를 바꿀 수 없다.</text><rect x="45" y="70" width="210" height="44" rx="8" fill="#ddf4ff" stroke="#54aeff" stroke-width="1"/><text x="150" y="91" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#0969da" text-anchor="middle">SW / Driver</text><text x="150" y="106" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="middle">레지스터 제어</text><line x1="150" y1="114" x2="150" y2="718" stroke="#d0d7de" stroke-width="1.5" stroke-dasharray="4 4"/><rect x="415" y="70" width="210" height="44" rx="8" fill="#ddf4ff" stroke="#54aeff" stroke-width="1"/><text x="520" y="91" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#0969da" text-anchor="middle">sgdma_top</text><text x="520" y="106" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="middle">DUT</text><line x1="520" y1="114" x2="520" y2="718" stroke="#d0d7de" stroke-width="1.5" stroke-dasharray="4 4"/><rect x="785" y="70" width="210" height="44" rx="8" fill="#ddf4ff" stroke="#54aeff" stroke-width="1"/><text x="890" y="91" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#0969da" text-anchor="middle">System Memory</text><text x="890" y="106" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="middle">descriptor · data</text><line x1="890" y1="114" x2="890" y2="718" stroke="#d0d7de" stroke-width="1.5" stroke-dasharray="4 4"/><path d="M150,172 L890,172" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><rect x="507.0" y="148" width="26" height="17" rx="8.5" fill="#fff1e5" stroke="#e16f24" stroke-width="1"/><text x="520.0" y="160.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="700" fill="#9a4a00" text-anchor="middle">1</text><text x="520.0" y="142" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="10" font-weight="600" fill="#1f2328" text-anchor="middle">descriptor 체인 작성</text><text x="520.0" y="186" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="middle">마지막만 flags = 0x3 (LAST | EOT_IRQ)</text><path d="M150,242 L520,242" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><rect x="322.0" y="218" width="26" height="17" rx="8.5" fill="#fff1e5" stroke="#e16f24" stroke-width="1"/><text x="335.0" y="230.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="700" fill="#9a4a00" text-anchor="middle">2</text><text x="335.0" y="212" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="10" font-weight="600" fill="#1f2328" text-anchor="middle">W  IRQ_MASK(0x080) = 0x1</text><text x="335.0" y="256" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="middle">SOT 마스크 · EOT 허용</text><path d="M150,308 L520,308" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><rect x="322.0" y="284" width="26" height="17" rx="8.5" fill="#fff1e5" stroke="#e16f24" stroke-width="1"/><text x="335.0" y="296.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="700" fill="#9a4a00" text-anchor="middle">3</text><text x="335.0" y="278" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="10" font-weight="600" fill="#1f2328" text-anchor="middle">W  CONTROL(0x400) = 0x5</text><text x="335.0" y="322" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="middle">ENABLE | HWDESC</text><path d="M150,368 L520,368" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><rect x="322.0" y="344" width="26" height="17" rx="8.5" fill="#fff1e5" stroke="#e16f24" stroke-width="1"/><text x="335.0" y="356.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="700" fill="#9a4a00" text-anchor="middle">4</text><text x="335.0" y="338" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="10" font-weight="600" fill="#1f2328" text-anchor="middle">W  SG_ADDRESS(0x47C) = 첫 descriptor 주소</text><path d="M150,424 L520,424" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><rect x="322.0" y="400" width="26" height="17" rx="8.5" fill="#fff1e5" stroke="#e16f24" stroke-width="1"/><text x="335.0" y="412.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="700" fill="#9a4a00" text-anchor="middle">5</text><text x="335.0" y="394" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="10" font-weight="600" fill="#1f2328" text-anchor="middle">W  TRANSFER_SUBMIT(0x408) = 0x1</text><rect x="400" y="452" width="560" height="150" rx="6" fill="#f6f8fa" stroke="#d0d7de" stroke-width="1" stroke-dasharray="5 4"/><text x="412" y="472" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="700" fill="#0a3069" text-anchor="start">체인 반복  ·  flags[0] = 0 이면 next_sg_addr 로 이동</text><path d="M520,524 L890,524" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><rect x="692.0" y="500" width="26" height="17" rx="8.5" fill="#fff1e5" stroke="#e16f24" stroke-width="1"/><text x="705.0" y="512.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="700" fill="#9a4a00" text-anchor="middle">6</text><text x="705.0" y="494" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="10" font-weight="600" fill="#1f2328" text-anchor="middle">m_sg_axi  descriptor fetch</text><text x="705.0" y="538" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="middle">48 B = 6 beat INCR · prefetch</text><path d="M520,584 L890,584" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><rect x="692.0" y="560" width="26" height="17" rx="8.5" fill="#fff1e5" stroke="#e16f24" stroke-width="1"/><text x="705.0" y="572.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="700" fill="#9a4a00" text-anchor="middle">7</text><text x="705.0" y="554" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="10" font-weight="600" fill="#1f2328" text-anchor="middle">m_src_axi read  →  m_dest_axi write</text><text x="705.0" y="598" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="middle">128 B 단위 분할</text><path d="M520,648 L150,648" fill="none" stroke="#1a7f37" stroke-width="1.4" marker-end="url(#ahgr)"/><rect x="322.0" y="624" width="26" height="17" rx="8.5" fill="#fff1e5" stroke="#e16f24" stroke-width="1"/><text x="335.0" y="636.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="700" fill="#9a4a00" text-anchor="middle">8</text><text x="335.0" y="618" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="10" font-weight="600" fill="#1f2328" text-anchor="middle">irq  (EOT)</text><text x="335.0" y="662" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="middle">flags[1] = 1 인 descriptor 완료 시</text><path d="M150,712 L520,712" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><rect x="322.0" y="688" width="26" height="17" rx="8.5" fill="#fff1e5" stroke="#e16f24" stroke-width="1"/><text x="335.0" y="700.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="700" fill="#9a4a00" text-anchor="middle">9</text><text x="335.0" y="682" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="10" font-weight="600" fill="#1f2328" text-anchor="middle">R 0x084  →  W 0x084 (W1C)  →  R 0x428</text><text x="335.0" y="726" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="middle">IRQ_PENDING clear 후 TRANSFER_DONE 확인</text><text x="16" y="758" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">⑨ 에서 clear(W1C) 를 상태 확인(TRANSFER_DONE) 보다 먼저 한다.  반대로 하면 그 사이에 들어온 이벤트를 함께 지워버릴 수 있다.  IRQ_PENDING 에 쓰면 실제로 지워지는 것은 IRQ_SOURCE 이다.</text></svg> -->

### Descriptor 포맷 (48 byte)

| Offset | 크기 | 필드 | 본 구성 처리 |
|---|:--:|---|---|
| `+0x00` | 32 | `flags` — `[0]` LAST, `[1]` EOT_IRQ | 사용 |
| `+0x04` | 32 | `id` | 사용 → `DESCRIPTOR_ID` |
| `+0x08` | 64 | `dest_addr` (하위 3비트 무시) | 사용 |
| `+0x10` | 64 | `src_addr` (하위 3비트 무시) | 사용 |
| `+0x18` | 64 | `next_sg_addr` | `flags[0]=0`일 때 |
| `+0x20` | 32 | `y_len` | **무시** (2D 비활성) — 0 권장 |
| `+0x24` | 32 | `x_len` — **전송 바이트 − 1** | 사용 (`[23:0]`만 유효) |
| `+0x28` | 32 | `src_stride` | **무시** — 0 권장 |
| `+0x2C` | 32 | `dst_stride` | **무시** — 0 권장 |

- **정렬**: 8바이트 필수, **64바이트 권장**(한 burst가 4 KiB 경계를 넘지 않도록)
- **버스트 속성**: `ARLEN=5`, `ARSIZE=3`, `ARBURST=INCR` 고정

---

## 2-2. SFR Map

**비트 필드·동작 상세는 [SGDMA-SFR-rel-v1.0.0.md](SGDMA-SFR-rel-v1.0.0.md) 를 참조한다.** 본 절은 검증 범위 식별을 위한 요약이다.

### 접근 사양

| 항목 | 값 |
|---|---|
| 버스 | AXI4-Lite, 32bit 데이터 |
| 주소 공간 | `0x000` ~ `0x7FF` (2 KB, 11bit) |
| 주소 환산 | **바이트 주소 = RTL 워드 주소 × 4** |
| `WSTRB` | **무시** — 모든 쓰기는 32bit 전체 쓰기 |
| `BRESP` / `RRESP` | **항상 OKAY** — 미정의 주소도 에러 없음 |
| 미매핑 주소 읽기 | `0x0000_0000` |

### 레지스터 요약

**근거 등급** — **M** = Sanity Test 46 checks로 실측 확인 · **R** = RTL 분석만 (미측정).
상세는 SFR 문서 §2.5를 참조한다. **이 열은 값의 신뢰도이지 요구사항 검증 상태가 아니다.**

| Offset | 이름 | 접근 | 리셋값 | 근거 | 본 구성 |
|---|---|:--:|---|:--:|---|
| `0x000` | `VERSION` | RO | `0x0004_0565` | **M** | Const |
| `0x004` | `PERIPHERAL_ID` | RO | `0x0000_0000` | **M** | Const |
| `0x008` | `SCRATCH` | RW | `0x0000_0000` | **M** | Active |
| `0x00C` | `IDENTIFICATION` | RO | `0x444D_4143` | **M** | Const |
| `0x010` | `INTERFACE_DESCRIPTION_1` | RO | `0x3807_0303` | **M** | Const |
| `0x014` | `INTERFACE_DESCRIPTION_2` | RO | **`0x0000_0000`** | **M** | Const |
| `0x080` | `IRQ_MASK` | RW | **`0x0000_0003`** | **M** | Active |
| `0x084` | `IRQ_PENDING` | RW1C | `0x0000_0000` | **M** | Active |
| `0x088` | `IRQ_SOURCE` | RO | `0x0000_0000` | **M** | Active |
| `0x400` | `CONTROL` | RW | `0x0000_0000` | **M** | Active |
| `0x404` | `TRANSFER_ID` | RO | `0x0000_0000` | **M** | Active |
| `0x408` | `TRANSFER_SUBMIT` | RW1S-SC | `0x0000_0000` | R | Active |
| `0x40C` | `FLAGS` | RW | **`0x0000_0002`** | **M** | Active |
| `0x410` | `DEST_ADDRESS` | RW | `0x0000_0000` | **M** | HWDESC=0 전용 |
| `0x414` | `SRC_ADDRESS` | RW | `0x0000_0000` | **M** | HWDESC=0 전용 |
| `0x418` | `X_LENGTH` | RW | `0x0000_0000` | R | HWDESC=0 전용 |
| `0x41C` | `Y_LENGTH` | — | `0x0000_0000` | **M** | Inactive |
| `0x420` / `0x424` | `DEST/SRC_STRIDE` | — | `0x0000_0000` | R | Inactive |
| `0x428` | `TRANSFER_DONE` | RO | `0x0000_0000` | **M** | Active |
| `0x42C` | `ACTIVE_TRANSFER_ID` | RO | `0x0000_0000` | R | Active |
| `0x430` | `STATUS` | RO | `0x0000_0000` | R | 예약 (항상 0) |
| `0x434` / `0x438` | `CURRENT_DEST/SRC_ADDRESS` | RO | 가변 | R | Debug |
| `0x43C` | `DBG_STATUS` | RO | 가변 | R | Debug |
| `0x440` / `0x444` | `DBG_IDS0/1` | RO | `0x0000_0000` | R | Debug (Gray) |
| `0x448` | `TRANSFER_PROGRESS` | RO | `0x0000_0000` | R | Active |
| `0x44C` | `PARTIAL_TRANSFER_LENGTH` | RO | `0x0000_0000` | R | **Unreachable** |
| `0x450` | `PARTIAL_TRANSFER_ID` | **RO-RS** | `0x0000_0000` | R | **Unreachable** |
| `0x454` | `DESCRIPTOR_ID` | RO | `0x0000_0000` | **M** | **SG 전용** |
| `0x458` / `0x45C` | `FRAMELOCK_*` | — | `0x0000_0000` | **M** | Inactive |
| `0x47C` | `SG_ADDRESS` | RW | `0x0000_0000` | **M** | **SG 전용** |
| `0x490` / `0x494` / `0x4BC` | 주소 `*_HIGH` | — | `0x0000_0000` | **M** | **Inactive** (ADDR_WIDTH=32) |
| `0x498` / `0x49C` | 디버그 `*_HIGH` | RO | `0x0000_0000` | R | Inactive |

### 검증 관점 특이사항

레지스터 맵에서 **일반적인 가정이 깨지는 지점**이다. 시나리오 작성 시 반드시 반영해야 한다.

| # | 특이사항 | 영향 |
|:--:|---|---|
| **1** | **`FLAGS`(0x40C) 리셋값이 `0x2`** (`LAST` 기본 1) | "리셋 후 전 레지스터 0" 가정 테스트가 **정상 동작을 FAIL로 판정** |
| **2** | **`IRQ_MASK` 리셋값이 `0x3`** (둘 다 마스크) | 리셋 직후 인터럽트가 올라오지 않음. **명시적 unmask 필요** |
| **3** | **파라미터로 죽은 비트가 존재** — `CONTROL[3]`, `FLAGS[0]`, 주소 `[2:0]`, HIGH 레지스터군 | write/read-back 테스트가 **정상 마스킹을 버그로 오판** |
| **4** | **`0x450` 읽기에 부작용** — FIFO pop | "전 레지스터 덤프" 테스트가 **내부 상태를 파괴** |
| **5** | **W1C 대상이 이름과 다름** — `IRQ_PENDING`에 쓰지만 `IRQ_SOURCE`가 지워짐 | 클리어 동작 검증 시 두 레지스터를 **구분해서** 확인해야 함 |
| **6** | **에러 응답이 없음** — 미정의 주소도 OKAY | 주소 디코드 오류는 **readback 비교로만** 검출 가능 |
| **7** | **`TRANSFER_SUBMIT`은 self-clearing** | 쓰기 전 **0인지 폴링** 필요. 1인 상태의 재쓰기는 조용히 무시됨 |

---

## 2-3. Sanity Test

본 IP에는 **회귀 게이트** 역할의 Sanity Test가 구현되어 있다. 상세는 아래 문서를 참조한다.

**→ [`SGDMA-SANITY-rel-v1.0.0`](SGDMA-SANITY-rel-v1.0.0)**

| 항목 | 값 |
|---|---|
| 문서 ID | SGDMA-SANITY-v1.0 |
| 구현 | `tb/sg_dma/tb_sg_dma.sv` |
| 구성 | **TC 7건 / 체크 46건** |
| 최종 실행 | 2026-10-06 — 46/46 PASS (시뮬레이션 시간 6,305 ns) |
| 역할 | **RTL 수정 시마다 "완전히 깨졌는가"를 수 초 안에 판별** |

| TC | 이름 | 체크 |
|---|---|:--:|
| `SAN-001` | Register identity | 5 |
| `SAN-002` | Scratch R/W | 3 |
| `SAN-003` | Reset defaults | 10 |
| `SAN-007` | Parameter-masked bits | 11 |
| `SAN-004` | Single descriptor copy | 4 |
| `SAN-005` | 3-descriptor chain, gather | 6 |
| `SAN-006` | IRQ & status | 7 |

> **본 SOR의 요구사항은 Sanity 결과와 무관하게 전부 ⬜(미검증)이다.** Sanity는 회귀
> 게이트이지 요구사항 검증 근거가 아니며, **검증팀이 자체 환경에서 독립적으로 재검증**한다.
> 본 문서의 시나리오에 `SAN-xxx`가 나타나는 것은 **동일한 확인을 이미 한 번 해 보았다는
> 참고 정보**이며, 그 TC를 그대로 쓰라는 뜻이 아니다.

> **Sanity가 보지 않는 것.** `SAN-003`은 리셋값을 확인하지만 SFR 문서 부록 A의 약 30개 중
> **10개만** 본다. 나머지와, `ENABLE`/`PAUSE` 시퀀스 · 전송 중 관측 · scatter · 길이/정렬
> sweep · 4 KiB 경계 · 에러 주입은 **Sanity 범위 밖**이다. 전체 목록은 Sanity 문서 §5.2에
> 있다.

---

# 3. Verification Requirements

## 요구사항 표기 규칙

### ID 체계

```
SGDMA-<CAT>-<NNN>
```

| CAT | 영역 | 수록 절 | 개수 |
|---|---|---|:--:|
| `RST` | 리셋 · 클럭 | 3-1 | **0** — Sanity Test로 대체 |
| `REG` | 레지스터 접근 | 3-3 | 24 |
| `IRQ` | 인터럽트 | 3-4 | 6 |
| `AXI` | AXI 프로토콜 | 3-7 | 7 |
| `DESC` | Descriptor 처리 | 3-8-1 | 9 |
| `FUNC` | 전송 기능 | 3-8-2 | 10 |
| `ERR` | 에러 · 예외 | 3-8-3 | 4 |
| `COV` | 커버리지 | 3-9 | 1 |
| | **합계** | | **61** |

### 필드 정의

| 필드 | 값 | 의미 |
|---|---|---|
| **SG** | `◆` / `◇` / `○` | SG 집중도 (아래) |
| **P** | `H` / `M` / `L` | H: 미검증 시 signoff 불가 · M: 필수지만 후순위 · L: 여유 시 |
| **출처** | `SPEC` / `RTL` / `MEAS` | SPEC: HDL 문서 · RTL: 코드 분석 · **MEAS: 실측 확정** |
| **방법** | `DIR` / `RND` / `ASRT` / `COV` | directed · random · assertion · coverage |
| **상태** | ⬜ | 검증 상태 — 본 개정에서는 **전 항목 미검증** |

### SG 집중도

팀 목표가 SG 검증이므로, 각 요구사항이 **SG에 얼마나 고유한지**를 세 등급으로 분류한다. 검증 자원 배분과 리뷰 우선순위 판단에 사용한다.

| 등급 | 정의 | 개수 |
|---|---|:--:|
| **◆ SG 고유** | SG가 없으면 존재하지 않는 요구사항. **본 검증의 핵심** | **18** |
| **◇ SG 상호작용** | 일반 DMA 기능이나 **SG 모드에서 동작이 달라져** 별도 확인 필요 | **8** |
| **○ 일반** | SG와 무관하나 검증 신뢰성을 위해 필요 (인프라 · 프로토콜) | **35** |

**리뷰 시에는 ◆와 ◇ 26개를 우선 확인할 것을 권한다.** 그중 4건은 3-8이 아니라
3-3(`REG-007`·`REG-015`·`REG-016`)과 3-7(`AXI-001`)에 있다.

### 검증 시나리오 Priority

| Priority | 명칭 | 목적 | 실행 시점 |
|:--:|---|---|---|
| **A** | **Sanity** | **기본 연결성 · 레지스터 · 회귀 게이트** | **RTL 수정 시마다** |
| **B** | Feature | SG 핵심 기능 — directed 검증 | 기능 추가 시 |
| C | Corner | 경계 조건 | signoff 전 |
| D | Error | 에러 · 예외 주입 | signoff 전 |
| E | Random | 랜덤 조합 | 여유 시 |

**Priority A에 해당하는 항목은 [2-3](#2-3-sanity-test)의 Sanity Test가 동일한 확인을 이미 수행했다.** 다만 본 문서의 상태는 전부 ⬜이며, 검증팀이 자체 환경에서 재검증한다.

### 공통 판정 항목

모든 시나리오는 아래를 기본 검사한다. 각 시나리오에서는 **추가 판정만** 기술한다.

| # | 항목 |
|:--:|---|
| C1 | timeout 미발생 (기본 50,000 cycle) |
| C2 | 목적지 데이터가 소스와 바이트 단위 일치 |
| C3 | 목적지 끝 이후 16 B가 미기록 (overrun 없음) |
| C4 | `IRQ_PENDING[1]`(TRANSFER_COMPLETED) set |
| C5 | AXI assertion 위반 0건 |
| C6 | `$error` 호출 0건 |

### 공통 메모리 맵

모든 시나리오가 공유하는 주소 배치다. 영역을 고정해 두면 **파형에서 주소만 보고도** 무엇에 대한 접근인지 판별할 수 있다.

| 영역 | 주소 범위 | 용도 |
|---|---|---|
| **DESC** | `0x0000_1000` ~ `0x0000_1FFF` | descriptor 체인 |
| **SRC** | `0x0001_0000` ~ `0x0001_FFFF` | 소스 데이터 |
| **DST** | `0x0002_0000` ~ `0x0002_FFFF` | 목적지 데이터 |
| **BOUND** | `0x0000_0F00` ~ `0x0000_10FF` | 4 KB 경계 테스트 전용 |
| **ERR** | `0x0003_0000` ~ `0x0003_FFFF` | 에러 응답 주입 영역 |
| **LONG** | `0x0004_0000` ~ `0x0004_FFFF` | 긴 체인용 descriptor |

---

## 3-1. Reset / Clock

**Sanity Test에서 커버됨. 해당 사항 없음.**

→ [2-3. Sanity Test](#2-3-sanity-test)

---

## 3-2. Connectivity

**IP DV level에서는 해당 사항 없음. SoC DV에서 필요.**

---

## 3-3. Register Access

### 범위

AXI4-Lite 레지스터 인터페이스의 **읽기 · 쓰기 정확성**과 **접근 유형별 동작**을 다룬다. 레지스터 제어가 틀리면 SG 기능 자체를 구동할 수 없으므로 **우선순위가 높다.**

### 요구사항

#### 식별 · 구성 정보

| ID | 요구사항 | SG | P | 출처 | 방법 | 상태 |
|---|---|:--:|:--:|:--:|:--:|:--:|
| REG-001 | `VERSION`(0x000) 읽기 시 `0x0004_0565` 반환 | ○ | H | MEAS | DIR | ⬜ |
| REG-002 | `PERIPHERAL_ID`(0x004) 읽기 시 합성 파라미터 `ID` 값 반환 | ○ | M | MEAS | DIR | ⬜ |
| REG-003 | `SCRATCH`(0x008)는 임의 32bit 값 write 후 동일 값 read | ○ | M | MEAS | DIR | ⬜ |
| REG-004 | `IDENTIFICATION`(0x00C) 읽기 시 `0x444D_4143`("DMAC") 반환 | ○ | H | MEAS | DIR | ⬜ |
| REG-005 | `INTERFACE_DESCRIPTION_1`(0x010)이 합성 파라미터를 정확히 반영 (`0x3807_0303`) | ○ | M | MEAS | DIR | ⬜ |
| REG-020 | `INTERFACE_DESCRIPTION_2`(0x014)가 `AXCACHE`/`AXPROT`/`CACHE_COHERENT`를 반영 (`0x0000_0000`) | ○ | M | MEAS | DIR | ⬜ |

#### 제어 · 전송 설정

| ID | 요구사항 | SG | P | 출처 | 방법 | 상태 |
|---|---|:--:|:--:|:--:|:--:|:--:|
| REG-006 | `CONTROL.ENABLE`(0x400[0]) = 1일 때만 전송 동작 | ○ | H | SPEC | DIR | ⬜ |
| **REG-007** | **`CONTROL.HWDESC`(0x400[2]) = 1일 때 SG 전송 활성화** | **◆** | H | MEAS | DIR | ⬜ |
| REG-008 | `CONTROL.PAUSE`(0x400[1]) = 1이면 진행 중 전송 일시 정지, 0 복귀 시 재개 | ◇ | M | SPEC | DIR | ⬜ |
| REG-009 | `TRANSFER_SUBMIT`(0x408)은 **RW1S-SC** — 1 write 시 큐잉되고 코어 수락 시 자동 0 복귀 | ○ | H | RTL | DIR | ⬜ |
| REG-010 | `TRANSFER_SUBMIT`에 0 write 또는 **이미 1인 상태의 1 write는 무효** | ○ | M | RTL | DIR | ⬜ |
| REG-011 | `ENABLE = 0` 상태의 `TRANSFER_SUBMIT` write는 **무시되고 에러도 발생하지 않음** | ○ | M | RTL | DIR | ⬜ |
| REG-012 | `TRANSFER_ID`(0x404)는 다음 전송 ID를 반환하며 `TRANSFER_SUBMIT`=0일 때만 유효 | ○ | M | SPEC | DIR | ⬜ |
| REG-013 | `TRANSFER_DONE`(0x428) 비트 x는 ID x 전송 완료 시 set, 신규 제출 시 clear<br/>**SG에서는 체인 전체가 1개 transfer로 취급됨** | ◇ | H | MEAS | DIR | ⬜ |
| REG-014 | `ACTIVE_TRANSFER_ID`(0x42C)는 진행 중 전송 ID, 유휴 시 `TRANSFER_ID`와 동일 | ○ | M | SPEC | DIR | ⬜ |
| **REG-015** | **`SG_ADDRESS`(0x47C)에 write한 값이 read로 확인되며, 최초 descriptor 주소로 사용** | **◆** | H | MEAS | DIR | ⬜ |
| **REG-016** | **`DESCRIPTOR_ID`(0x454)는 처리 중/최종 descriptor의 `id` 반환. HWDESC=0이면 0** | **◆** | H | MEAS | DIR | ⬜ |

#### 상태 · 디버그

| ID | 요구사항 | SG | P | 출처 | 방법 | 상태 |
|---|---|:--:|:--:|:--:|:--:|:--:|
| REG-017 | `CURRENT_SRC_ADDRESS`(0x438) / `CURRENT_DEST_ADDRESS`(0x434)가 진행에 따라 갱신 | ○ | L | SPEC | DIR | ⬜ |
| REG-018 | `TRANSFER_PROGRESS`(0x448)가 목적지 전송 바이트를 반영하고 **EOT 시 0으로 clear** | ○ | L | RTL | DIR | ⬜ |
| REG-024 | `DBG_STATUS`(0x43C)가 reset manager 상태를 반영 | ○ | L | RTL | DIR | ⬜ |

#### 접근 규칙

| ID | 요구사항 | SG | P | 출처 | 방법 | 상태 |
|---|---|:--:|:--:|:--:|:--:|:--:|
| REG-019 | RO 레지스터에 write 시 값이 변하지 않고 정상 응답(OKAY) | ○ | M | SPEC | DIR | ⬜ |
| **REG-021** | **파라미터로 비활성화된 비트는 write가 무시되고 0으로 읽힘**<br/>`CONTROL[3]`, `FLAGS[0]`, 주소 `[2:0]`, `*_ADDRESS_HIGH`, `Y_LENGTH`, `*_STRIDE`, `FRAMELOCK_*` | ○ | H | MEAS | DIR | ⬜ |
| REG-022 | 미매핑 주소 읽기 시 `0x0000_0000` 반환, **에러 응답 없음** | ○ | M | MEAS | DIR | ⬜ |
| REG-023 | `WSTRB`가 무시되어 모든 쓰기가 32bit 전체 쓰기로 처리됨 | ○ | M | RTL | DIR | ⬜ |

> **REG-021이 중요한 이유 — 오판 방지.** 이 동작을 문서화하지 않으면 "RW 레지스터
> write/read-back" 테스트가 **정상 마스킹을 버그로 보고**한다. 기대값을 SOR와 TB 양쪽에
> 고정해두는 것이 목적이다.

> **REG-023 주의:** `WSTRB`가 무시되므로 byte/halfword 쓰기를 하면 나머지 바이트가 버스에
> 실린 값으로 덮어써진다. **드라이버는 항상 32bit 단위로 접근해야 한다.**

### 검증 시나리오

#### SAN-001 — Register Identity (A)

| | |
|---|---|
| **목적** | AXI4-Lite 경로와 레지스터맵 오프셋이 올바른지 확인 |
| **커버** | REG-001, REG-002, REG-004, REG-005, REG-020 |
| **상태** | ⬜ 미검증 |

**기대 결과 (실측 확정)**

| 레지스터 | 기대값 | 근거 |
|---|---|---|
| `VERSION`(0x000) | `0x0004_0565` | IP 버전 4.05.65 |
| `PERIPHERAL_ID`(0x004) | `0x0000_0000` | wrapper `ID = 0` |
| `IDENTIFICATION`(0x00C) | `0x444D_4143` | "DMAC" ASCII |
| `INTERFACE_DESCRIPTION_1`(0x010) | `0x3807_0303` | 빌드 파라미터 인코딩 |
| `INTERFACE_DESCRIPTION_2`(0x014) | `0x0000_0000` | `AXCACHE=0000`, `AXPROT=000` |

**추가 판정**

- **`VERSION`과 `IDENTIFICATION`은 게이트 역할** — 둘 중 하나라도 틀리면 버스나 레지스터 디코딩이 깨진 것이므로 **이후 시나리오를 전부 SKIP**한다
- `INTERFACE_DESCRIPTION_1`은 **레지스터 한 번 읽기로 빌드 구성 전체를 확인**한다. `DMA_TYPE_SRC/DEST`, `BYTES_PER_BEAT`, `MAX_BYTES_PER_BURST`, `MAX_NUM_FRAMES`가 모두 인코딩되어 있어, 이 값이 맞으면 **의도한 파라미터로 합성되었음이 증명**된다

---

#### SAN-002 — Scratch Read/Write (A)

| | |
|---|---|
| **목적** | AXI4-Lite **write** 경로 확인 (SAN-001은 read만 검증) |
| **커버** | REG-003 |
| **상태** | ⬜ 미검증 |

**절차**

| # | 동작 | 기대 |
|:--:|---|---|
| 1 | `0x008` ← `0xA5A5_5A5A`, read | `0xA5A5_5A5A` |
| 2 | `0x008` ← `0x5A5A_A5A5`, read | `0x5A5A_A5A5` |
| 3 | `0x008` ← `0x0000_0000`, read | `0x0000_0000` |

> **패턴을 반전해 두 번 쓰는 이유:** 한 패턴만 쓰면 일부 비트가 고착(stuck-at)되어 있어도
> 통과한다. 교번 패턴 쌍으로 비트 단위 결함을 함께 본다.

---

#### SAN-007 — Parameter-masked Bits (A)

| | |
|---|---|
| **목적** | 파라미터로 **의도적으로 죽인 비트**가 실제로 죽어 있는지 확인 |
| **커버** | REG-021, REG-022 |
| **상태** | ⬜ 미검증 |

**기대 결과 (실측 확정)**

| # | 동작 | 기대값 | 근거 파라미터 |
|:--:|---|---|---|
| 1 | `0x400` ← `0xFFFF_FFFF`, read | `0x0000_0007` | `FRAMELOCK=0` |
| 2 | `0x40C` ← `0xFFFF_FFFF`, read | `0x0000_0006` | `CYCLIC=0` |
| 3~5 | `0x410`/`0x414`/`0x47C` ← `0xFFFF_FFFF`, read | `0xFFFF_FFF8` | 64bit 폭 → 8B 정렬 |
| 6~8 | `0x490`/`0x494`/`0x4BC` read | `0x0000_0000` | `ADDR_WIDTH=32` |
| 9 | `0x41C` read | `0x0000_0000` | `DMA_2D_TRANSFER=0` |
| 10 | `0x458` read | `0x0000_0000` | `FRAMELOCK=0` |
| 11 | 미매핑(`0x0F0`, `0x600`) read | `0x0000_0000` | 양쪽 regmap `default` |

**필수 사후 처리**

이 시나리오는 레지스터에 write를 수행하므로 **종료 전 반드시 원복**한다. 특히 `CONTROL`에 `0xF`를 쓰면 `ENABLE=1`이 되어 **이후 전송 시나리오의 전제가 깨진다.**

```
0x400 ← 0x0000_0000      // ENABLE 해제 — 생략 시 SAN-004 전제 붕괴
0x40C ← 0x0000_0002      // FLAGS 리셋값 복원
0x410 / 0x414 / 0x47C ← 0x0000_0000
```

**제외 대상**

| 주소 | 사유 |
|---|---|
| `0x450` `PARTIAL_TRANSFER_ID` | **읽기가 FIFO를 pop** — 레지스터 순회에서 제외 |
| `0x440`/`0x444` `DBG_IDS0/1` | **Gray 인코딩 값** — 안정적 기대값 정의 불가 |

---

#### FT-007 — Transfer Queueing (B)

| | |
|---|---|
| **목적** | 진행 중 전송이 있는 상태에서 다음 전송 연속 제출 |
| **커버** | REG-009, REG-010, REG-012, REG-014, FUNC-008 |
| **출처** | ADI `test_program_tr_queue` |

**메모리 배치**

| 체인 | descriptor | 소스 | 총 길이 | 목적지 |
|---|---|---|:--:|---|
| A | `0x0000_1300` ~ (3개) | `0x0001_A000` ~ | 1,536 B | `0x0002_8000` |
| B | `0x0000_1400` ~ (3개) | `0x0001_C000` ~ | 1,536 B | `0x0002_A000` |

체인 A를 충분히 길게 하여 **B 제출 시점에 A가 진행 중**이 되도록 한다.

**절차**

```
 1. 체인 A, B를 메모리에 작성
 2. IRQ_MASK = 0x1, CONTROL = 0x5
 3. TRANSFER_ID read → ID_A 기록
 4. SG_ADDRESS = chainA, TRANSFER_SUBMIT = 1
 5. TRANSFER_SUBMIT이 0이 될 때까지 폴링        ← 큐잉 완료 (REG-009)
 6. TRANSFER_ID read → ID_B 기록
 7. ACTIVE_TRANSFER_ID read                     ← A가 진행 중인지 (REG-014)
 8. SG_ADDRESS = chainB, TRANSFER_SUBMIT = 1
 9. TRANSFER_SUBMIT이 0이 될 때까지 폴링
10. 두 전송 완료까지 irq 처리 반복
11. TRANSFER_DONE 확인, A·B 목적지 데이터 각각 검증
```

**추가 판정**

| # | 항목 |
|:--:|---|
| 1 | `ID_A` ≠ `ID_B` (순차 증가) |
| 2 | 7번 시점 `ACTIVE_TRANSFER_ID` = `ID_A` |
| 3 | 최종 `TRANSFER_DONE`에 `ID_A`, `ID_B` 비트 모두 set |
| 4 | 5·9번 폴링이 무한 대기에 빠지지 않음 |
| 5 | **B 제출 시점에 A가 미완료**임을 로그로 확인 (queueing의 증거) |
| 6 | 이미 1인 상태에서 1을 재write 시 요청이 중복되지 않음 (REG-010) |

> **SG에서의 의미:** SG에서는 **체인 하나가 하나의 transfer**다. 즉 이 시나리오는
> "체인 A 전체가 진행 중일 때 체인 B를 예약할 수 있는가"를 묻는다.

---

#### FT-010 — Status Register Tracking (B)

| | |
|---|---|
| **목적** | 진행 상태 레지스터가 실제 진행을 반영 |
| **커버** | REG-017, REG-018, REG-024 |

**절차**

1. 4 KB 단일 descriptor 전송 시작
2. 전송 중 100 cycle 간격으로 `CURRENT_SRC_ADDRESS`, `CURRENT_DEST_ADDRESS`, `TRANSFER_PROGRESS`, `DBG_STATUS` read
3. 완료 후 재read

**기대 결과**

| 항목 | 기대 동작 |
|---|---|
| `CURRENT_SRC_ADDRESS` | `0x1_0000`에서 시작해 단조 증가 |
| `CURRENT_DEST_ADDRESS` | `0x2_0000`에서 시작해 단조 증가 |
| `TRANSFER_PROGRESS` | 0에서 증가, 최대 4096 도달 |
| **완료 후 `TRANSFER_PROGRESS`** | **0으로 clear** (EOT 시 지워짐) |
| `DBG_STATUS[2:0]` | 전송 중 `4`(ENABLED) |

---

#### FT-014 — Register Access Rules (B)

| | |
|---|---|
| **목적** | RO write 무시, WSTRB 무시, `ENABLE=0`에서의 SUBMIT 무시 |
| **커버** | REG-011, REG-019, REG-023 |

**절차**

| # | 동작 | 기대 |
|:--:|---|---|
| 1 | `VERSION`(0x000)에 `0xFFFF_FFFF` write → read | `0x0004_0565` 불변, BRESP = OKAY |
| 2 | `IRQ_SOURCE`(0x088)에 write → read | 불변, OKAY |
| 3 | `SCRATCH`에 `WSTRB = 4'b0001`로 `0x0000_00FF` write → read | **`0x0000_00FF`** (상위 바이트도 덮어써짐) |
| 4 | `CONTROL = 0x0` 상태에서 `TRANSFER_SUBMIT = 1` write → read | `0x0`, 전송 미발생 |

> **3번이 핵심이다.** `WSTRB`가 무시되므로 **부분 쓰기가 전체 쓰기로 동작**한다.
> 기대값이 `0xFFFF_FFFF & 상위 유지`가 아니라 **버스에 실린 값 그대로**임을 확인한다.

---

#### FT-011 — ENABLE Toggle & Graceful Tear-down (B)

| | |
|---|---|
| **목적** | 전송 중 비활성화 시 진행 중 트랜잭션이 정상 종료되고, 설정은 유지되는지 |
| **커버** | REG-006 |

**절차**

1. 긴 체인(8 descriptor × 512 B) 전송 시작
2. 진행 중인 시점에 `CONTROL = 0x4` (ENABLE clear, HWDESC 유지)
3. AXI 버스가 조용해질 때까지 관측
4. **설정 레지스터군과 추적 상태군을 각각 read**
5. `CONTROL = 0x5`로 재활성화
6. 새 전송(SAN-004와 동일)을 제출하고 정상 완료 확인

**추가 판정**

| # | 항목 |
|:--:|---|
| 1 | disable 직후 신규 AR/AW 발행 중단 |
| 2 | 진행 중 burst는 **완료까지 진행** (중간 절단 없음) |
| 3 | **hang 없이** 버스가 idle로 수렴 |
| 4 | `TRANSFER_ID` / `ACTIVE_TRANSFER_ID` / `TRANSFER_DONE` / `TRANSFER_PROGRESS` = 0 (SFR §8) |
| 5 | `SG_ADDRESS` / `FLAGS` / `IRQ_MASK` / `IRQ_SOURCE` **값 유지** (SFR §8) |
| 6 | 재활성화 후 전송이 이전 상태에 영향받지 않음 |

> **SG 고유의 관심사:** 체인 **중간**에서 중단되므로, 남은 descriptor가 어떻게 처리되는지
> (폐기되는지, 재활성화 시 이어지는지)를 관측해야 한다.

---

#### FT-012 — Pause / Resume (B)

| | |
|---|---|
| **목적** | 일시 정지 후 재개 시 데이터 무결성 |
| **커버** | REG-008 |

**절차**

1. 긴 전송(4 KB) 시작
2. 진행 중 `CONTROL = 0x7` (ENABLE \| PAUSE \| HWDESC)
3. 1,000 cycle 대기하며 버스 활동 관측
4. `CONTROL = 0x5` (PAUSE clear)
5. 전송 완료 대기 후 데이터 비교

**추가 판정**

- pause 중 신규 트랜잭션 중단, `TRANSFER_PROGRESS` 정지
- resume 후 **중단 지점부터 이어서** 진행
- **데이터 손실·중복 없음** (이 시나리오의 핵심)
- `PAUSE`는 리셋 펄스를 내지 않으므로 추적 상태가 **유지**되어야 함 (FT-011의 `ENABLE=0`과 대비 — SFR §8)

---

> **FT-011 · FT-012는 본 개정에서 3-1에서 이 절로 옮겨왔다.** [3-1](#3-1-reset--clock)이
> 해당사항 없음이 되면서 `CONTROL.ENABLE` · `CONTROL.PAUSE`의 요구사항이 REG-006 ·
> REG-008 하나씩만 남았기 때문이다. 두 시나리오는 [SFR 문서 §8 리셋 · ENABLE · PAUSE
> 영향 매트릭스](SGDMA-SFR-rel-v1.0.0.md)를 기대값으로 사용한다. 그 매트릭스는
> **전부 RTL 분석(R) 근거이며 한 줄도 측정되지 않았다** — 한 칸이라도 틀리면 두 시나리오가
> FAIL한다.

---

## 3-4. Interrupt

### 범위

인터럽트 이벤트 기록 · 마스크 · 클리어와, **SG 모드에서의 이벤트 의미**를 다룬다.

### 신호 경로

```
이벤트 ──▶ IRQ_SOURCE(0x088) ──▶ ~IRQ_MASK(0x080) & ──▶ IRQ_PENDING(0x084) ──▶ irq
          (래치, 마스크 무관)                           (조합 결과, 저장소 아님)   (level)
```

| Bit | 이벤트 | 발생 조건 (HWDESC=1) |
|:--:|---|---|
| `[0]` | `TRANSFER_QUEUED` (SOT) | **체인 제출 1회당 1회** |
| `[1]` | `TRANSFER_COMPLETED` (EOT) | **`flags[1]=1`인 descriptor가 끝날 때마다** |

### 요구사항

| ID | 요구사항 | SG | P | 출처 | 방법 | 상태 |
|---|---|:--:|:--:|:--:|:--:|:--:|
| IRQ-001 | `TRANSFER_COMPLETED` — 전송 완료 시 이벤트 기록<br/>**SG에서는 `flags[1]=1`인 descriptor마다 발생** | ◇ | H | MEAS | DIR | ⬜ |
| IRQ-002 | `TRANSFER_QUEUED` — 전송이 큐로 이동(= `TRANSFER_SUBMIT` 1→0) 시 이벤트 기록 | ○ | M | SPEC | DIR | ⬜ |
| IRQ-003 | `IRQ_MASK`(0x080) 비트가 **1이면 마스크(비활성)**, 0이면 활성. 리셋값 `0x3` | ○ | H | MEAS | DIR | ⬜ |
| IRQ-004 | `IRQ_PENDING`(0x084)은 `~MASK & SOURCE`를 반영하며 **1 write로 `IRQ_SOURCE`를 clear** | ○ | H | MEAS | DIR | ⬜ |
| IRQ-005 | `IRQ_SOURCE`(0x088)는 **마스크와 무관하게** 이벤트 기록. 마스크 해제 시 pending으로 전파 | ○ | M | MEAS | DIR | ⬜ |
| IRQ-006 | 다수 전송이 연속 완료되어도 인터럽트 누락 없이 `TRANSFER_DONE`으로 모두 식별 가능 | ○ | M | SPEC | DIR | ⬜ |

> **IRQ-001이 SG 상호작용인 이유:** SG의 핵심 이점은 **체인된 전송을 하나로 취급하여
> 인터럽트를 줄이는 것**이다. descriptor 5개 체인에서 인터럽트가 5회 발생하면 SG를 쓰는
> 의미가 없다. 따라서 "체인당 1회"는 단순 기능 확인이 아니라 **SG의 설계 의도가 지켜지는지**에
> 대한 검증이다. 동시에 **원할 때 중간 인터럽트를 받을 수 있어야** 하므로 FT-006과 쌍을 이룬다.

> **IRQ-004 주의 — 이름과 실제가 다르다.** `IRQ_PENDING`에 write하지만 지워지는 것은
> `IRQ_SOURCE`다. `IRQ_PENDING`은 독립 저장소가 아니라 조합 결과다.

> **`irq`는 level 신호다.** 원인을 지울 때까지 유지된다. **edge-trigger 인터럽트
> 컨트롤러에 직결하면** 한 이벤트 처리 중 다른 이벤트가 들어올 때 레벨이 내려가지 않아
> 두 번째 엣지를 놓친다. SoC 통합 시 **level-trigger로 연결**한다.

### 검증 시나리오

#### SAN-006 — IRQ & Status (A)

| | |
|---|---|
| **목적** | 인터럽트 기록 · 마스크 · 클리어와 상태 레지스터 |
| **커버** | IRQ-001, IRQ-003, IRQ-004, IRQ-005, REG-013, REG-016 |
| **상태** | ⬜ 미검증 |

**절차**

1. 단일 descriptor(64 B, `id=0xC5`, `flags=0x3`) 작성
2. `IRQ_MASK` read → `0x1` 확인 (EOT만 unmask)
3. 전송 시작 → irq 대기
4. `IRQ_PENDING` read → `[1]` = 1 확인
5. 읽은 값을 그대로 write (W1C)
6. `IRQ_PENDING` 재read → `0x0` 확인
7. **`IRQ_SOURCE` read → `0x1` 확인**
8. irq de-assert 확인
9. `DESCRIPTOR_ID` read → `0xC5` 확인

**추가 판정**

| # | 항목 | 의미 |
|:--:|---|---|
| 1 | W1C 이후 `IRQ_PENDING` = 0이고 irq가 내려감 | IRQ-004 |
| 2 | **W1C 이후 `IRQ_SOURCE[0]`(SOT)이 `1`로 남음** | **IRQ-005 직접 증거** — 마스크된 이벤트도 SOURCE에는 기록됨 |
| 3 | `IRQ_MASK = 0x1`이므로 `IRQ_PENDING[0]`은 항상 0 | IRQ-003 |

> **7번이 IRQ-005의 핵심 증거다.** SOT는 마스크되어 있어 `IRQ_PENDING`에는 나타나지
> 않지만 `IRQ_SOURCE`에는 기록된다. 또한 W1C로 EOT만 지웠으므로 SOT는 남는다.
> 이 한 번의 읽기로 **"SOURCE는 마스크와 무관"** 과 **"W1C는 지정한 비트만 지움"** 이
> 동시에 확인된다.

---

#### FT-006 — Per-Descriptor IRQ (B)

| | |
|---|---|
| **목적** | descriptor별 `EOT_IRQ` flag로 중간 인터럽트 발생 |
| **커버** | IRQ-001, IRQ-006, DESC-005 |

**메모리 배치 (체인 4개, 각 128 B, id = `0xC0`~`0xC3`)**

| # | `flags` | 의도 |
|:--:|---|---|
| 0 | `2'b10` | IRQ only — 중간 인터럽트 |
| 1 | `2'b00` | 조용히 진행 |
| 2 | `2'b10` | IRQ only |
| 3 | `2'b11` | LAST + IRQ |

**절차**

1. 체인 작성 후 전송 시작
2. irq를 **반복 감시**하며 발생할 때마다 `IRQ_PENDING` W1C → `DESCRIPTOR_ID` 기록 → 카운트
3. 마지막 descriptor 완료까지 반복

**기대 결과**

| 항목 | 기대값 |
|---|---|
| irq 발생 횟수 | **3회** (descriptor 0, 2, 3) |
| 각 시점 `DESCRIPTOR_ID` | `0xC0`, `0xC2`, `0xC3` |
| descriptor 1 완료 시점 | **irq 미발생** |

> **구현 주의:** irq가 level이므로 clear 전에 다음 irq가 겹칠 수 있다. clear 후 irq가
> 내려갔다가 다시 올라오는지 확인하는 로직이 필요하며, 겹침이 관측되면
> **`DESCRIPTOR_ID` 변화**로 구분한다.

> **SAN-005와 쌍을 이룬다.** SAN-005는 "체인 전체에 irq 1회", FT-006은 "원할 때 중간 irq".
> **둘 다 성립해야** SG의 인터럽트 제어가 의도대로 동작하는 것이다.

---

#### FT-013 — IRQ Mask Combinations (B)

| | |
|---|---|
| **목적** | 마스크 조합별 인터럽트 전파 |
| **커버** | IRQ-002, IRQ-003, IRQ-005 |

**조합**

| # | `IRQ_MASK` | QUEUED | COMPLETED | 기대 irq | 기대 `IRQ_PENDING` | 기대 `IRQ_SOURCE` |
|:--:|---|---|---|---|---|---|
| 1 | `0x3` | mask | mask | **발생 안 함** | `0x0` | `0x3` |
| 2 | `0x2` | 활성 | mask | QUEUED만 | `0x1` | `0x3` |
| 3 | `0x1` | mask | 활성 | COMPLETED만 | `0x2` | `0x3` |
| 4 | `0x0` | 활성 | 활성 | 둘 다 | `0x3` | `0x3` |

**절차 (조합마다)**

1. `IRQ_MASK` 설정 → SAN-004 전송 실행
2. irq 발생 여부·시점 기록
3. `IRQ_PENDING`, `IRQ_SOURCE` read → W1C clear

**추가 판정**

| # | 항목 |
|:--:|---|
| 1 | **`IRQ_SOURCE`는 모든 조합에서 `0x3`** — 마스크와 무관하게 기록 (IRQ-005) |
| 2 | 조합 1에서 **전송 후 마스크를 해제하면 지연 전파**되어 irq가 올라옴 |
| 3 | `IRQ_PENDING` W1C가 마스크 여부와 무관하게 `IRQ_SOURCE`를 지움 |

> **2번이 드라이버 설계에 중요하다.** 마스크 상태에서 쌓인 이벤트가 unmask 순간 터져
> 나온다. 드라이버는 **unmask 전에 `IRQ_PENDING`에 `0x3`을 써서 비우는** 순서를 지켜야 한다.

---

---

## 3-5. Low Power

**현재 IP 버전에서는 해당사항 없음.**

---

## 3-6. Security

**현재 IP 버전에서는 해당사항 없음.**

---

## 3-7. AXI Protocol

### 범위

세 마스터 포트와 하나의 슬레이브 포트가 **AXI4 / AXI4-Lite 규약을 준수**하는지 다룬다.

### 요구사항

| ID | 요구사항 | SG | P | 출처 | 방법 | 상태 |
|---|---|:--:|:--:|:--:|:--:|:--:|
| **AXI-001** | **`m_sg_axi` AR 속성 고정 — `ARLEN=5`, `ARSIZE=3'h3`, `ARBURST=2'h1`(INCR)** | **◆** | H | RTL | ASRT | ⬜ |
| AXI-002 | `m_src_axi` / `m_dest_axi` burst 속성이 데이터 폭 · 버스트 설정과 일치 | ○ | H | SPEC | ASRT | ⬜ |
| AXI-003 | `m_dest_axi` write 시 `WSTRB`가 유효 바이트만 지시하고 `WLAST`가 마지막 beat에만 assert | ○ | H | SPEC | ASRT | ⬜ |
| AXI-004 | 모든 AXI burst가 **4 KB 주소 경계를 넘지 않음** (`m_sg_axi` 포함) | ○ | H | SPEC | ASRT | ⬜ |
| AXI-005 | slave의 `*READY` 지연(backpressure)에도 데이터 손실 · 중복 없이 정상 완료 | ○ | H | — | RND | ⬜ |
| AXI-006 | 다중 outstanding 환경에서 정상 동작 | ○ | M | — | RND | ⬜ |
| AXI-007 | `AxCACHE` / `AxPROT` 출력이 파라미터 설정값과 일치 (**`4'b0000`** / `3'b000`) | ○ | L | MEAS | ASRT | ⬜ |

> **AXI-001이 SG 고유인 이유:** descriptor fetch는 **48 B를 6-beat INCR burst 한 번**으로
> 읽는다. 이 속성이 고정되어 있어야 descriptor 포맷 해석이 성립한다. SG가 없으면 존재하지
> 않는 포트이자 트랜잭션이다.

> **AXI-004 주의:** 스펙은 4 KB 경계 문제를 피하기 위해 전송 시작 주소를
> `MAX_BYTES_PER_BURST`에 정렬할 것을 권고한다. 정렬되지 않은 시작 주소에서 경계 위반이
> 발생하는지가 핵심 검증 포인트이며, **descriptor(48 B)가 경계를 걸치는 경우도 포함**한다.

> **AXI-007 실측:** `INTERFACE_DESCRIPTION_2` 읽기로 `AxCACHE = 4'b0000`,
> `AxPROT = 3'b000`을 확인했다. 다만 **실제 버스 출력과의 일치는 미확인**이므로
> assertion으로 교차 확인이 필요하다.

### TB 선행 요구

본 절의 다수 항목은 **AXI 프로토콜 체커와 랜덤 지연 주입**이 있어야 검증된다.

| 필요 능력 | 커버되는 요구사항 |
|---|---|
| AXI4 프로토콜 assertion (handshake, burst, 4KB) | AXI-001~004, AXI-007 |
| 랜덤 `*READY` 지연 | AXI-005 |
| multiple outstanding 슬레이브 모델 | AXI-006 |

### 검증 시나리오

#### FT-005 — Burst Split Check (B)

| | |
|---|---|
| **목적** | 전송이 `MAX_BYTES_PER_BURST` 단위로 분할됨 |
| **커버** | AXI-002, FUNC-006, FUNC-007 |

**절차**

1. 512 B 단일 descriptor 전송
2. AR/AW 트랜잭션을 **자동 카운트 · 기록**
3. 기대 패턴과 비교

**기대 결과**

| 항목 | 기대값 |
|---|---|
| SRC AR 횟수 | 4 (512 / 128) |
| SRC AR 주소 | `0x1_0000`, `0x1_0080`, `0x1_0100`, `0x1_0180` |
| 각 AR `ARLEN` | 15 (16 beat × 8 B = 128 B) |
| DST AW 횟수 | 4 |
| store-and-forward | 각 SRC AR 완료 **후** 대응 DST AW 시작 |

> **현재는 `$display` 출력만 있다.** slave 모델에서 AR/AW를 자동 집계하여 비교하도록
> 보강해야 한다.

---

#### FT-009 — Backpressure (B)

| | |
|---|---|
| **목적** | slave의 ready 지연에도 데이터 무결성 유지 |
| **커버** | AXI-005 |
| **선행** | 랜덤 `*READY` 지연 주입 |

**조건 조합**

| 반복 | SG 지연 | SRC 지연 | DST 지연 |
|:--:|:--:|:--:|:--:|
| 1 | 0 | 0 | 0~15 |
| 2 | 0 | 0~15 | 0 |
| 3 | **0~15** | 0 | 0 |
| 4 | 0~7 | 0~7 | 0~7 |
| 5 | 0~15 | 0~15 | 0~15 |

**절차** SAN-005(3-descriptor gather)를 각 조합으로 반복 실행

**추가 판정**

- 모든 조합에서 데이터 100% 일치
- 지연이 커질수록 **완료 시간만 증가하고 결과는 동일**
- AXI assertion: `*VALID` assert 후 `*READY`까지 payload 유지

> **조합 3의 의미:** SG 포트만 지연시키면 **descriptor fetch가 느려졌을 때 데이터 전송이
> 어떻게 대기하는지**를 볼 수 있다. **SG 고유의 스트레스 조건**이다.

---

#### CT-001~003 — 4KB Boundary (C)

| TC | SG | 조건 | 커버 |
|---|:--:|---|---|
| CT-001 | ○ | `src = 0x0000_0F80`, len 256 → 데이터 burst가 4 KB 경계 통과 | AXI-004 |
| CT-002 | ◇ | `src = 0x0000_0F83`, len 256 → 비정렬 + 경계 | AXI-004, FUNC-005 |
| **CT-003** | **◆** | **descriptor를 `0x0000_0FF0`에 배치** (48 B가 4 KB 경계를 걸침) | **AXI-004, DESC-008** |

> **CT-003이 SG 고유인 이유:** descriptor fetch는 48 B를 **1회 burst**로 읽는다. 이것이
> 4 KB 경계를 걸치면 AXI 규약 위반이 되거나 DUT가 스스로 분할해야 한다.
> **SG에만 존재하는 실패 모드**이며, DESC-008(8B 정렬)도 함께 닫힌다.

---

---

## 3-8. IP Core Function

### 범위

**본 절이 SOR의 본체다.** descriptor 처리, 전송 기능, 에러 처리를 다룬다. SG 고유 요구사항 18개 중 **16개가 이 절에 있다.**

### 3-8-1. DESC — Descriptor 처리

이 카테고리는 **전부 SG 고유**다. SG가 없으면 descriptor 개념 자체가 존재하지 않는다.

| ID | 요구사항 | SG | P | 출처 | 방법 | 상태 |
|---|---|:--:|:--:|:--:|:--:|:--:|
| DESC-001 | descriptor 1개를 `m_sg_axi`로 **64bit × 6 beat = 48 byte**, INCR burst(`ARLEN=5`, `ARSIZE=3`)로 fetch | ◆ | H | MEAS | DIR+ASRT | ⬜ |
| DESC-002 | descriptor 필드 배치를 정확히 해석<br/>`+0x00` flags/id · `+0x08` dest · `+0x10` src · `+0x18` next · `+0x24` x_len | ◆ | H | MEAS | DIR | ⬜ |
| DESC-003 | `flags[0]`(LAST) = 1이면 해당 descriptor 처리 후 체인 종료 및 IDLE 복귀 | ◆ | H | MEAS | DIR | ⬜ |
| DESC-004 | `flags[0]` = 0이면 `next_sg_addr`가 가리키는 다음 descriptor를 fetch | ◆ | H | MEAS | DIR | ⬜ |
| DESC-005 | `flags[1]`(EOT_IRQ) = 1이면 해당 세그먼트 전송 완료 시 인터럽트 발생 | ◆ | H | MEAS | DIR | ⬜ |
| DESC-006 | `id` 필드가 `DESCRIPTOR_ID` 레지스터로 보고됨 | ◆ | M | MEAS | DIR | ⬜ |
| DESC-007 | `x_length` 해석은 **전송 바이트 수 − 1** | ◆ | H | MEAS | DIR | ⬜ |
| DESC-008 | descriptor 주소 하위 3bit는 무시됨 (8-byte 정렬) | ◆ | M | RTL | DIR | ⬜ |
| DESC-009 | descriptor fetch가 데이터 전송과 **파이프라인으로 중첩** 수행됨 (prefetch) | ◆ | M | MEAS | DIR | ⬜ |

> **DESC-006 실측 결과 (2026-10-02 확정):** 체인 완료 후 `DESCRIPTOR_ID`는
> **마지막으로 완료된 descriptor의 `id`를 유지**한다. 3-descriptor 체인(`0xB0`→`0xB1`→`0xB2`)에서
> `0xB2`를 반환함을 확인했다. SG 완료 추적 FIFO가 비면 출력이 갱신되지 않기 때문이다.
>
> **다만 이는 `util_axis_fifo`의 구현 특성이지 ADI가 문서화한 계약이 아니다.**
> 드라이버가 완료 판정 근거로 삼는 것은 권장하지 않는다. 완료 확인은 EOT 인터럽트 또는
> `TRANSFER_DONE`으로 하고, 이 레지스터는 **디버깅 · 추적 용도**로 쓴다.

> **DESC-009 실측 근거:** 3-descriptor 체인에서 SG AR이 4,215 / 4,295 / 4,375 ns에 발생하고
> 첫 SRC AR이 4,335 ns에 발생했다. **세 번째 descriptor fetch가 첫 데이터 읽기보다 늦다** —
> 즉 fetch와 전송이 겹쳐 진행된다.

> **2D 필드:** descriptor의 `y_length` · `src_stride` · `dest_stride`는 2D 전송 전용이며
> 본 검증에서는 항상 `0`으로 기록한다. 해당 필드의 동작은 범위 밖이다.

### 3-8-2. FUNC — 전송 기능

| ID | 요구사항 | SG | P | 출처 | 방법 | 상태 |
|---|---|:--:|:--:|:--:|:--:|:--:|
| FUNC-001 | descriptor 1개로 지정 길이만큼 메모리→메모리 복사가 바이트 단위로 정확 | ○ | H | MEAS | DIR | ⬜ |
| **FUNC-002** | **Gather — 흩어진 다수 소스 영역을 연속 목적지로 모음** | **◆** | H | MEAS | DIR | ⬜ |
| **FUNC-003** | **Scatter — 연속 소스를 흩어진 다수 목적지로 분산** | **◆** | H | SPEC | DIR | ⬜ |
| **FUNC-004** | **임의 길이 N(1 ≤ N ≤ 상한)의 descriptor 체인을 순서대로 처리** | **◆** | H | SPEC | DIR+RND | ⬜ |
| FUNC-005 | MM→MM 구성에서 **바이트 단위 임의 길이** 전송 가능 (정렬 제약 없음) | ◇ | H | RTL | DIR+RND | ⬜ |
| FUNC-006 | 전송이 `MAX_BYTES_PER_BURST`(128 B) 단위로 분할되어 AXI burst 발행 | ○ | M | MEAS | DIR | ⬜ |
| FUNC-007 | store-and-forward 동작 — 소스 burst 수신 완료 후 목적지 write 시작 | ○ | L | MEAS | DIR | ⬜ |
| FUNC-008 | 진행 중 전송이 있는 상태에서 다음 전송을 연속 submit(queueing) 가능 | ◇ | H | SPEC | DIR | ⬜ |
| FUNC-009 | 목적지 write 영역 밖(전송 길이 이후)이 오염되지 않음 | ○ | H | MEAS | DIR | ⬜ |
| FUNC-010 | 비정렬 주소에서의 동작이 정의되고 데이터가 정확 **[확인 필요]** | ◇ | M | — | DIR | ⬜ |

> **FUNC-005의 중요성:** `axi_dmac.v`가 `/* MM has no alignment requirements */` 주석과
> 함께 MM→MM일 때 `DMA_LENGTH_ALIGN = 0`으로 계산한다. 이는 **ADI `dma_sg` TB가 검증하지
> 않는 구성**이며(양쪽 모두 한쪽이 Stream), 우리 프로젝트에서 0-replication 패치를 유발한
> 경로다. **본 검증의 고유 가치가 집중된 항목이다.**

### 3-8-3. ERR — 에러 · 예외 처리

| ID | 요구사항 | SG | P | 출처 | 방법 | 상태 |
|---|---|:--:|:--:|:--:|:--:|:--:|
| ERR-001 | `m_src_axi` read 응답이 SLVERR/DECERR일 때 동작이 정의되고 hang 미발생 **[확인 필요]** | ◇ | H | — | DIR | ⬜ |
| **ERR-002** | **`m_sg_axi` descriptor fetch 응답이 에러일 때의 동작 [확인 필요]** | **◆** | H | RTL | DIR | ⬜ |
| ERR-003 | `m_dest_axi` write 응답이 에러일 때의 동작 **[확인 필요]** | ◇ | H | — | DIR | ⬜ |
| ERR-004 | 잘못된 descriptor 내용(길이 0, next가 자기 자신 등)에서 hang 미발생 **[확인 필요]** | ◆ | M | — | DIR | ⬜ |

> **ERR-002 — RTL에서 확인된 사실:** `dmac_sg.v`는 **`m_sg_axi_rresp`를 검사하지 않는다.**
> 에러 응답이 와도 수신한 데이터를 그대로 descriptor로 사용한다. 즉 **잘못된 주소의
> descriptor를 읽어도 에러 표시 없이 쓰레기값으로 전송이 진행**될 수 있다.
> 이것이 의도된 설계인지, 허용 가능한 동작인지 **판단이 필요하다.**

> **ERR-001 / ERR-003 [확인 필요]:** HDL 문서에 AXI 에러 응답 처리 동작이 명시되어 있지
> 않다. `response_handler.v`, `axi_dmac_response_manager.v` 분석으로 실제 동작을 먼저
> 파악한 뒤 요구사항을 확정해야 한다. **두 TB 모두 에러 주입을 하지 않으므로 이 영역은
> upstream 검증 공백일 가능성이 높다.**

### 검증 시나리오

#### SAN-004 — Single Descriptor Copy (A)

| | |
|---|---|
| **목적** | 가장 단순한 SG 전송 1건이 끝까지 동작 |
| **커버** | DESC-001~003, DESC-007, FUNC-001, FUNC-006, FUNC-009, REG-007, REG-013, REG-015 |
| **상태** | ⬜ 미검증 |

**메모리 배치**

| 영역 | 주소 | 크기 | 내용 |
|---|---|---|---|
| descriptor | `0x0000_1000` | 48 B | 단일 descriptor |
| 소스 | `0x0001_0000` | 256 B | `fill_pattern(tag=0x10)` |
| 목적지 | `0x0002_0000` | 256 B | (전송 결과) |
| guard | `0x0002_0100` | 16 B | **미기록이어야 함** |

**Descriptor**

| 필드 | 값 |
|---|---|
| `flags` | `2'b11` (LAST + EOT_IRQ) |
| `id` | `0xA0` |
| `dest_addr` / `src_addr` | `0x0002_0000` / `0x0001_0000` |
| `next` | `0x0` |
| `x_length` | `255` (= 256 − 1) |

**기대 결과 (실측)**

| 관측 지점 | 기대값 |
|---|---|
| SG AR | `addr=0x1000`, `ARLEN=5`, `ARSIZE=3`, `ARBURST=INCR` — **정확히 1회** |
| SRC AR | `0x1_0000` (16 beat), `0x1_0080` (16 beat) — **128 B 단위 2회** |
| DST AW | `0x2_0000` (16 beat), `0x2_0080` (16 beat) |
| `TRANSFER_DONE` | 해당 비트 set |
| `DESCRIPTOR_ID` | `0xA0` |

**추가 판정**

- SG AR이 **정확히 1회**만 발생 (LAST flag로 체인 종료 — DESC-003)
- 소스 read 총 바이트 = 목적지 write 총 바이트 = 256
- guard 영역 미기록 (FUNC-009)

---

#### SAN-005 — 3-Descriptor Gather (A)

| | |
|---|---|
| **목적** | descriptor 체인 추적과 gather 동작 |
| **커버** | DESC-004, DESC-006, DESC-009, FUNC-002, IRQ-001 |
| **상태** | ⬜ 미검증 |

**메모리 배치**

| # | descriptor | 소스 | 길이 | 목적지 | tag | `flags` |
|:--:|---|---|:--:|---|---|---|
| 0 | `0x0000_1100` | `0x0001_1000` | 128 B | `0x0002_1000` | `0x40` | `2'b00` |
| 1 | `0x0000_1140` | `0x0001_3000` | 256 B | `0x0002_1080` | `0x80` | `2'b00` |
| 2 | `0x0000_1180` | `0x0001_5000` | 64 B | `0x0002_1180` | `0xC0` | `2'b11` |

소스는 **8 KB 간격으로 흩어져** 있고, 목적지는 **연속**이다 (gather).

**기대 결과 (실측)**

| 관측 지점 | 기대값 |
|---|---|
| SG AR 순서 | `0x1100` → `0x1140` → `0x1180` (**정확히 3회**) |
| **SG prefetch** | **첫 DST AW 이전에 SG AR 3회가 모두 완료** |
| DST AW 주소 | `0x2_1000`, `0x2_1080`, `0x2_1100`, `0x2_1180` — **연속** |
| `DESCRIPTOR_ID` | **`0xB2`** (마지막 completed descriptor) |
| irq | **1회만** 발생 |

**추가 판정**

| # | 항목 | 의미 |
|:--:|---|---|
| 1 | 세그먼트별 독립 비교 — 어느 세그먼트가 틀렸는지 식별 가능 | 디버깅성 |
| 2 | 목적지 write가 **소스 세그먼트 경계와 무관하게** 128 B 단위로 재분할 | gather의 증거 |
| 3 | **irq가 1회만 발생** | **SG의 핵심 이점 확인** (IRQ-001) |
| 4 | 완료 후 `DESCRIPTOR_ID` = `0xB2` | DESC-006 (3개 체인이므로 단일 descriptor보다 강한 증거) |

---

#### FT-001 — Scatter (B) ★

| | |
|---|---|
| **목적** | 연속 소스를 흩어진 목적지로 분산 (gather의 역방향) |
| **커버** | **FUNC-003** (SG 고유, 현재 미검증) |
| **착수 순서** | **1순위** |

**메모리 배치**

| # | descriptor | 소스 | 길이 | 목적지 |
|:--:|---|---|:--:|---|
| 0 | `0x0000_1200` | `0x0001_8000` | 128 B | `0x0002_2000` |
| 1 | `0x0000_1240` | `0x0001_8080` | 256 B | `0x0002_4000` |
| 2 | `0x0000_1280` | `0x0001_8180` | 64 B | `0x0002_6000` |

소스는 `0x1_8000`부터 **연속 448 B**, 목적지는 **8 KB 간격으로 분산**.

**추가 판정**

- 각 목적지 영역이 소스의 해당 구간과 일치
- **목적지 영역 사이의 공백**(`0x2_2080`~`0x2_3FFF` 등)이 **미기록** — scatter가 정확히 분리되었는지
- SRC AR 주소가 **연속**, DST AW가 **세 영역으로 분리**되어 발생

> **gather와의 대칭성:** SAN-005(gather)와 FT-001(scatter)이 쌍을 이룬다.
> **두 방향 모두 동작해야 "Scatter-Gather"라는 이름이 성립한다.**

---

#### FT-002 — Chain Length Sweep (B) ★

| | |
|---|---|
| **목적** | 체인 길이에 관계없이 전송이 완결됨 |
| **커버** | **FUNC-004**, DESC-004 |
| **착수 순서** | **2순위** |

**스윕 조건** (세그먼트 각 64 B)

| 반복 | 체인 길이 N | 총 바이트 |
|:--:|:--:|:--:|
| 1 | 1 | 64 |
| 2 | 2 | 128 |
| 3 | 4 | 256 |
| 4 | 8 | 512 |
| 5 | 16 | 1,024 |
| 6 | 32 | 2,048 |

**절차 (반복마다)**

1. 메모리 clear 또는 반복별 주소 영역 이동
2. 소스 N개 영역에 tag = `0x10 + 반복인덱스`로 패턴 기록
3. descriptor N개를 `0x1000 + i*64`에 작성, **마지막만** `flags=2'b11`
4. 표준 시퀀스로 전송
5. 전 세그먼트 비교 + guard 검사

**추가 판정**

- SG AR 횟수 = N (**정확히**)
- `DESCRIPTOR_ID` = 마지막 descriptor의 id
- irq **1회** (체인 길이와 무관)
- N=32에서도 timeout 미발생

> **N=1의 의미:** 체인 길이 1은 SAN-004와 동일하지만, **스윕 루프가 경계에서 정상
> 동작하는지** 확인하는 의미가 있다.

---

#### FT-003 — Transfer Length Sweep (B) ★

| | |
|---|---|
| **목적** | **MM→MM 구성의 바이트 단위 임의 길이 전송 검증** |
| **커버** | **FUNC-005**, FUNC-006, DESC-007, AXI-003 |
| **착수 순서** | **3순위 — ADI TB가 검증하지 않는 우리 고유 영역** |

**배경**

`axi_dmac.v`가 MM→MM일 때 `DMA_LENGTH_ALIGN = 0`으로 계산하므로 길이 정렬 제약이 없다. 이 특성이 실제로 성립하는지, 그리고 **0-replication 패치가 동작을 훼손하지 않았는지** 확인한다.

**스윕 조건**

| 길이 (B) | 검증 의도 | 마지막 beat 유효 바이트 |
|:--:|---|:--:|
| 1 | 최소 (`x_length = 0`) | 1 |
| 2 / 7 | 버스 폭 미만, 홀수 | 2 / 7 |
| 8 | 정확히 1 beat | 8 |
| 9 | 1 beat + 1 B | 1 |
| 63 / 64 / 65 | 8 beat 전후 | 7 / 8 / 1 |
| **127 / 128 / 129** | **버스트 경계 전후** | 7 / 8 / 1 |
| 255 / 256 | 2 버스트 전후 | 7 / 8 |

**추가 판정**

| # | 항목 |
|:--:|---|
| 1 | 정확히 `len` 바이트만 전송 (부족 · 초과 모두 FAIL) |
| 2 | 마지막 partial beat의 `WSTRB`가 **유효 바이트만** 지시 (AXI-003) |
| 3 | 길이 129 B에서 DST AW가 2회 (16 beat + 1 beat) |
| 4 | 길이 1 B에서도 hang · timeout 없음 |

> **실패 시 의미:** 이 시나리오가 실패하면 **0-replication 패치가 동작을 바꿨을 가능성**이
> 있다. 패치 전후 비교로 원인을 분리한다.

---

#### FT-004 — Address Alignment Sweep (B)

| | |
|---|---|
| **목적** | 비정렬 주소에서 전송 정확성 |
| **커버** | FUNC-010, DESC-008 |

**스윕 조건** (길이 64 B 고정)

| src offset | dst offset | 의도 |
|:--:|:--:|---|
| +0 / +0 | | 기준 |
| +1 / +0 | | 소스만 비정렬 |
| +0 / +1 | | 목적지만 비정렬 |
| +1 / +1 | | 양쪽 동일 offset |
| +3 / +5 | | 양쪽 다른 offset |
| +7 / +1 | | 최대 비정렬 |

**추가 판정**

- 스펙상 "정렬되지 않은 주소는 LSB를 0으로 만들어 내부적으로 정렬된다"고 기술되어 있다. **실제 동작을 관측하고 결과를 본 문서에 반영**한다
- 데이터가 기대와 다르게 정렬되면 FAIL이 아니라 **동작 특성으로 기록**하고 제약사항으로 추가

> **이 시나리오는 성격이 이중적이다.** 첫 실행에서는 관측 결과를 로그로 남기고
> (PASS/FAIL 판정 없이), 동작을 확정한 뒤 기대값을 고정하여 **회귀 테스트로 전환**한다.
> [부록 C](#부록-c-미확정-항목)에 등록되어 있다.

---

#### FT-008 — Descriptor ID Tracking (B)

| | |
|---|---|
| **목적** | `DESCRIPTOR_ID`가 처리 중 descriptor를 반영 |
| **커버** | DESC-006, REG-016 |

**메모리 배치** 체인 8개, 각 512 B (폴링 여유 확보), id = `0xD0` ~ `0xD7`

**절차**

1. 체인 작성 후 전송 시작
2. 전송 중 `DESCRIPTOR_ID`를 **주기적으로 폴링**(100 cycle 간격)하여 값 변화 기록
3. 완료 후 기록된 시퀀스 분석

**기대 결과**

- 관측된 id 시퀀스가 `0xD0` → … → `0xD7` 순서를 **벗어나지 않음** (건너뛰기 허용, **역행은 FAIL**)
- 최종값 = `0xD7`
- 전송 완료 전에 `0xD7`이 나타나지 않음

> **prefetch 고려:** descriptor는 데이터 전송보다 앞서 fetch된다(DESC-009). 따라서
> `DESCRIPTOR_ID`가 "현재 전송 중"인지 "최근 fetch한" descriptor인지 폴링으로 확정한다.
> **완료 후 값은 이미 실측으로 확정**되었다(마지막 completed descriptor).

---

#### C — Corner 시나리오 (골격)

| TC | SG | 핵심 조건 | 커버 | 확정 필요 사항 |
|---|:--:|---|---|---|
| CT-004 | ◆ | 체인 **128개** — LONG 영역 사용 | FUNC-004 | — |
| CT-005 | ○ | 길이 `2^24 − 1` 근처 | FUNC-005 | 시뮬레이션 시간 검토 |
| CT-006 | ◇ | back-to-back 전송 20회 반복 | FUNC-008, IRQ-006 | — |
| CT-007 | ○ | src/dst 영역 겹침 | FUNC-001 | **동작 파악 목적** |
| CT-008 | ◆ | `next_sg_addr`가 자기 자신 (무한 루프 체인) | ERR-004 | **ENABLE=0으로만 정지 가능한지** |

#### D — Error 시나리오 (골격)

| TC | SG | 핵심 조건 | 커버 | 선행 |
|---|:--:|---|---|---|
| ET-001 | ◇ | SRC read에 SLVERR 주입 | ERR-001 | **RTL 분석** + 에러 주입 |
| **ET-002** | **◆** | **SG fetch에 SLVERR 주입** | **ERR-002** | 동일 |
| ET-003 | ◇ | DST write에 SLVERR 주입 | ERR-003 | 동일 |
| ET-005 | ◆ | 길이 0 descriptor (`x_length` 필드가 `0xFFFFFF`) | ERR-004 | — |
| ET-004 | ◇ | **전송 중 `resetn` 인가** — 체인 중간 포함 | **없음** ※ | — |

※ **ET-004는 커버하는 요구사항이 없다.** [3-1 Reset / Clock](#3-1-reset--clock)이 해당사항 없음이 되면서 대응 요구사항이 사라졌기 때문이다. 시나리오 자체는 가치가 있어 골격에 남겨두되, **요구사항 없이 수행하는 추가 확인**으로 다룬다.

**ET-001~003 선행 작업**

```bash
grep -n "rresp\|bresp" rtl/third_party/adi_hdl/library/axi_dmac/response_handler.v
grep -n "rresp\|bresp" rtl/third_party/adi_hdl/library/axi_dmac/axi_dmac_response_manager.v
grep -n "rresp"        rtl/third_party/adi_hdl/library/axi_dmac/src_axi_mm.v
grep -n "bresp"        rtl/third_party/adi_hdl/library/axi_dmac/dest_axi_mm.v
```

결과에 따라 기대 동작이 갈린다. 어느 쪽이든 **"hang이 발생하지 않는다"** 는 최소 판정은 공통이다.

> **ET-002 시나리오 구상:** 체인 3개 중 **두 번째 descriptor fetch만 실패**하도록 주소를
> ERR 영역에 배치한다. 첫 세그먼트는 전송되고 두 번째에서 실패하는 상황에서 DUT가
> 정지하는지, 건너뛰는지, hang하는지를 관측한다. `RRESP`를 검사하지 않으므로
> **쓰레기값으로 전송이 진행될 가능성이 높다** — 그 경우 "검출 불가"가 결론이 되며,
> SoC 레벨에서 보호가 필요하다는 제약사항으로 기록한다.

#### E — Random (골격)

| TC | SG | 조건 | 커버 | 선행 |
|---|:--:|---|---|---|
| RT-001 | ◆ | 랜덤 체인 (길이 1~32, 세그먼트 1 B~4 KB, 주소 랜덤) | FUNC-004, FUNC-005 | 랜덤화 + 커버리지 |
| RT-002 | ○ | RT-001 + 랜덤 ready 지연 | AXI-005, AXI-006 | 위 + 지연 주입 |

---

---

## 3-9. Coverage Measurement (Optional)

**가능하면 Toggle Coverage 측정.**

| ID | 요구사항 | SG | P | 출처 | 방법 | 상태 |
|---|---|:--:|:--:|:--:|:--:|:--:|
| COV-001 | 가능하면 Toggle Coverage 측정 | ○ | L | SPEC | COV | ⬜ |
---

# 부록 A. 요구사항 ↔ 시나리오 추적성

## A-1. 요구사항 분포

| CAT | 영역 | 수록 절 | ◆ | ◇ | ○ | 계 |
|---|---|:--:|:--:|:--:|:--:|:--:|
| `RST` | 리셋 · 클럭 | 3-1 | — | — | — | **0** |
| `REG` | 레지스터 접근 | 3-3 | **3** | 2 | 19 | 24 |
| `IRQ` | 인터럽트 | 3-4 | — | 1 | 5 | 6 |
| `AXI` | AXI 프로토콜 | 3-7 | **1** | — | 6 | 7 |
| `DESC` | Descriptor 처리 | 3-8-1 | **9** | — | — | 9 |
| `FUNC` | 전송 기능 | 3-8-2 | **3** | 3 | 4 | 10 |
| `ERR` | 에러 · 예외 | 3-8-3 | **2** | 2 | — | 4 |
| `COV` | 커버리지 | 3-9 | — | — | 1 | 1 |
| | **합계** | | **18** | **8** | **35** | **61** |

**SG 고유(◆) 18건이 본 검증의 핵심이다.** 14건은 [3-8](#3-8-ip-core-function)에 모여 있으나
**나머지 4건은 다른 절에 흩어져 있으므로 3-8만 보면 놓친다.**

| 절 | ◆ 요구사항 | 건수 |
|---|---|:--:|
| **3-3** | **`REG-007`(HWDESC) · `REG-015`(SG_ADDRESS) · `REG-016`(DESCRIPTOR_ID)** | **3** |
| **3-7** | **`AXI-001`(`m_sg_axi` AR 속성 고정)** | **1** |
| 3-8-1 | `DESC-001` ~ `DESC-009` | 9 |
| 3-8-2 | `FUNC-002`(Gather) · `FUNC-003`(Scatter) · `FUNC-004`(체인 길이) | 3 |
| 3-8-3 | `ERR-002`(SG fetch 에러) · `ERR-004`(잘못된 descriptor) | 2 |
| | **합계** | **18** |

> **전 항목이 ⬜(미검증)이다.** Sanity Test가 통과한 항목도 포함한다 — 사유는
> [2-3](#2-3-sanity-test) 참조.

## A-2. 추적성 매트릭스

**시나리오 열의 `SAN-xxx`는 Sanity Test가 동일한 확인을 이미 수행했다는 참고 정보**이며, 요구사항이 검증되었다는 뜻이 아니다.

| 요구사항 | 커버 시나리오 | Priority | 상태 |
|---|---|:--:|:--:|
| REG-001, 002, 004, 005, 020 | SAN-001 | A | ⬜ |
| REG-003 | SAN-002 | A | ⬜ |
| REG-006 | SAN-004, FT-011 | A/B | ⬜ |
| REG-007, 015, 016 | SAN-004, SAN-005, SAN-006 | A | ⬜ |
| REG-008 | FT-012 | B | ⬜ |
| REG-009, 010, 012, 014 | FT-007 | B | ⬜ |
| REG-011, 019, 023 | FT-014 | B | ⬜ |
| REG-013 | SAN-004, SAN-006 | A | ⬜ |
| REG-017, 018, 024 | FT-010 | B | ⬜ |
| REG-021, 022 | SAN-007 | A | ⬜ |
| IRQ-001, 003, 004 | SAN-006 | A | ⬜ |
| IRQ-002, 005 | SAN-006, FT-013 | A/B | ⬜ |
| IRQ-006 | FT-006, CT-006 | B/C | ⬜ |
| AXI-001 | SAN-004 (관측), assertion | A | ⬜ |
| AXI-002 | FT-005 | B | ⬜ |
| AXI-003 | FT-003 | B | ⬜ |
| AXI-004 | CT-001~003 | C | ⬜ |
| AXI-005, 006 | FT-009, RT-002 | B/E | ⬜ |
| AXI-007 | SAN-001 (레지스터), assertion | A | ⬜ |
| DESC-001~003, 007 | SAN-004 | A | ⬜ |
| DESC-004, 006, 009 | SAN-005 | A | ⬜ |
| DESC-005 | SAN-005, FT-006 | A/B | ⬜ |
| DESC-008 | FT-004, CT-003 | B/C | ⬜ |
| FUNC-001, 006, 009 | SAN-004 | A | ⬜ |
| FUNC-002 | SAN-005 | A | ⬜ |
| **FUNC-003** | **FT-001** ★ | B | ⬜ |
| FUNC-004 | SAN-005, FT-002, CT-004 | A/B/C | ⬜ |
| FUNC-005 | FT-003, FT-004 | B | ⬜ |
| FUNC-007 | SAN-004 (관측), FT-005 (판정) | A/B | ⬜ |
| FUNC-008 | FT-007, CT-006 | B/C | ⬜ |
| FUNC-010 | FT-004 | B | ⬜ |
| ERR-001, 003 | ET-001, ET-003 | D | ⬜ |
| ERR-002 | **ET-002** | D | ⬜ |
| ERR-004 | CT-008, ET-005 | C/D | ⬜ |
| COV-001 | 전 Priority B 완료 후 측정 | — | ⬜ |

> **◆ SG 고유 중 Sanity와 겹치지 않는 것**은 FUNC-003(scatter) · FUNC-004(긴 체인) ·
> FUNC-005(바이트 단위 길이) · ERR-002(SG fetch 에러) 네 건이다. **FT-001이 FUNC-003
> 하나로 닫히므로 비용 대비 효과가 가장 크다.**

---

# 부록 B. 시나리오 목록

## B-1. Priority A — Sanity

**구현되어 있으나 본 SOR 상태는 ⬜이다** — [2-3](#2-3-sanity-test) 참조.

| TC | 이름 | 체크 | 수록 절 |
|---|---|:--:|:--:|
| SAN-001 | Register identity | 5 | 3-3 |
| SAN-002 | Scratch R/W | 3 | 3-3 |
| SAN-003 | Reset defaults | 10 | — (3-1 해당사항 없음) |
| SAN-007 | Parameter-masked bits | 11 | 3-3 |
| SAN-004 | Single descriptor copy | 4 | 3-8 |
| SAN-005 | 3-descriptor gather | 6 | 3-8 |
| SAN-006 | IRQ & status | 7 | 3-4 |

## B-2. Priority B — Feature

| TC | 이름 | 커버 ◆/◇ | 착수 순서 | 수록 절 |
|---|---|:--:|:--:|:--:|
| **FT-001** | Scatter | **◆** | **1** | 3-8 |
| **FT-002** | Chain length sweep | **◆** | **2** | 3-8 |
| **FT-003** | Transfer length sweep | ◇ | **3** | 3-8 |
| FT-004 | Address alignment sweep | ◇ | 4 | 3-8 |
| FT-005 | Burst split check | ○ | 6 | 3-7 |
| FT-006 | Per-descriptor IRQ | ◆ | 5 | 3-4 |
| FT-007 | Transfer queueing | ◇ | 5 | 3-3 |
| FT-008 | Descriptor ID tracking | ◆ | 5 | 3-8 |
| FT-009 | Backpressure | ○ | 7 | 3-7 |
| FT-010 | Status register tracking | ○ | 8 | 3-3 |
| FT-011 | ENABLE toggle & tear-down | ◇ | 6 | **3-3** |
| FT-012 | Pause / Resume | ◇ | 6 | **3-3** |
| FT-013 | IRQ mask combinations | ○ | 7 | 3-4 |
| FT-014 | Register access rules | ○ | 8 | 3-3 |

## B-3. Priority C ~ E

| Priority | TC | 수록 절 |
|:--:|---|:--:|
| C | CT-001~003 (4 KB 경계), CT-004~008 | 3-7 / 3-8 |
| D | ET-001~003, ET-005 | 3-8 |
| D | ET-004 (전송 중 리셋) — **커버 요구사항 없음** | 3-8 |
| E | RT-001~002 | 3-8 |

## B-4. 작성 우선순위

| 순서 | 작업 | 닫히는 요구사항 |
|:--:|---|---|
| 1 | **FT-001** ★ | **FUNC-003** (◆) |
| 2 | **FT-002** ★ | FUNC-004 (◆) |
| 3 | **FT-003** ★ | FUNC-005 — **ADI 미검증 영역** |
| 4 | FT-004 | FUNC-010, DESC-008 |
| 5 | FT-006, FT-007, FT-008 | DESC-005, FUNC-008, REG 다수 |
| 6 | FT-011, FT-012 | REG-006, REG-008 |
| 7 | AXI 체커 + 랜덤 지연 → FT-005, FT-009 | AXI-001~006 자동 커버 |
| 8 | CT-001~003 | AXI-004, DESC-008 |
| 9 | RTL 에러 처리 분석 → ET-001~003 | ERR-001~003 |
| 10 | Toggle Coverage 측정 | COV-001 |

> **Sanity와 겹치는 Priority A 항목(SAN-xxx)은 검증팀이 자체 환경에서 먼저 재현한 뒤
> Priority B로 넘어가는 것을 권한다.** 재현에 실패하면 환경 차이를 먼저 해소해야 이후
> 결과를 신뢰할 수 있다.

---

# 부록 C. 미확정 항목

| # | 항목 | 내용 | 해소 방법 | 영향 |
|:--:|---|---|---|---|
| 1 | **ERR-001~003** | AXI 에러 응답 처리 동작이 스펙에 미기재 | RTL 분석 → 요구사항 확정 | 요구사항 문구 |
| 2 | **FUNC-010** | 비정렬 주소 동작 | FT-004 실행 결과 | 요구사항 확정 |
| 3 | ERR-004 | 잘못된 descriptor(길이 0, 자기 참조 next) 동작 | CT-008, ET-005 | 요구사항 확정 |
| 4 | DESC-005 | descriptor별 IRQ의 정확한 발생 시점 | FT-006 | — |
| 5 | REG-018 | `TRANSFER_PROGRESS`의 SG 체인 누적 동작 | FT-010 | — |
| 6 | **`AXCACHE = 4'b0000`** | IP DV에서는 확정. **SoC 성능 영향 재검토 필요** | SoC 통합 시 | 설계 결정 |
| 7 | `DMA_AXI_ADDR_WIDTH = 32` | 확정. **주소 공간 4 GB 초과 시 재결정** | SoC 통합 시 | 설계 결정 |

---

# 부록 D. 가정 및 제약

| # | 내용 |
|:--:|---|
| A1 | DUT는 ADI `axi_dmac`을 **수정 없이** 사용한다. 단 xsim 호환을 위한 **0-replication 패치 1건**이 적용되어 있으며, 이는 기능 변경이 아닌 문법 호환 수정이다. |
| A2 | 세 AXI 마스터(`sg`/`src`/`dest`)는 **동일 메모리 공간**을 공유한다. 실제 SoC의 단일 DDR 상황을 모사한다. |
| A3 | 검증 환경은 **Vivado 2024.2 xsim** 기준이다. RTL은 Verilog-2001, TB는 SystemVerilog로 컴파일한다. |
| A4 | **단일 클럭 도메인(100 MHz)** 을 가정한다. |
| A5 | 본 SOR은 **IP 단위(block-level) 검증**을 대상으로 한다. SoC 통합 검증은 별도 문서로 다룬다. |
| A6 | descriptor는 TB가 직접 메모리에 기록한다. 실제 시스템에서는 **드라이버가 수행**하는 작업이며, 드라이버 검증은 범위 밖이다. |
| A7 | 현 TB 메모리 모델은 **single outstanding**이다. 성능 측정과 AXI-006은 모델 확장 후에만 유효하다. |
| A8 | 내부 ID의 **Gray 인코딩은 유지**한다(2026-10-01 결정). 단일 클럭에서는 불필요하나, 기능 결함이 아니므로 ADI 원본과의 divergence를 최소화한다. |

---
# 부록 E. 개정 이력

| 버전 | 일자 | 내용 |
|---|---|---|
| v0.1 | 2026-09-29 | 최초 작성 |
| v0.2 | 2026-09-29 | Phase 개념 제거, Out of Scope 정리, SG 집중도(◆/◇/○) 도입. 요구사항 63개 |
| v1.0 | 2026-10-06 | 표준 IP DV SOR 형식으로 재편, Test Scenario 문서 통합, 요구사항 70개 |
| **rel-v1.0.0(v2.0)** | **2026-10-06** | **팀 점검 반영 — 검증팀 인계본.** 아래 참조 |

## v1.0 → rel-v1.0.0(v2.0) 변경 내역

| # | 변경 | 내용 |
|:--:|---|---|
| 1 | **블록 다이어그램 전면 재작성** | ASCII 아트 → **SVG 3종** (시스템 연결 / DUT 내부 / 전송 흐름). 모듈 계층은 표로 대체 |
| 2 | **3-1 Reset / Clock** | 내용 전부 삭제 → "Sanity Test에서 커버됨. 해당 사항 없음". **RST-001~006 6건 삭제** |
| 3 | **3-2 Connectivity** | 문구만 남김 — "IP DV level에서는 해당 사항 없음. SoC DV에서 필요" |
| 4 | **3-5 / 3-6** | 문구만 남김 — "현재 IP 버전에서는 해당사항 없음" |
| 5 | **상태 표기** | **✅ · 🟡 전부 제거 → 전 항목 ⬜.** Sanity 통과 항목도 검증팀이 독립 재검증 |
| 6 | **2-3 Sanity Test 신설** | Sanity 문서 링크 및 커버 범위 요약 |
| 7 | **Priority 체계** | `P0`~`P4` → **`A`~`E`** |
| 8 | **목차** | 3-8-1 / 3-8-2 / 3-8-3 등 하위 절 포함 |
| 9 | **3-9 Coverage** | 내용 축소 → "가능하면 Toggle Coverage 측정". **COV 4건 → 1건** |
| 10 | **요구사항 합계** | **70 → 61** (RST −6, COV −3) |

## 시나리오 이동

| 시나리오 | v1.0 | rev-v1.0.0(v2.0) | 사유 |
|---|---|---|---|
| FT-011 (ENABLE toggle) | 3-1 | **3-3** | 커버 요구사항이 RST-003/004/006 → **REG-006** |
| FT-012 (Pause / Resume) | 3-1 | **3-3** | 커버 요구사항이 RST-003/004 → **REG-008** |
| SAN-003 (Reset defaults) | 3-1 | **본문 제외** | 3-1 해당사항 없음. Sanity 문서에만 수록 |
| ET-004 (전송 중 리셋) | 3-1 | **3-8 골격** | RST-005 삭제로 **커버 요구사항 없음**. 추가 확인으로 유지 |

> **RST 요구사항 6건을 삭제하면서 `ENABLE`/`PAUSE` 동작 검증이 REG-006 · REG-008 두
> 건으로 줄었다.** [SFR 문서 §8의 영향 매트릭스](SGDMA-SFR-rel-v1.0.0.md)는
> 여전히 RTL 분석(R) 근거이며 미측정 상태다. FT-011 · FT-012가 그 매트릭스를 기대값으로
> 쓰므로, 두 시나리오를 수행하면 매트릭스 전체가 간접적으로 검증된다.
