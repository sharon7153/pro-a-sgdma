# SGDMA SFR (레지스터) 맵 — 통합본 rev.002

| 항목 | 내용 |
|---|---|
| 문서 ID | SGDMA-SFR-002 |
| 작성일 | 2026-10-02 |
| 작성자 | hrcho |
| 대상 | `sg_dma_top` — `pro-a-sgdma` repo (as-built) |
| 기준 구성 | AXI-MM only / 단일 클록 / Gray-ID 유지 / No 2D / SG 활성 / **`DMA_AXI_ADDR_WIDTH = 32`** |

## 통합 경위

본 문서는 아래 두 문서를 통합한 것입니다.

| 원본 | 작성 | 기여 |
|---|---|---|
| `260930-claude-SFR_MAP-001-jsha.md` (rev.001) | jsha | **문서 구조 전체** — 비트 필드 정의, 접근 유형 체계, 리셋 체계, SG descriptor 포맷, 인터럽트 동작, 프로그래밍 시퀀스 |
| `261001-claude-sgdma_sfr_map-hrcho.md` (v0.2) | hrcho | **실측값** — Sanity Test 46개 체크로 확인한 리셋값·마스킹 동작 |

rev.001의 구조를 유지하고, **시뮬레이션으로 확인된 값을 덮어썼습니다.** 통합 과정에서 두 문서가 어긋난 지점은 [부록 D](#부록-d--통합-시-해소된-충돌)에 정리했습니다.

**가장 중요한 변경은 [§2.5 근거 등급](#25-근거-등급)입니다.** 모든 값에 "RTL을 읽어서 추론한 것"과 "돌려서 확인한 것"을 구분해 표시했습니다. rev.001과 v0.2가 충돌한 원인이 바로 그 구분이 없었기 때문입니다.

---

## 목차

- [1. 기준 구성](#1-기준-구성)
- [2. 레지스터 인터페이스 공통 사양](#2-레지스터-인터페이스-공통-사양)
- [3. 레지스터 맵 요약](#3-레지스터-맵-요약)
- [4. 레지스터 상세](#4-레지스터-상세)
- [5. SG 디스크립터 메모리 포맷](#5-sg-디스크립터-메모리-포맷)
- [6. 인터럽트 동작](#6-인터럽트-동작)
- [7. 프로그래밍 시퀀스](#7-프로그래밍-시퀀스)
- [8. 리셋 · ENABLE · PAUSE 영향 매트릭스](#8-리셋--enable--pause-영향-매트릭스)
- [9. Sanity Test 연계](#9-sanity-test-연계)
- [10. ADDR_WIDTH = 64 전환 시 영향](#10-addr_width--64-전환-시-영향)
- [11. 미확정 항목](#11-미확정-항목)
- [부록 A — 리셋 직후 readback 기대값](#부록-a--리셋-직후-readback-기대값)
- [부록 B — Gray 코드 변환표 (ID_WIDTH = 4)](#부록-b--gray-코드-변환표-id_width--4)
- [부록 C — 관련 문서](#부록-c--관련-문서)
- [부록 D — 통합 시 해소된 충돌](#부록-d--통합-시-해소된-충돌)

---

## 1. 기준 구성

### 1.1 레지스터 맵에 영향을 주는 파라미터

`sg_dma_top.v`가 `axi_dmac`에 넘기는 36개 파라미터 중, 레지스터의 **필드 폭 · 리셋값 · 쓰기 가능 여부**를 바꾸는 것만 추렸습니다.

| 파라미터 | 값 | 출처 | 레지스터 맵 영향 |
|---|:--:|---|---|
| `ID` | `0` | wrapper 명시 | `PERIPHERAL_ID`(0x004) 읽기값 |
| `DMA_TYPE_SRC` / `_DEST` | `0` / `0` (AXI-MM) | wrapper | `INTERFACE_DESCRIPTION_1` 필드, `SRC/DEST_ADDRESS` 활성, `X_LENGTH` 정렬 제약 없음 |
| `DMA_DATA_WIDTH_SRC` / `_DEST` / `_SG` | `64` | wrapper | 주소 레지스터 하위 3비트 무시 |
| **`DMA_AXI_ADDR_WIDTH`** | **`32`** | **wrapper 명시** | **`*_ADDRESS_HIGH` 레지스터 전부 비활성** |
| `DMA_LENGTH_WIDTH` | `24` | wrapper 명시 | `X_LENGTH` 유효 폭 24비트 |
| `DMA_2D_TRANSFER` | `0` | wrapper | `Y_LENGTH`, `*_STRIDE` 비활성 |
| `DMA_SG_TRANSFER` | `1` | wrapper | `CONTROL.HWDESC` 쓰기 가능, `SG_ADDRESS` 활성 |
| `CYCLIC` | `0` | wrapper | `FLAGS.CYCLIC` 쓰기 무시 (항상 0) |
| `FRAMELOCK` | `0` | wrapper 명시 | `CONTROL.FRAMELOCK` 쓰기 무시, `FRAMELOCK_*` 비활성 |
| `MAX_NUM_FRAMES_WIDTH` | `3` | wrapper 명시 | `INTERFACE_DESCRIPTION_1.MAX_NUM_FRAMES` = 7 |
| `MAX_BYTES_PER_BURST` | `128` | wrapper | `INTERFACE_DESCRIPTION_1.BYTES_PER_BURST_WIDTH` = 7 |
| `FIFO_SIZE` | `8` | wrapper | `ID_WIDTH` = 4 → `DBG_IDS0/1` 필드 폭 |
| `USE_EXT_SYNC` / `AUTORUN` | `0` / `0` | wrapper 명시 | `INTERFACE_DESCRIPTION_1` 상위 비트, 모든 리셋값이 non-AUTORUN 쪽 |
| `CACHE_COHERENT` | `0` | wrapper 명시 | `INTERFACE_DESCRIPTION_2[0]` |
| **`AXI_AXCACHE` / `AXI_AXPROT`** | **미지정** | **`axi_dmac` 기본값** | **`INTERFACE_DESCRIPTION_2` — 실측 `0x0000_0000` ⚠ [§4.1.6](#416-interface_description_2-0x014)** |
| `DISABLE_DEBUG_REGISTERS` | `0` | wrapper 명시 | 디버그 레지스터 읽힘 |
| `SYNC_TRANSFER_START` | `0` | wrapper | 레지스터 없음 |

> **rev.001과의 차이 — `DMA_AXI_ADDR_WIDTH`.** rev.001은 이 값을 "RTL 가이드에 명시되지 않음 → `axi_dmac` 기본값 64"로 가정했습니다. 그러나 `sg_dma_top.v`는 **32로 명시**하고 있고, 시뮬레이션도 32로 돌았습니다. 본 문서는 **as-built인 32**를 따릅니다. 64 전환 시 영향은 [§10](#10-addr_width--64-전환-시-영향)에 분리해 두었습니다.

### 1.2 파생 localparam

| localparam | 계산 | 본 구성 값 | 쓰이는 곳 |
|---|---|:--:|---|
| `BYTES_PER_BEAT_WIDTH_SRC/DEST/SG` | `log2(64/8)` | **3** | 주소 레지스터 쓰기 가능 비트 `[31:3]` |
| `DMA_LENGTH_ALIGN` | SRC·DEST 모두 MM → `max(0,0)` | **0** | `X_LENGTH` 쓰기 가능 비트 `[23:0]` |
| `REAL_MAX_BYTES_PER_BURST` | `min(128, 256×64/8)` | **128** | burst 분할 |
| `BYTES_PER_BURST_WIDTH` | `log2(128)` | **7** | `INTERFACE_DESCRIPTION_1[19:16]` |
| `ID_WIDTH` | `FIFO_SIZE > 4 ? 4` | **4** | `DBG_IDS0/1` 필드 |
| `DBG_ID_PADDING` | `8 − ID_WIDTH` | **4** | `DBG_IDS0/1` 상위 패딩 |
| **`HAS_ADDR_HIGH`** | `DMA_AXI_ADDR_WIDTH > 32` | **0** | `*_HIGH` 레지스터 **비활성** |
| `ADDR_LOW_MSB` | `HAS_ADDR_HIGH ? 31 : ADDR_WIDTH-1` | **31** | 주소 레지스터 폭 |
| `HAS_SRC_ADDR` / `HAS_DEST_ADDR` | `DMA_TYPE_* == 0` | **1 / 1** | 주소 레지스터 읽기값 게이트 |
| `MEASURED_LENGTH_WIDTH` | `DMA_2D_TRANSFER ? 32 : DMA_LENGTH_WIDTH` | **24** | `TRANSFER_PROGRESS` 폭 |
| `MAX_NUM_FRAMES` | `2**3` | **8** | `INTERFACE_DESCRIPTION_1[31:27]` = 7 |
| `PCORE_VERSION` | 상수 | **`0x0004_0565`** | `VERSION` |

> **`DMA_LENGTH_ALIGN = 0`은 본 구성의 고유 특성입니다.** SRC와 DEST가 **둘 다 AXI-MM**일 때만 0이 되며, ADI 공식 testbench(`testbenches/ip/dma_sg`)는 양쪽 모두 한쪽이 AXI-Stream이라 이 경로를 검증하지 않습니다. `X_LENGTH` 바이트 단위 지정([§4.4.6](#446-x_length-0x418))과 `burst_memory.v` 0-replication 패치가 모두 여기에서 나옵니다.

---

## 2. 레지스터 인터페이스 공통 사양

### 2.1 버스와 주소 체계

| 항목 | 사양 | 근거 |
|---|---|:--:|
| 버스 | AXI4-Lite slave (`s_axi_*`), 32비트 데이터 | R |
| 주소 폭 | 11비트 → **2 KiB (0x000–0x7FF)** | R |
| 내부 주소 | **word 주소** `up_waddr/up_raddr = s_axi_*addr[10:2]` (9비트) | R |
| 바이트 주소 환산 | `byte_offset = word_addr × 4` | R |
| 클록 / 리셋 | `s_axi_aclk` / `s_axi_aresetn` (active-low, 동기) | R |
| **`WSTRB`** | **무시.** 모든 쓰기는 32비트 전체 쓰기 | R |
| `BRESP` / `RRESP` | **항상 `OKAY`(2'b00)** — 미정의 주소도 에러 없음 | R |
| **미정의 주소 읽기** | **`0x0000_0000`** | **M** |
| 미정의 주소 쓰기 | 무시 (부작용 없음) | R |
| `AxPROT` | 무시 | R |

```
바이트 주소 = 워드 주소 × 4
  9'h000 → 0x000      9'h100 → 0x400      9'h11F → 0x47C
```

> **주의 — 부분 쓰기 금지.** `WSTRB`가 무시되므로 byte/halfword 쓰기를 하면 나머지 바이트가 버스에 실린 값으로 덮어써집니다. 드라이버는 **항상 32비트 단위**로 접근해야 합니다.

> **주의 — 에러 응답 부재.** 잘못된 주소 접근이 `SLVERR`로 드러나지 않습니다. 검증에서 주소 디코드 오류를 잡으려면 **readback 값 비교가 유일한 수단**입니다. Sanity `SAN-007`의 미매핑 주소 체크가 이 역할을 합니다.

본 문서의 "Offset"은 **바이트 주소**, "Word"는 RTL `case` 문의 **9비트 word 주소**입니다.

### 2.2 접근 유형

| 표기 | 의미 |
|---|---|
| **RO** | 읽기 전용. 쓰기 무시 |
| **RW** | 읽기/쓰기. 쓴 값이 그대로 읽힘 (필드 설명의 마스크 조건 적용) |
| **RW1C** | 1을 쓰면 해당 비트의 **원천 상태**가 지워짐. 0 쓰기는 무효 |
| **RW1S-SC** | 1을 쓰면 세트, 하드웨어가 조건 충족 시 자동으로 0 복귀. 0 쓰기는 무효 |
| **RO-C** | 읽기 전용 상수 (파라미터로 고정) |
| **RO-RS** | 읽기 전용이나 **읽기에 부작용이 있음** (FIFO pop 등) |
| **—** | 미구현. 쓰기 무시, 읽기 0 |

### 2.3 리셋 체계

레지스터는 두 종류의 "지움" 조건을 가집니다. **이 구분을 놓치면 검증 기대값이 틀립니다.**

| 조건 | 트리거 | 지워지는 대상 |
|---|---|---|
| **HW 리셋** | `s_axi_aresetn = 0` | 모든 RW 설정 레지스터 (`SCRATCH`, `IRQ_MASK`, `IRQ_SOURCE`, `CONTROL`, `FLAGS`, 주소, 길이, `SG_ADDRESS`) |
| **채널 비활성** | `CONTROL.ENABLE = 0` | 전송 추적 상태 (`TRANSFER_ID`, `ACTIVE_TRANSFER_ID`, `TRANSFER_DONE`, `TRANSFER_SUBMIT`, `TRANSFER_PROGRESS`, partial FIFO) + DMA 데이터 경로 전체 |

`ENABLE=0`은 **설정 레지스터를 지우지 않고**, `IRQ_SOURCE`도 지우지 않습니다. 상세는 [§8](#8-리셋--enable--pause-영향-매트릭스).

### 2.4 레지스터 상태 분류

| 분류 | 의미 |
|---|---|
| **Active** | 본 구성에서 기능함 |
| **Active (HWDESC=0)** | 레지스터 모드에서만 의미. SG 모드에서는 값이 무시됨 |
| **Active (HWDESC=1)** | SG 모드 전용 |
| **Const** | 파라미터 상수를 읽기만 함 |
| **Debug** | 기능에 영향 없는 관측용 |
| **Unreachable** | 레지스터는 동작하나 본 구성에서 값을 바꾸는 사건이 없음 |
| **Inactive** | 파라미터로 비활성. 쓰기 무시, 읽기 0 |

### 2.5 근거 등급

**본 통합본에서 신설한 표기입니다.** 각 값이 어디까지 확인된 것인지 구분합니다.

| 등급 | 의미 | 신뢰도 |
|:--:|---|---|
| **M** | **실측 확인** — Sanity Test(2026-10-01/02, 46 checks)로 readback 비교 완료 | 가장 높음 |
| **R** | **RTL 분석** — 소스 코드에서 직접 도출. 시뮬레이션 미확인 | 높음 |
| **D** | **upstream 문서 인용** — RTL과 어긋나는 사례가 있어 참고용 | 낮음 |

> **왜 이 구분이 필요한가.** 통합 전 두 문서는 `INTERFACE_DESCRIPTION_2`의 리셋값을 서로 다르게 적고 있었습니다. 양쪽 다 **RTL을 읽어서 계산**했으나, `axi_dmac_regmap.v`의 로컬 기본값(`4'b0011`)을 본 것이지 `axi_dmac`이 실제로 넘기는 값을 본 것이 아니었습니다. 실측값은 `0x0000_0000`입니다. 정적 분석만으로는 이런 종류의 오류를 잡을 수 없으므로, **어떤 값이 아직 검증되지 않았는지 문서가 스스로 드러내야 합니다.**

---

## 3. 레지스터 맵 요약

| Offset | Word | 이름 | 접근 | 리셋값 | 근거 | 본 구성 | 상세 |
|---|---|---|:--:|---|:--:|---|:--:|
| `0x000` | `0x000` | `VERSION` | RO-C | `0x0004_0565` | **M** | Const | [4.1.1](#411-version-0x000) |
| `0x004` | `0x001` | `PERIPHERAL_ID` | RO-C | `0x0000_0000` | **M** | Const | [4.1.2](#412-peripheral_id-0x004) |
| `0x008` | `0x002` | `SCRATCH` | RW | `0x0000_0000` | **M** | Active | [4.1.3](#413-scratch-0x008) |
| `0x00C` | `0x003` | `IDENTIFICATION` | RO-C | `0x444D_4143` | **M** | Const | [4.1.4](#414-identification-0x00c) |
| `0x010` | `0x004` | `INTERFACE_DESCRIPTION_1` | RO-C | `0x3807_0303` | **M** | Const | [4.1.5](#415-interface_description_1-0x010) |
| `0x014` | `0x005` | `INTERFACE_DESCRIPTION_2` | RO-C | **`0x0000_0000`** | **M** | Const | [4.1.6](#416-interface_description_2-0x014) |
| `0x080` | `0x020` | `IRQ_MASK` | RW | `0x0000_0003` | **M** | Active | [4.2.1](#421-irq_mask-0x080) |
| `0x084` | `0x021` | `IRQ_PENDING` | RW1C | `0x0000_0000` | **M** | Active | [4.2.2](#422-irq_pending-0x084) |
| `0x088` | `0x022` | `IRQ_SOURCE` | RO | `0x0000_0000` | **M** | Active | [4.2.3](#423-irq_source-0x088) |
| `0x400` | `0x100` | `CONTROL` | RW | `0x0000_0000` | **M** | Active | [4.3.1](#431-control-0x400) |
| `0x404` | `0x101` | `TRANSFER_ID` | RO | `0x0000_0000` | **M** | Active | [4.4.1](#441-transfer_id-0x404) |
| `0x408` | `0x102` | `TRANSFER_SUBMIT` | RW1S-SC | `0x0000_0000` | R | Active | [4.4.2](#442-transfer_submit-0x408) |
| `0x40C` | `0x103` | `FLAGS` | RW | **`0x0000_0002`** | **M** | Active (일부) | [4.4.3](#443-flags-0x40c) |
| `0x410` | `0x104` | `DEST_ADDRESS` | RW | `0x0000_0000` | **M** | Active (HWDESC=0) | [4.4.4](#444-dest_address-0x410) |
| `0x414` | `0x105` | `SRC_ADDRESS` | RW | `0x0000_0000` | **M** | Active (HWDESC=0) | [4.4.5](#445-src_address-0x414) |
| `0x418` | `0x106` | `X_LENGTH` | RW | `0x0000_0000` | R | Active (HWDESC=0) | [4.4.6](#446-x_length-0x418) |
| `0x41C` | `0x107` | `Y_LENGTH` | — | `0x0000_0000` | **M** | Inactive | [4.8](#48-본-구성에서-비활성인-레지스터) |
| `0x420` | `0x108` | `DEST_STRIDE` | — | `0x0000_0000` | R | Inactive | [4.8](#48-본-구성에서-비활성인-레지스터) |
| `0x424` | `0x109` | `SRC_STRIDE` | — | `0x0000_0000` | R | Inactive | [4.8](#48-본-구성에서-비활성인-레지스터) |
| `0x428` | `0x10A` | `TRANSFER_DONE` | RO | `0x0000_0000` | **M** | Active | [4.5.1](#451-transfer_done-0x428) |
| `0x42C` | `0x10B` | `ACTIVE_TRANSFER_ID` | RO | `0x0000_0000` | R | Active | [4.5.2](#452-active_transfer_id-0x42c) |
| `0x430` | `0x10C` | `STATUS` | RO | `0x0000_0000` | R | 예약 (항상 0) | [4.5.3](#453-status-0x430) |
| `0x434` | `0x10D` | `CURRENT_DEST_ADDRESS` | RO | 가변 ¹ | R | Debug | [4.7.1](#471-current_dest_address-0x434) |
| `0x438` | `0x10E` | `CURRENT_SRC_ADDRESS` | RO | 가변 ¹ | R | Debug | [4.7.2](#472-current_src_address-0x438) |
| `0x43C` | `0x10F` | `DBG_STATUS` | RO | 가변 ² | R | Debug | [4.7.3](#473-dbg_status-0x43c) |
| `0x440` | `0x110` | `DBG_IDS0` | RO | `0x0000_0000` | R | Debug (Gray) | [4.7.4](#474-dbg_ids0-0x440--dbg_ids1-0x444) |
| `0x444` | `0x111` | `DBG_IDS1` | RO | `0x0000_0000` | R | Debug (Gray) | [4.7.4](#474-dbg_ids0-0x440--dbg_ids1-0x444) |
| `0x448` | `0x112` | `TRANSFER_PROGRESS` | RO | `0x0000_0000` | R | Active | [4.5.4](#454-transfer_progress-0x448) |
| `0x44C` | `0x113` | `PARTIAL_TRANSFER_LENGTH` | RO | `0x0000_0000` | R | **Unreachable** | [4.5.5](#455-partial_transfer_length-0x44c--partial_transfer_id-0x450) |
| `0x450` | `0x114` | `PARTIAL_TRANSFER_ID` | **RO-RS** | `0x0000_0000` | R | **Unreachable** | [4.5.5](#455-partial_transfer_length-0x44c--partial_transfer_id-0x450) |
| `0x454` | `0x115` | `DESCRIPTOR_ID` | RO | `0x0000_0000` | **M** | Active (HWDESC=1) | [4.6.2](#462-descriptor_id-0x454) |
| `0x458` | `0x116` | `FRAMELOCK_CONFIG` | — | `0x0000_0000` | **M** | Inactive | [4.8](#48-본-구성에서-비활성인-레지스터) |
| `0x45C` | `0x117` | `FRAMELOCK_STRIDE` | — | `0x0000_0000` | R | Inactive | [4.8](#48-본-구성에서-비활성인-레지스터) |
| `0x47C` | `0x11F` | `SG_ADDRESS` | RW | `0x0000_0000` | **M** | Active (HWDESC=1) | [4.6.1](#461-sg_address-0x47c) |
| `0x490` | `0x124` | `DEST_ADDRESS_HIGH` | **—** | `0x0000_0000` | **M** | **Inactive** | [§10](#10-addr_width--64-전환-시-영향) |
| `0x494` | `0x125` | `SRC_ADDRESS_HIGH` | **—** | `0x0000_0000` | **M** | **Inactive** | [§10](#10-addr_width--64-전환-시-영향) |
| `0x498` | `0x126` | `CURRENT_DEST_ADDRESS_HIGH` | RO | `0x0000_0000` | R | **Inactive** | [§10](#10-addr_width--64-전환-시-영향) |
| `0x49C` | `0x127` | `CURRENT_SRC_ADDRESS_HIGH` | RO | `0x0000_0000` | R | **Inactive** | [§10](#10-addr_width--64-전환-시-영향) |
| `0x4BC` | `0x12F` | `SG_ADDRESS_HIGH` | **—** | `0x0000_0000` | **M** | **Inactive** | [§10](#10-addr_width--64-전환-시-영향) |
| 그 외 | — | (미정의) | — | `0x0000_0000` | **M** | — | [§2.1](#21-버스와-주소-체계) |

¹ AXI master 포트의 주소 출력을 그대로 읽으므로 리셋 직후 값은 address generator 상태에 따릅니다. **리셋값 비교 대상에서 제외**를 권장합니다.
² reset manager 상태 머신 값이 그대로 보이므로 고정 리셋값이 없습니다. [4.7.3](#473-dbg_status-0x43c) 참조.

> **rev.001과의 차이 — HIGH 레지스터군.** rev.001은 `ADDR_WIDTH=64` 가정으로 `DEST/SRC/SG_ADDRESS_HIGH`를 **RW / Active**로 분류했습니다. 본 구성(`=32`)에서는 `if (HAS_ADDR_HIGH)` 가드로 **쓰기 로직 자체가 합성되지 않아** Inactive입니다. Sanity `SAN-007`이 `0xFFFF_FFFF` 기입 후 `0x0000_0000` 읽힘을 실측했습니다.

---

## 4. 레지스터 상세

각 레지스터는 **비트 필드 → 동작 → RTL 근거 → 본 구성 참고 → 검증 포인트** 순서입니다.

### 4.1 식별 · 구성 정보 (0x000–0x014)

#### 4.1.1 `VERSION` (0x000)

| Bits | Field | 접근 | 값 | 설명 |
|---|---|:--:|---|---|
| `[31:16]` | `VERSION_MAJOR` | RO-C | `0x0004` | 주 버전 4 |
| `[15:8]` | `VERSION_MINOR` | RO-C | `0x05` | 부 버전 5 |
| `[7:0]` | `VERSION_PATCH` | RO-C | `0x65` | 패치 |

- **RTL 근거**: `axi_dmac_regmap.v:150` `localparam PCORE_VERSION = 'h00040565`, `:248`.
- **실측 (M)**: `0x0004_0565` — `SAN-001` check 1.
- **검증 포인트**: Sanity의 첫 readback. **이 값이 틀리면 버스나 레지스터 디코딩이 깨진 것**이므로 이후 테스트를 진행할 의미가 없습니다. TB가 이 체크 실패 시 나머지를 SKIP 처리합니다.

#### 4.1.2 `PERIPHERAL_ID` (0x004)

| Bits | Field | 접근 | 값 | 설명 |
|---|---|:--:|---|---|
| `[31:0]` | `PERIPHERAL_ID` | RO-C | `ID` 파라미터 | 동일 IP 다중 인스턴스 식별용 |

- **RTL 근거**: `axi_dmac_regmap.v:249`.
- **실측 (M)**: `0x0000_0000` — `sg_dma_top`이 `ID = 0`으로 명시.
- **SoC 통합 시**: 여러 SGDMA를 붙이면 인스턴스별로 다른 `ID`를 주고, 이 레지스터로 구분합니다.

#### 4.1.3 `SCRATCH` (0x008)

| Bits | Field | 접근 | 리셋 | 설명 |
|---|---|:--:|---|---|
| `[31:0]` | `SCRATCH` | RW | `0x0000_0000` | 기능 없음. 버스 연결 확인용 |

- **RTL 근거**: `axi_dmac_regmap.v:169`(선언), `:213`(리셋), `:220-222`(쓰기), `:250`(읽기).
- **실측 (M)**: `0xA5A5_5A5A` / `0x5A5A_A5A5` / `0x0000_0000` 3회 write-readback 일치 — `SAN-002`.
- **검증 포인트**: **패턴을 반전해 두 번 쓰는 것**이 중요합니다. 한 패턴만 쓰면 일부 비트가 고착(stuck-at)되어 있어도 통과합니다. `WSTRB`가 무시되므로 byte-strobe 테스트는 "무시됨"을 기대값으로 둡니다.

#### 4.1.4 `IDENTIFICATION` (0x00C)

| Bits | Field | 접근 | 값 | 설명 |
|---|---|:--:|---|---|
| `[31:0]` | `IDENTIFICATION` | RO-C | `0x444D_4143` | ASCII `"DMAC"` |

- **RTL 근거**: `axi_dmac_regmap.v:251`.
- **실측 (M)**: `0x444D_4143` — `SAN-001` check 2. `VERSION`과 함께 버스 생존 판정 기준입니다.

#### 4.1.5 `INTERFACE_DESCRIPTION_1` (0x010)

합성 파라미터를 소프트웨어가 확인할 수 있도록 패킹한 상수 레지스터입니다.

```
 31    27 26 25 24 23  20 19  16 15 14 13 12 11   8 7  6 5  4 3    0
+--------+--+--+--+------+------+-----+-----+------+----+-----+------+
|MAX_NUM_|2D|EX|AR| rsvd |BPBRST|rsvd |TYPE | BPB  |rsvd|TYPE | BPB  |
|FRAMES-1|TL|SY|UN|      |_WIDTH|     | SRC | SRC  |    |DEST | DEST |
+--------+--+--+--+------+------+-----+-----+------+----+-----+------+
    7     0  0  0    0      7      0     0     3     0     0     3     → 0x3807_0303
```

| Bits | Field | 접근 | 본 구성 값 | 설명 |
|---|---|:--:|:--:|---|
| `[31:27]` | `MAX_NUM_FRAMES` | RO-C | `7` | `2**MAX_NUM_FRAMES_WIDTH − 1`. FRAMELOCK=0이어도 파라미터 값이 그대로 보임 |
| `[26]` | `DMA_2D_TLAST_MODE` | RO-C | `0` | 2D TLAST 모드 |
| `[25]` | `USE_EXT_SYNC` | RO-C | `0` | 외부 sync 사용 여부 |
| `[24]` | `HAS_AUTORUN` | RO-C | `0` | AUTORUN 파라미터 |
| `[23:20]` | — | RO | `0` | 예약 |
| `[19:16]` | `BYTES_PER_BURST_WIDTH` | RO-C | `7` | `log2(128)` |
| `[15:14]` | — | RO | `0` | 예약 |
| `[13:12]` | `DMA_TYPE_SRC` | RO-C | `0` | 0 = AXI-MM, 1 = AXI-Stream, 2 = FIFO |
| `[11:8]` | `BYTES_PER_BEAT_SRC_LOG2` | RO-C | `3` | `log2(64/8)` |
| `[7:6]` | — | RO | `0` | 예약 |
| `[5:4]` | `DMA_TYPE_DEST` | RO-C | `0` | 0 = AXI-MM |
| `[3:0]` | `BYTES_PER_BEAT_DEST_LOG2` | RO-C | `3` | `log2(64/8)` |

- **RTL 근거**: `axi_dmac_regmap.v:252-255`.
- **실측 (M)**: **`0x3807_0303`** — 계산값과 일치. `SAN-001` check 4.
- **본 구성 참고**: **레지스터 한 번 읽기로 빌드 파라미터 전체를 확인**할 수 있는 지점입니다. `DMA_TYPE_SRC/DEST`, `BYTES_PER_BEAT`, `MAX_BYTES_PER_BURST`, `MAX_NUM_FRAMES`가 모두 인코딩되어 있어, 이 값이 맞으면 "의도한 구성으로 합성됐다"가 증명됩니다.
- **RTL 해석 주의**: `[31:27]` 식은 `MAX_NUM_FRAMES[4:0]-1`로, 크기 없는 상수 `1` 때문에 self-determined 폭이 32비트가 됩니다. 결과적으로 `[31:27]`에는 하위 5비트(=7)가 정상적으로 남지만 **린트 경고가 날 수 있습니다.**

#### 4.1.6 `INTERFACE_DESCRIPTION_2` (0x014)

> ⚠ **통합 과정에서 정정된 항목입니다.** 두 원본 문서 모두 `0x0000_0030`으로 적었으나, **실측값은 `0x0000_0000`** 입니다.

| Bits | Field | 접근 | **실측값** | 설명 |
|---|---|:--:|:--:|---|
| `[31:11]` | — | RO | `0` | 예약 |
| `[10:8]` | `AXI_AXPROT` | RO-C | **`3'b000`** | 모든 master 포트의 `AxPROT` 출력값 |
| `[7:4]` | `AXI_AXCACHE` | RO-C | **`4'b0000`** | 모든 master 포트의 `AxCACHE` 출력값 |
| `[3:1]` | — | RO | `0` | 예약 |
| `[0]` | `CACHE_COHERENT` | RO-C | `0` | 캐시 일관성 모드 |

- **RTL 근거**: `axi_dmac_regmap.v:256-259`.
- **실측 (M)**: **`0x0000_0000`** — `SAN-001` check 5 (2026-10-01).
- **오류의 원인**: `axi_dmac_regmap.v`는 `parameter [3:0] AXI_AXCACHE = 4'b0011`을 **자체 기본값**으로 갖습니다. 두 문서 모두 이 선언을 보고 `0x30`을 계산했으나, 실제로는 상위 모듈 `axi_dmac`이 넘기는 값이 적용됩니다. `sg_dma_top.v`가 이 파라미터를 지정하지 않으므로 `axi_dmac`의 기본값이 쓰이고, 그 결과가 `4'b0000`입니다.
- **⚠ 설계 확인 필요**: `AXCACHE = 4'b0000`은 **Device Non-bufferable**입니다. MM→MM DMA에서는 통상 `4'b0011`(Normal Non-cacheable Bufferable)을 씁니다. 실제 버스에 나가는 값이므로 **SoC 통합 시 성능에 영향**이 있습니다. `sg_dma_top.v`에서 `AXI_AXCACHE`를 명시할지 결정이 필요합니다 → [§11](#11-미확정-항목).
- **검증 포인트**: `m_src_axi_arcache` / `m_dest_axi_awcache` / `m_sg_axi_arcache`가 이 필드와 같은지 AXI 모니터로 교차 확인 가능합니다.

---

### 4.2 인터럽트 (0x080–0x088)

세 레지스터가 하나의 구조를 이룹니다.

```
이벤트 → IRQ_SOURCE(래치) → IRQ_MASK로 게이트 → IRQ_PENDING → irq 출력
```

| Bit | 이벤트 | 내부 신호 | 발생 조건 |
|:--:|---|---|---|
| `[0]` | `TRANSFER_QUEUED` | `up_sot` | 전송 요청이 DMA 코어에 수락됨 |
| `[1]` | `TRANSFER_COMPLETED` | `up_eot` | 전송(또는 EOT 플래그 descriptor)이 완료됨 |

#### 4.2.1 `IRQ_MASK` (0x080)

| Bits | Field | 접근 | 리셋 | 설명 |
|---|---|:--:|:--:|---|
| `[31:2]` | — | RO | `0` | 예약 |
| `[1]` | `TRANSFER_COMPLETED` | RW | **`1`** | 1 = 마스크(차단), 0 = 허용 |
| `[0]` | `TRANSFER_QUEUED` | RW | **`1`** | 1 = 마스크, 0 = 허용 |

- **RTL 근거**: `axi_dmac_regmap.v:176` `reg [1:0] up_irq_mask = 2'h3`, `:212`(리셋), `:223-225`(쓰기), `:260`(읽기).
- **실측 (M)**: 리셋값 `0x0000_0003` — `SAN-003` check 2.
- **본 구성 참고**: **리셋 시 두 인터럽트 모두 마스크**되어 있습니다. 드라이버가 명시적으로 unmask해야 `irq`가 올라옵니다.
- **검증 포인트**
  - 마스크는 `IRQ_SOURCE` 래치를 **막지 않습니다.** 마스크 상태에서도 이벤트는 쌓이고, **unmask하는 순간 `irq`가 즉시 올라갑니다**(과거 이벤트가 튀어나옴). unmask 전에 `IRQ_PENDING`에 `0x3`을 써서 비우는 순서를 드라이버·테스트 모두 지켜야 합니다.
  - unmask 케이스를 최소 1회 포함해야 IRQ 경로가 검증됩니다. Sanity `SAN-006`이 `IRQ_MASK = 0x1`로 EOT만 unmask하여 이를 수행합니다.

#### 4.2.2 `IRQ_PENDING` (0x084)

| Bits | Field | 접근 | 리셋 | 설명 |
|---|---|:--:|:--:|---|
| `[31:2]` | — | RO | `0` | 예약 |
| `[1]` | `TRANSFER_COMPLETED` | RW1C | `0` | 읽기: `SOURCE[1] & ~MASK[1]`. 1 쓰기: **`IRQ_SOURCE[1]`** 지움 |
| `[0]` | `TRANSFER_QUEUED` | RW1C | `0` | 읽기: `SOURCE[0] & ~MASK[0]`. 1 쓰기: **`IRQ_SOURCE[0]`** 지움 |

```verilog
assign up_irq_pending      = ~up_irq_mask & up_irq_source;              // :184
assign up_irq_source_clear = (up_wreq && up_waddr == 9'h021) ? up_wdata[1:0] : 2'b00;  // :186
up_irq_source <= up_irq_trigger | (up_irq_source & ~up_irq_source_clear);              // :200
```

- **실측 (M)**: 리셋값 `0x0`(`SAN-003`), 전송 후 `[1]` 세트 → W1C → `0x0` 복귀(`SAN-006`).
- **동작 상세**
  - `IRQ_PENDING`은 **독립 저장소가 아닙니다.** `IRQ_SOURCE`와 `IRQ_MASK`의 조합 결과입니다.
  - 1 쓰기는 **마스크 여부와 무관하게** `IRQ_SOURCE`를 지웁니다. 마스크된 이벤트도 이 레지스터로 지울 수 있습니다.
  - 같은 사이클에 새 이벤트와 clear가 겹치면 **이벤트가 이깁니다** — 이벤트를 잃지 않는 설계입니다.

> **이름과 실제가 어긋나는 지점입니다.** "PENDING에 쓴다"고 생각하지만 **지워지는 것은 SOURCE**입니다. 검증 시나리오를 쓸 때 반드시 구분해야 합니다.

#### 4.2.3 `IRQ_SOURCE` (0x088)

| Bits | Field | 접근 | 리셋 | 설명 |
|---|---|:--:|:--:|---|
| `[31:2]` | — | RO | `0` | 예약 |
| `[1]` | `TRANSFER_COMPLETED` | RO | `0` | `up_eot` 발생 시 래치. `IRQ_PENDING[1]`에 1을 써야 지워짐 |
| `[0]` | `TRANSFER_QUEUED` | RO | `0` | `up_sot` 발생 시 래치. `IRQ_PENDING[0]`에 1을 써야 지워짐 |

- **RTL 근거**: `axi_dmac_regmap.v:196-202`, `:262`.
- **실측 (M)**: 리셋값 `0x0`(`SAN-003`). **전송 후 W1C로 `[1]`만 지우면 `[0]`은 `0x1`로 남음** — `SAN-006` check 4. 마스크된 SOT 이벤트가 SOURCE에는 기록된다는 직접 증거입니다.
- **본 구성 참고**: `s_axi_aresetn`으로만 지워집니다. **`CONTROL.ENABLE=0`으로는 지워지지 않습니다.**
- **검증 포인트**: 마스크와 무관하게 기록되므로, 인터럽트를 쓰지 않는 polling 테스트에서도 이 레지스터로 SOT/EOT 발생을 확인할 수 있습니다.

---

### 4.3 채널 제어 (0x400)

#### 4.3.1 `CONTROL` (0x400)

| Bits | Field | 접근 | 리셋 | 본 구성 동작 |
|---|---|:--:|:--:|---|
| `[31:4]` | — | RO | `0` | 예약 |
| `[3]` | `FRAMELOCK` | **RO** | `0` | 쓰기값 `& FRAMELOCK(=0)` → **항상 0** |
| `[2]` | `HWDESC` | RW | `0` | 1 = Scatter-Gather 모드. 쓰기값 `& DMA_SG_TRANSFER(=1)` |
| `[1]` | `PAUSE` | RW | `0` | 1 = 일시정지(상태 보존) |
| `[0]` | `ENABLE` | RW | `0` | 1 = 채널 활성, 0 = 비활성 + 내부 상태 초기화 |

```verilog
ctrl_flock  <= up_wdata[3] & FRAMELOCK;        // = 0
ctrl_hwdesc <= up_wdata[2] & DMA_SG_TRANSFER;  // 반영됨
ctrl_pause  <= up_wdata[1];
ctrl_enable <= up_wdata[0];                    // :226-231
```

- **실측 (M)**: 리셋값 `0x0`(`SAN-003`). **`0xFFFF_FFFF` 기입 → `0x0000_0007` 읽힘**(`SAN-007`) — `[3]` 마스킹 확인.
- **동작 상세**
  - **`ENABLE`** 1→0 전이(단 1사이클이라도)는 reset manager의 `needs_reset`을 세웁니다. 진행 중인 AXI 트랜잭션을 프로토콜상 완료한 뒤 모든 도메인에 리셋 펄스를 넣습니다. 동시에 regmap의 전송 추적 상태가 즉시 지워집니다 ([§8](#8-리셋--enable--pause-영향-매트릭스)).
  - **`PAUSE`** = 1이면 `ENABLED → SHUTDOWN → DISABLED`로 가지만 **리셋 펄스는 내지 않습니다.** 0으로 되돌리면 `STARTUP`을 거쳐 이전 상태에서 재개합니다.
  - **`HWDESC`** 는 전송 요청의 출처를 고릅니다. 0이면 레지스터, 1이면 `SG_ADDRESS`가 가리키는 descriptor 체인입니다.
- **본 구성 참고 — HWDESC 리셋값은 0입니다.** "SG 모드 상시 사용"은 **소프트웨어 운용 전제**이지 하드웨어 리셋값이 아닙니다. SG 모드를 쓰려면 드라이버가 `CONTROL`에 **`0x5`(ENABLE | HWDESC)** 를 써야 합니다.
- **프로그래밍 규칙**
  - 네 비트가 **한 번의 쓰기로 동시에** 갱신됩니다. `PAUSE`만 바꿀 때도 `HWDESC`/`ENABLE`을 함께 실어야 합니다(read-modify-write).
  - `HWDESC`는 **`ENABLE`과 같은 쓰기로** 설정하고, 전송 중에는 바꾸지 않습니다. 전송 도중 바꾸면 요청·응답 경로 mux가 즉시 전환되어 **진행 중인 전송의 응답 매칭이 깨질 수 있습니다.** RTL에 이를 막는 보호 로직은 없습니다.
- **검증 포인트**
  - `FRAMELOCK` 비트에 1을 써도 0으로 읽히는지 (`SAN-007` — **실측 완료**).
  - `ENABLE` 0→1→0 토글 후 [§8](#8-리셋--enable--pause-영향-매트릭스)의 지워짐 대상이 모두 0인지 (**미측정** — FT 대상).

---

### 4.4 전송 요청 (0x404–0x424)

#### 4.4.1 `TRANSFER_ID` (0x404)

| Bits | Field | 접근 | 리셋 | 설명 |
|---|---|:--:|:--:|---|
| `[31:2]` | — | RO | `0` | 예약 |
| `[1:0]` | `TRANSFER_ID` | RO | `0` | **다음에 제출될** 전송의 ID (2비트, 0–3 순환) |

- **RTL 근거**: `axi_dmac_regmap_request.v:133`, `:364-373`, `:210`.
- **실측 (M)**: 리셋값 `0x0` — `SAN-003` check 7.
- **동작 상세**: `up_sot`마다 +1 (binary, mod 4). 제출 시점에 `TRANSFER_DONE`의 해당 비트를 0으로 내립니다. `ENABLE=0`이면 0으로 초기화.
- **본 구성 참고**: 이 ID는 **소프트웨어용 2비트 binary 카운터**이며, 내부 Gray-ID(4비트)와는 **무관**합니다. SG 모드에서는 **체인 1개 제출 = ID 1개**입니다.

#### 4.4.2 `TRANSFER_SUBMIT` (0x408)

| Bits | Field | 접근 | 리셋 | 설명 |
|---|---|:--:|:--:|---|
| `[31:1]` | — | RO | `0` | 예약 |
| `[0]` | `TRANSFER_SUBMIT` | **RW1S-SC** | `0` | 1 쓰기 = 전송 요청 발행. 코어가 수락하면(`up_sot`) 0으로 복귀 |

```verilog
if (ctrl_enable == 1'b1) begin
  if (up_wreq && up_waddr == 9'h102) up_dma_req_valid <= up_dma_req_valid | up_wdata[0];
  else if (up_sot) up_dma_req_valid <= 1'b0;
end else begin
  up_dma_req_valid <= 1'b0;      // ← ENABLE=0이면 SUBMIT 무시
end                               // :175-183
```

- **동작 상세**
  - **`ENABLE=1`일 때만 쓰기가 반영됩니다.** `ENABLE=0`에서의 쓰기는 무시되고 비트도 0으로 유지됩니다. **조용히 실패**하므로 순서가 중요합니다.
  - 0 쓰기는 효과가 없습니다(`| up_wdata[0]`). **이미 1인 상태에서 다시 1을 써도 요청이 하나 더 쌓이지 않습니다.** 두 번째 요청은 사라집니다.
  - 읽기값 1 = "요청이 아직 코어에 수락되지 않음".
- **프로그래밍 규칙**: 쓰기 전에 반드시 이 비트가 **0이 될 때까지 polling** 합니다.
- **SG 모드에서의 수락 시점**: HWDESC=1이면 수락 신호는 SG 주소 FIFO(`dmac_sg.v`, 1단)의 ready입니다. **첫 descriptor 주소가 SG 엔진에 넘어간 시점**에 0으로 돌아오며, 체인 전체가 끝날 때까지 기다리지 않습니다.
- **미측정 (R)**: 현재 Sanity는 `ENABLE=1` 상태에서 1회 쓰기만 합니다. self-clearing 타이밍과 `ENABLE=0` 시 무시 동작은 **FT 대상**입니다.

#### 4.4.3 `FLAGS` (0x40C)

> ⚠ **리셋값이 `0`이 아닙니다.** "리셋 후 전 레지스터 0"을 가정한 테스트는 여기서 FAIL합니다.

| Bits | Field | 접근 | 리셋 | 본 구성 동작 |
|---|---|:--:|:--:|---|
| `[31:3]` | — | RO | `0` | 예약 |
| `[2]` | `PARTIAL_REPORTING_EN` | RW | `0` | 1 = partial 전송 길이 기록 활성 |
| `[1]` | `TLAST` | RW | **`1`** | 전송 마지막 표시(`request_last`) |
| `[0]` | `CYCLIC` | **RO** | `0` | 쓰기값 `& CYCLIC(=0)` → **항상 0** |

```verilog
localparam AUTORUN_FLAGS_LAST = AUTORUN ? AUTORUN_FLAGS[1] : 1;   // ← 1
up_dma_cyclic <= up_wdata[0] & DMA_CYCLIC;                        // ← 상시 0  :188
```

- **실측 (M)**: 리셋값 **`0x0000_0002`**(`SAN-003` check 5). **`0xFFFF_FFFF` 기입 → `0x0000_0006` 읽힘**(`SAN-007`) — `[0]` 마스킹 확인.
- **본 구성 참고**
  - **`CYCLIC`**: 파라미터가 쓰기 경로를 마스크하므로 **레지스터 수준에서 이미 0 고정**입니다. 레지스터 비트 자체를 RTL에서 제거할 실익이 크지 않다고 판단한 근거입니다.
  - **`TLAST`**: HWDESC 모드에서도 descriptor가 아니라 **이 레지스터 값**이 요청에 실립니다. 목적지가 AXI-MM이라 버스에 TLAST가 없으므로 데이터 경로 영향은 없으나, 내부 완료 처리에 쓰이므로 **리셋값 1을 유지**하는 것을 권장합니다.
  - **`PARTIAL_REPORTING_EN`**: partial 전송은 AXI-Stream 소스의 조기 TLAST로만 발생합니다. 소스가 AXI-MM인 본 구성에서는 **1로 설정해도 기록될 사건이 없습니다.**

#### 4.4.4 `DEST_ADDRESS` (0x410)

| Bits | Field | 접근 | 리셋 | 설명 |
|---|---|:--:|:--:|---|
| `[31:3]` | `DEST_ADDRESS[31:3]` | RW | `0` | 목적지 시작 주소 |
| `[2:0]` | — | **RO** | `0` | beat 정렬 비트. 쓰기 무시, 읽기 0 |

- **RTL 근거**: `axi_dmac_regmap_request.v:192`(쓰기), `:213`(읽기 — `{addr[31:3], 3'b000}`).
- **실측 (M)**: 리셋값 `0x0`(`SAN-003`). **`0xFFFF_FFFF` 기입 → `0xFFFF_FFF8` 읽힘**(`SAN-007`).
- **정렬**: 64비트 버스이므로 **8바이트 정렬**이 필요합니다. 비정렬 값을 쓰면 하위 3비트가 **조용히 버려집니다.** upstream은 4 KiB 경계 넘김을 피하기 위해 `MAX_BYTES_PER_BURST`(128 B) 정렬을 권장합니다.
- **본 구성 참고**: **HWDESC=0에서만 사용됩니다.** HWDESC=1이면 descriptor의 `dest_addr`가 쓰이고 이 레지스터 값은 무시됩니다.

#### 4.4.5 `SRC_ADDRESS` (0x414)

구조·동작은 [4.4.4](#444-dest_address-0x410)와 같습니다 (`:193`, `:214`). 실측도 동일합니다.

#### 4.4.6 `X_LENGTH` (0x418)

| Bits | Field | 접근 | 리셋 | 설명 |
|---|---|:--:|:--:|---|
| `[31:24]` | — | RO | `0` | 쓰기 무시 (`DMA_LENGTH_WIDTH=24`) |
| `[23:0]` | `X_LENGTH` | RW | `0` | **전송 바이트 수 − 1** |

```verilog
9'h106: up_dma_x_length[DMA_LENGTH_WIDTH-1:DMA_LENGTH_ALIGN]
          <= up_wdata[DMA_LENGTH_WIDTH-1:DMA_LENGTH_ALIGN];
//                     ↑ DMA_LENGTH_ALIGN = 0 → [23:0] 전부 쓰기 가능   :194
```

- **범위**: 1 B (`0x00_0000`) ~ 16 MiB (`0xFF_FFFF`).
- **본 구성 고유 동작**

| 구성 | `DMA_LENGTH_ALIGN` | 쓰기 가능 비트 | 길이 단위 |
|---|:--:|:--:|---|
| ADI 표준 (Stream 포함) | 3 | `[23:3]` — 하위 3비트 상시 1 | 8 바이트 |
| **본 구성 (MM→MM)** | **0** | **`[23:0]` 전부** | **1 바이트** |

- **리셋값 주의**: upstream 문서는 `2**clog2(버스폭/8)−1`(= 7)로 적지만, 이는 정렬 비트가 있는 구성의 값입니다. **본 구성에서는 0**입니다.
- **미측정 (R)**: Sanity `SAN-003`에 `X_LENGTH` 리셋값 체크가 **없습니다.** 추가를 권장합니다 → [§9.3](#93-sanity-미커버-영역).

> **참고 — 0-replication 이슈와의 관계**
> `axi_dmac_regmap_request.v:140`에도 `{DMA_LENGTH_ALIGN{1'b1}}`이 있으나 **에러가 나지 않습니다.**
> ```verilog
> reg [DMA_LENGTH_WIDTH-1:0] up_dma_x_length = {DMAC_DEF_X_LENGTH_DEFAULT[...], {DMA_LENGTH_ALIGN{1'b1}}};
> //                                            └── 다른 피연산자와 함께 concat 안 → 합법
> ```
> Verilog-2001 LRM은 0-replication을 **다른 피연산자가 있는 concatenation 안에서만** 허용합니다. `axi_dmac_burst_memory.v:163`은 단독으로 쓰여 불법이었고, 그것이 저희 repo의 유일한 RTL 패치 근거입니다.

---

### 4.5 전송 상태 (0x428–0x430, 0x448–0x450)

#### 4.5.1 `TRANSFER_DONE` (0x428)

| Bits | Field | 접근 | 리셋 | 설명 |
|---|---|:--:|:--:|---|
| `[31]` | `PARTIAL_TRANSFER_DONE` | RO | `0` | partial 정보가 FIFO에 남아 있음 (본 구성 Unreachable) |
| `[30:4]` | — | RO | `0` | 예약 |
| `[3:0]` | `TRANSFER_n_DONE` | RO | `0` | 전송 ID별 완료 플래그 |

- **RTL 근거**: `axi_dmac_regmap_request.v:135`, `:364-380`, `:219`.
- **실측 (M)**: 리셋값 `0x0`(`SAN-003`). 전송 완료 후 비트 세트 확인(`SAN-004`).
- **동작 상세**
  - `up_sot` 시 `bit[TRANSFER_ID]` ← 0, `up_eot` 시 `bit[ACTIVE_TRANSFER_ID]` ← 1.
  - **ID를 재사용하기 전까지** 완료 상태를 유지합니다. 4개를 넘게 연속 제출하면 오래된 완료 정보가 덮어써집니다.
  - `ENABLE=0`에서 전부 0.
- **⚠ SG 모드 주의**: 비트를 세우는 `up_eot`는 **EOT 플래그(`flags[1]`)가 설정된 descriptor**가 끝날 때마다 발생합니다. 반면 `TRANSFER_ID`는 **체인당** 1씩 증가합니다. 한 체인에 `flags[1]=1`인 descriptor가 2개 이상이면 **두 카운터가 어긋납니다.** 1:1 대응이 필요하면 **체인의 마지막 descriptor에만 `flags[1]`을 설정**하십시오 ([§6.2](#62-sg-모드hwdesc1에서의-이벤트-의미)).

#### 4.5.2 `ACTIVE_TRANSFER_ID` (0x42C)

| Bits | Field | 접근 | 리셋 | 설명 |
|---|---|:--:|:--:|---|
| `[31:2]` | — | RO | `0` | 예약 |
| `[1:0]` | `ACTIVE_TRANSFER_ID` | RO | `0` | **다음에 완료될** 전송의 ID |

- **RTL 근거**: `axi_dmac_regmap_request.v:134`, `:375-377`, `:220`.
- **폭 주의**: upstream 문서와 TB 패키지는 `[4:0]`으로 적지만 **RTL은 2비트**입니다.
- **미측정 (R)** → [§9.3](#93-sanity-미커버-영역).

#### 4.5.3 `STATUS` (0x430)

| Bits | Field | 접근 | 값 | 설명 |
|---|---|:--:|:--:|---|
| `[31:0]` | `RESERVED` | RO | `0` | 예약. 항상 0 |

- **RTL 근거**: `axi_dmac_regmap_request.v:221` `9'h10c: up_rdata <= 32'h0`.
- 채널 상태는 `DBG_STATUS`(0x43C)를 사용합니다.

#### 4.5.4 `TRANSFER_PROGRESS` (0x448)

| Bits | Field | 접근 | 리셋 | 설명 |
|---|---|:--:|:--:|---|
| `[31:24]` | — | RO | `0` | 예약 |
| `[23:0]` | `TRANSFER_PROGRESS` | RO | `0` | 현재 전송에서 목적지 응답까지 끝난 누적 바이트 수 |

- **RTL 근거**: `axi_dmac_regmap_request.v:153`, `:399-407`, `:222`.
- **동작 상세**
  - 목적지 응답마다 `measured_burst_length + 1`을 더합니다.
  - **EOT가 실린 응답 다음 사이클에 0으로 지워집니다.** 따라서 **완료 직후에 읽으면 대개 0**이고, 전송 **도중**의 진행률 관찰에만 의미가 있습니다.
  - `ENABLE=0`에서 0.
- **⚠ SG 모드 주의**: 지움 조건의 EOT는 `flags[1]=1`인 descriptor에서만 발생합니다. 그러므로 **`flags[1]=0`인 descriptor의 바이트는 지워지지 않고 계속 누적**되어, EOT 플래그 descriptor까지의 **체인 누적 바이트**가 보입니다.

> **이름 주의.** 통합 전 hrcho 문서는 이 레지스터를 `TRANSFER_LENGTH`로 적었으나, **완료 시 0으로 지워지는 동작**을 보면 `TRANSFER_PROGRESS`가 정확합니다. rev.001의 명칭을 채택했습니다.

#### 4.5.5 `PARTIAL_TRANSFER_LENGTH` (0x44C) / `PARTIAL_TRANSFER_ID` (0x450)

| 레지스터 | Bits | 접근 | 설명 |
|---|---|:--:|---|
| `PARTIAL_TRANSFER_LENGTH` | `[23:0]` | RO | partial FIFO head의 바이트 수 |
| `PARTIAL_TRANSFER_ID` | `[1:0]` | **RO-RS** | partial FIFO head의 전송 ID. **읽으면 FIFO가 pop됨** |

```verilog
assign up_tlf_rd = up_rreq && up_raddr == 'h114;   // 0x450 읽기 → pop   :382
```

- **읽기 순서**: 반드시 `LENGTH` → `ID` 순서로 읽습니다. `ID`를 먼저 읽으면 해당 항목의 길이를 잃습니다.
- **본 구성 — Unreachable**: partial 응답은 AXI-Stream 소스가 `X_LENGTH`보다 먼저 TLAST를 낼 때만 생깁니다. 소스가 AXI-MM이라 `response_partial`이 항상 0이므로 FIFO에 아무것도 들어가지 않습니다. 두 레지스터는 항상 0이고 `TRANSFER_DONE[31]`도 0입니다.
- **⚠ 검증 시 주의**: **"전 레지스터 덤프" 방식의 테스트는 `0x450`에서 내부 상태를 파괴합니다.** 본 구성에서는 FIFO가 비어 있어 실제 영향이 없지만, **레지스터 순회 테스트에서는 제외**하는 것을 원칙으로 둡니다. Sanity `SAN-007`은 이 주소를 읽지 않습니다.

---

### 4.6 Scatter-Gather (0x454, 0x47C)

#### 4.6.1 `SG_ADDRESS` (0x47C)

| Bits | Field | 접근 | 리셋 | 설명 |
|---|---|:--:|:--:|---|
| `[31:3]` | `SG_ADDRESS[31:3]` | RW | `0` | **첫 descriptor 주소** |
| `[2:0]` | — | RO | `0` | 쓰기 무시, 읽기 0 |

- **RTL 근거**: `axi_dmac_regmap_request.v:333-354`(generate, `DMA_SG_TRANSFER=1`일 때만 존재), `:234`.
- **실측 (M)**: 리셋값 `0x0`(`SAN-003`). `0xFFFF_FFFF` 기입 → `0xFFFF_FFF8`(`SAN-007`).
- **정렬**: SG 인터페이스가 64비트이므로 **8바이트 정렬 필수**입니다. descriptor 하나는 48 B를 **6-beat burst 한 번**으로 읽으므로, **4 KiB 경계를 넘지 않도록 64바이트 정렬을 권장**합니다.
- **사용 범위**: 체인의 **첫 descriptor만** 이 레지스터로 지정합니다. 이후는 각 descriptor의 `next_sg_addr`에서 옵니다.
- **갱신 시점**: `TRANSFER_SUBMIT` 시점에 SG 엔진으로 넘어갑니다. 제출 후에는 다음 체인을 위해 바로 갱신해도 됩니다.

#### 4.6.2 `DESCRIPTOR_ID` (0x454)

| Bits | Field | 접근 | 리셋 | 설명 |
|---|---|:--:|:--:|---|
| `[31:0]` | `DESCRIPTOR_ID` | RO | `0` | SG 완료 추적 FIFO head의 descriptor `id` |

```verilog
assign fifo_in_data  = {hwdesc_flags & MASK_EOT_IRQ ? 1'b1 : 1'b0, hwdesc_id};
assign fifo_out_ready = resp_in_valid;    // ← 목적지 응답이 오면 pop
assign resp_out_id   = fifo_out_data[31:0];        // dmac_sg.v:312-315
```

- **동작 상세**
  - SG 엔진은 descriptor를 읽을 때마다 `{EOT 플래그, id}`를 **4-entry FIFO**에 넣고, 해당 descriptor의 전송이 끝날 때 하나씩 꺼냅니다.
  - 레지스터는 FIFO의 **head**를 조합 논리로 읽습니다. 전송 중에는 "현재 처리 중인 descriptor의 ID"입니다.
- **⚠ 실측 (M) — 체인 완료 후의 값**

  **본 구성에서는 체인 완료 후 `DESCRIPTOR_ID`가 마지막으로 완료된 descriptor의 id를 유지합니다.**

  | 테스트 | 체인 | 완료 후 읽은 값 | 기대 |
  |---|:--:|:--:|---|
  | `SAN-005` | 3개 (`0xB0`→`0xB1`→`0xB2`) | **`0xB2`** | 마지막 descriptor |
  | `SAN-006` | 1개 (`0xC5`) | **`0xC5`** | 마지막 descriptor |

  FIFO가 비면 `util_axis_fifo`의 `m_mem_read`가 멈춰 출력이 갱신되지 않기 때문입니다. `SAN-005`의 체인은 앞선 `SAN-004`(`0xA0`)가 남긴 값이 아니라 **자기 체인의 마지막 id**를 반환했으므로, "이전 슬롯의 잔류값"이 아님이 확인되었습니다.

  > **다만 이 동작은 ADI가 문서화한 계약이 아니라 `util_axis_fifo`의 구현 특성입니다.** 드라이버가 전송 완료 판정의 **근거로 삼는 것은 권장하지 않습니다.** 완료 확인은 EOT 인터럽트 또는 `TRANSFER_DONE`으로 하고, 이 레지스터는 **디버깅·추적 용도**로 씁니다.

- **HWDESC=0이면** 0입니다.

#### 4.6.3 SG 전용 동작 요약

| 항목 | 내용 |
|---|---|
| 활성 조건 | `CONTROL.HWDESC = 1` |
| 무시되는 레지스터 | `SRC_ADDRESS`, `DEST_ADDRESS`, `X_LENGTH` (descriptor 값 사용) |
| 그대로 쓰이는 레지스터 | `FLAGS.TLAST`, `IRQ_*`, `CONTROL` |
| descriptor 읽기 버스 | `m_sg_axi` (AR/R만 사용, `ARLEN=5`, `ARSIZE=3`, `ARBURST=INCR`) |
| **descriptor 읽기 에러** | **`m_sg_axi_rresp`를 검사하지 않음.** 에러 응답이 와도 데이터를 그대로 descriptor로 사용 |

---

### 4.7 디버그 (0x434–0x444)

`DISABLE_DEBUG_REGISTERS=0`이므로 모두 읽힙니다. **값의 타이밍이 버스 핸드셰이크에 묶여 있어 정확한 기대값 비교보다는 관찰용**입니다.

#### 4.7.1 `CURRENT_DEST_ADDRESS` (0x434)

`m_dest_axi_awaddr[31:0]`을 그대로 읽습니다 (`axi_dmac_regmap.v:264`). burst 단위로 갱신되므로 "가장 최근에 발행했거나 발행 대기 중인 write burst의 시작 주소"로 해석합니다.

#### 4.7.2 `CURRENT_SRC_ADDRESS` (0x438)

`m_src_axi_araddr[31:0]` (`:265`). 해석은 위와 같습니다.

#### 4.7.3 `DBG_STATUS` (0x43C)

upstream 레지스터 문서와 TB 패키지에 **없는** 레지스터입니다. RTL에서만 확인됩니다.

| Bits | Field | 설명 |
|---|---|---|
| `[31:12]` | — | 0 |
| `[11]` | `needs_reset` | ENABLE=0이 관측되어 리셋 시퀀스가 예약됨 |
| `[10]` | `req_resetn` | request 도메인 리셋 해제(1) |
| `[9]` | `src_resetn` | src 도메인 리셋 해제(1) |
| `[8]` | `dest_resetn` | dest 도메인 리셋 해제(1) |
| `[7]` | `sg_resetn` | SG 도메인 리셋 해제(1) |
| `[6]` | `req_enabled` | request 도메인 활성 |
| `[5]` | `enabled_src` | src 도메인 활성 |
| `[4]` | `enabled_dest` | dest 도메인 활성 |
| `[3]` | `enabled_sg` | SG 도메인 활성 |
| `[2:0]` | `state` | reset manager 상태 |

| `state` | 이름 | 의미 |
|:--:|---|---|
| `0` | `DO_RESET` | 리셋 펄스 발생 |
| `1` | `RESET` | 리셋 완료 대기 / `ENABLE=0` 동안 머무름 |
| `2` | `DISABLED` | 리셋 완료, `PAUSE` 해제 대기 |
| `3` | `STARTUP` | 모든 도메인 활성화 대기 |
| `4` | `ENABLED` | 정상 동작 |
| `5` | `SHUTDOWN` | 진행 중 트랜잭션 마무리 대기 |

- **본 구성 참고**: 단일 클록·`ASYNC_CLK_*=0`이므로 **4개 도메인 리셋이 같은 사이클에 풀리는 것이 정상**입니다. `enabled_sg`는 HWDESC=0이면 활성 판정에서 제외됩니다.
- **정상 운용 시 기대 패턴**: 리셋 후 ENABLE=0 → `state=1`, ENABLE=1 대기 → `state=4`, PAUSE=1 → `state=2`.
- **미측정 (R)** → [§9.3](#93-sanity-미커버-영역). 이 레지스터는 **FT에서 `ENABLE`/`PAUSE` 시퀀스를 관측하는 데 유용**합니다.

#### 4.7.4 `DBG_IDS0` (0x440) / `DBG_IDS1` (0x444)

```
DBG_IDS0 (dest)                             DBG_IDS1 (src)
 31  28 27  24 23 20 19 16 15 12 11  8 7  4 3  0     (각 byte: [7:4]=0 패딩, [3:0]=Gray ID)
+------+------+-----+-----+-----+-----+----+----+
| 0000 | resp | 0000| data| 0000| addr|0000| req|
+------+------+-----+-----+-----+-----+----+----+
```

| 레지스터 | Bits | Field |
|---|---|---|
| `DBG_IDS0` | `[27:24]` / `[19:16]` / `[11:8]` / `[3:0]` | dest의 response / data / address / request ID |
| `DBG_IDS1` | 동일 | src의 response / data / address / request ID |
| 공통 | `[31:28]`, `[23:20]`, `[15:12]`, `[7:4]` | 0 (`DBG_ID_PADDING=4`) |

- **값의 인코딩 — Gray**: 모든 필드는 **내부 burst 순번 태그의 Gray 코드 값**이며 **AXI transaction ID가 아닙니다.** 필드 하나가 burst 1개마다 `inc_id()`로 Gray 순서로 전진합니다.
  - `ENABLE=1` 이후 누적 burst 수 N에서 정지 상태의 기대값 = `b2g(N mod 16)` ([부록 B](#부록-b--gray-코드-변환표-id_width--4)).
  - 두 필드의 거리(in-flight burst 수) = `(g2b(x) − g2b(y)) mod 16`. **Gray 값을 그대로 빼면 틀립니다.**
- **burst 수 계산**: `MAX_BYTES_PER_BURST=128`이므로 128 B 정렬 전송은 `ceil((X_LENGTH+1)/128)`개 burst입니다. SG descriptor fetch는 이 ID를 쓰지 않으므로 N에 포함되지 않습니다.
- **리셋**: `ENABLE=0` → 모든 ID 0.
- **⚠ Sanity 판정 대상에서 제외**: Gray 인코딩 값이라 **안정적 기대값을 정의할 수 없고**, 인코딩 방식이 바뀌면 기대값도 바뀝니다. 읽기에 부작용은 없으므로 디버깅 참고용으로는 유효합니다.

---

### 4.8 본 구성에서 비활성인 레지스터

파라미터(`generate`)로 저장소 자체가 만들어지지 않거나 쓰기가 마스크됩니다. **쓰기 무시, 읽기 0**입니다.

| Offset | 이름 | 비활성 조건 | 근거 | 실측 |
|---|---|---|:--:|:--:|
| `0x41C` | `Y_LENGTH` | `DMA_2D_TRANSFER=0` | `regmap_request.v:271-275` | **M** |
| `0x420` | `DEST_STRIDE` | `DMA_2D_TRANSFER=0` | 동일 | R |
| `0x424` | `SRC_STRIDE` | `DMA_2D_TRANSFER=0` | 동일 | R |
| `0x458` | `FRAMELOCK_CONFIG` | `FRAMELOCK=0` | `:323-329` | **M** |
| `0x45C` | `FRAMELOCK_STRIDE` | `FRAMELOCK=0` | 동일 | R |
| `0x490` / `0x494` / `0x4BC` | 주소 `*_HIGH` | **`ADDR_WIDTH=32`** | `if (HAS_ADDR_HIGH)` 가드 | **M** |
| `0x400[3]` | `CONTROL.FRAMELOCK` | `FRAMELOCK=0` | `regmap.v:227` | **M** |
| `0x40C[0]` | `FLAGS.CYCLIC` | `CYCLIC=0` | `regmap_request.v:188` | **M** |

> **검증 가치**: 전 비트 1을 쓴 뒤 0이 읽히는지 확인하면 **"파라미터로 기능이 빠졌음"을 레지스터 수준에서 증명**할 수 있습니다. Sanity `SAN-007`이 이 목적의 TC입니다. 이는 **버그 검출보다 오판 방지**가 목적입니다 — 이 동작을 모르면 나중에 누가 "RW 레지스터 write/read-back" 테스트를 작성했을 때 정상 동작을 버그로 보고합니다.

---

## 5. SG 디스크립터 메모리 포맷

`CONTROL.HWDESC=1`에서 SG 엔진(`dmac_sg.v`)이 `m_sg_axi`로 읽는 메모리 구조입니다.

- **크기**: 48바이트 (64비트 × 6 beat, `ARLEN=5`)
- **정렬**: 8바이트 필수, **64바이트 권장** (한 burst가 4 KiB 경계를 넘지 않도록)
- **엔디언**: little-endian

| Offset | 크기 | Field | 비트 사용 | 본 구성 처리 | beat |
|---|:--:|---|---|---|:--:|
| `+0x00` | 32 | `flags` | `[0]` LAST, `[1]` EOT_IRQ, `[31:2]` 무시 | 사용 | 0 `[31:0]` |
| `+0x04` | 32 | `id` | `[31:0]` | 사용 → `DESCRIPTOR_ID` | 0 `[63:32]` |
| `+0x08` | 64 | `dest_addr` | `[63:3]` | 사용 | 1 |
| `+0x10` | 64 | `src_addr` | `[63:3]` | 사용 | 2 |
| `+0x18` | 64 | `next_sg_addr` | `[63:3]` | `flags[0]=0`일 때 다음 descriptor | 3 |
| `+0x20` | 32 | `y_len` | — | **무시** (2D 비활성) — 0 권장 | 4 `[31:0]` |
| `+0x24` | 32 | `x_len` | `[23:0]` (바이트 − 1) | 사용 | 4 `[63:32]` |
| `+0x28` | 32 | `src_stride` | — | **무시** — 0 권장 | 5 `[31:0]` |
| `+0x2C` | 32 | `dst_stride` | — | **무시** — 0 권장 | 5 `[63:32]` |

**`flags` 상세**

| Bit | 이름 | 의미 |
|:--:|---|---|
| `[0]` | `LAST` | 1 = 체인의 마지막. 처리 후 SG 엔진이 IDLE로 복귀. 0 = `next_sg_addr`를 이어서 읽음 |
| `[1]` | `EOT_IRQ` | 1 = 이 descriptor의 데이터 전송이 끝나면 `TRANSFER_COMPLETED` 이벤트 발생 |

> **주의 1 — `x_len` 상위 비트.** descriptor는 32비트지만 내부 레지스터가 24비트라 `[31:24]`가 **조용히 잘립니다.** 16 MiB 이상을 한 descriptor에 쓰면 길이가 틀어집니다.
>
> **주의 2 — 끝나지 않는 체인.** `LAST`가 하나도 없는 순환 체인은 합법적인 "HW cyclic" 구성입니다. **`ENABLE=0`으로만 멈출 수 있습니다.**
>
> **주의 3 — 읽기 에러 미검출.** `RRESP`를 검사하지 않으므로, 잘못된 주소의 descriptor를 읽어도 **에러 표시 없이 쓰레기값으로 전송이 진행**될 수 있습니다.

**실측 (M)**: Sanity `SAN-004`(1개) / `SAN-005`(3개 체인) / `SAN-006`(1개)에서 위 포맷으로 descriptor를 구성해 정상 동작을 확인했습니다. `SAN-005` 로그에서 **체인 3개가 첫 데이터 전송 전에 모두 prefetch**되는 것도 관측되었습니다.

---

## 6. 인터럽트 동작

### 6.1 신호 경로

```
                 +------------------- IRQ_SOURCE (0x088) --------------------+
up_sot ─┐        |  source <= {eot, sot} | (source & ~clear)                 |
up_eot ─┴──────► |  clear  = (write to 0x084) ? wdata[1:0] : 0               |
                 +---------------------------+------------------------------+
                                             │
                      IRQ_MASK (0x080) ──► ~mask &
                                             │
                                    IRQ_PENDING (0x084)
                                             │
                                      OR-reduce, 1 FF
                                             │
                                            irq   (level, active-high)
```

- `irq`는 `IRQ_PENDING` 비트 OR를 **1사이클 레지스터**로 낸 **레벨 신호**입니다.
- 원인을 지울 때까지 유지됩니다. **엣지 트리거 인터럽트 컨트롤러에 연결하면** 한 이벤트 처리 중 다른 이벤트가 들어올 때 레벨이 내려가지 않아 두 번째 엣지를 놓칠 수 있습니다. **레벨 트리거로 연결**합니다.
- **실측 (M)**: W1C 후 `irq` de-assert 확인 — `SAN-006` check 6.

### 6.2 SG 모드(HWDESC=1)에서의 이벤트 의미

| 이벤트 | HWDESC=0 | **HWDESC=1 (본 구성)** |
|---|---|---|
| `TRANSFER_QUEUED` (`up_sot`) | 레지스터 요청 수락 시 1회 | **체인 제출 1회당 1회** |
| `TRANSFER_COMPLETED` (`up_eot`) | 전송 완료 시 1회 | **`flags[1]=1`인 descriptor가 끝날 때마다** 1회 |

**권장 descriptor 플래그 설정**

| 목적 | 설정 | 결과 |
|---|---|---|
| **체인당 완료 인터럽트 1회 (기본)** | 마지막만 `flags = 0x3`, 나머지 `0x0` | `TRANSFER_ID` ↔ `TRANSFER_DONE` 1:1, 인터럽트 최소화 |
| descriptor별 진행 추적 | 모두 `flags[1]=1`, 마지막만 `flags[0]=1` | descriptor마다 EOT. **`TRANSFER_DONE`/`ACTIVE_TRANSFER_ID`가 체인 ID와 어긋남** |
| 인터럽트 없는 체인 | 모두 `flags[1]=0` | EOT 없음. **`TRANSFER_DONE` 미세트, `TRANSFER_PROGRESS` 미클리어** — 완료 확인은 메모리 polling만 가능 |

Sanity `SAN-005`가 첫 번째 방식(마지막만 `0x3`)을 사용합니다.

### 6.3 인터럽트 서비스 루틴 권장 순서

1. `IRQ_PENDING`(0x084) 읽기 → 처리할 비트 확인
2. **같은 값을 `IRQ_PENDING`에 써서 clear** (RW1C)
3. `TRANSFER_COMPLETED`이면 `TRANSFER_DONE`(0x428)으로 완료된 전송 ID 확인
4. `TRANSFER_QUEUED`이면 다음 전송 제출 가능

> **clear(2)를 상태 확인(3)보다 먼저 하는 이유**: clear 이후 들어온 이벤트는 "이벤트 우선" 규칙에 따라 다시 래치되므로 잃지 않습니다. 반대로 상태 확인 후 clear하면 **그 사이에 들어온 이벤트를 함께 지워버릴 수 있습니다.**

---

## 7. 프로그래밍 시퀀스

모든 접근은 **32비트 단위**입니다.

### 7.1 초기화 및 sanity check

| # | 동작 | 기대값 | Sanity TC |
|:--:|---|---|---|
| 1 | `R(0x000)` VERSION | `0x0004_0565` | `SAN-001` |
| 2 | `R(0x00C)` IDENTIFICATION | `0x444D_4143` | `SAN-001` |
| 3 | `R(0x010)` INTERFACE_DESCRIPTION_1 | `0x3807_0303` | `SAN-001` |
| 4 | `W(0x008, 0xA5A5_5A5A)` / `R(0x008)` | 기입값 | `SAN-002` |
| 5 | `R(0x400)` CONTROL | `0x0000_0000` | `SAN-003` |
| 6 | `R(0x080)` IRQ_MASK | `0x0000_0003` | `SAN-003` |

### 7.2 SG 전송 실행 (본 구성 표준 흐름)

```
1. 메모리에 descriptor 체인 작성 (§5 포맷, 8B 정렬)
     마지막 descriptor만 flags = 0x3 (LAST | EOT_IRQ)

2. W(0x080, 0x1)      // IRQ_MASK — SOT 마스크, EOT 허용
3. W(0x400, 0x5)      // CONTROL  — ENABLE | HWDESC
4. W(0x47C, <첫 descriptor 주소>)
5. W(0x408, 0x1)      // TRANSFER_SUBMIT

6. irq 대기  (또는 R(0x428) TRANSFER_DONE polling)

7. R(0x084) → IRQ_PENDING
8. W(0x084, <7의 값>) // W1C — IRQ_SOURCE 클리어
9. R(0x428)           // 완료된 전송 ID 확인
```

> **⚠ 3번과 5번의 순서는 바꿀 수 없습니다.** `ENABLE=0` 상태에서 `TRANSFER_SUBMIT`을 쓰면 **아무 일도 일어나지 않고 에러도 나지 않습니다**([§4.4.2](#442-transfer_submit-0x408)). 조용히 실패하므로 디버깅이 어렵습니다.

### 7.3 연속 전송

| # | 동작 | 비고 |
|:--:|---|---|
| 1 | `R(0x408)`이 0인지 확인 | 0이 아니면 이전 요청 미수락 |
| 2 | `R(0x404)` TRANSFER_ID 기록 | 이번 전송에 부여될 ID |
| 3 | `W(0x47C, <다음 체인 주소>)` | |
| 4 | `W(0x408, 0x1)` | |

최대 4개까지 추적 가능합니다(`TRANSFER_DONE[3:0]`). 그 이상 연속 제출하면 오래된 완료 정보가 덮어써집니다.

---

## 8. 리셋 · ENABLE · PAUSE 영향 매트릭스

| 레지스터 / 상태 | HW 리셋 | `ENABLE=0` | `PAUSE=1` |
|---|:--:|:--:|:--:|
| `SCRATCH` | 0 | 유지 | 유지 |
| `IRQ_MASK` | `0x3` | 유지 | 유지 |
| `IRQ_SOURCE` | 0 | **유지** | 유지 |
| `IRQ_PENDING` (조합) | 0 | SOURCE 따라감 | 유지 |
| `CONTROL` | 0 | — | — |
| `FLAGS` | `0x2` | 유지 | 유지 |
| `DEST/SRC_ADDRESS` | 0 | 유지 | 유지 |
| `X_LENGTH` | 0 | 유지 | 유지 |
| `SG_ADDRESS` | 0 | 유지 | 유지 |
| `TRANSFER_ID` | 0 | **0** | 유지 |
| `ACTIVE_TRANSFER_ID` | 0 | **0** | 유지 |
| `TRANSFER_DONE` | 0 | **0** | 유지 |
| `TRANSFER_SUBMIT` | 0 | **0** | 유지 |
| `TRANSFER_PROGRESS` | 0 | **0** | 유지 |
| partial FIFO | 비움 | **비움** | 유지 |
| DMA 데이터 경로 | 리셋 | **리셋 펄스** | 정지(상태 보존) |
| `DBG_IDS0/1` | 0 | **0** | 유지 |

> **핵심**: `ENABLE=0`은 **설정은 남기고 진행 상태만 지웁니다.** 테스트 간 상태 격리에 쓸 수 있지만, 의도치 않게 내리면 진행 중이던 전송 정보를 잃습니다.

---

## 9. Sanity Test 연계

> **본 통합본에서 신설한 절입니다.** 레지스터 맵과 회귀 테스트가 어긋나지 않도록 매핑을 명시합니다.

Sanity Test(`SGDMA-SANITY-v0.2`, `tb/sg_dma/tb_sg_dma.sv`)는 **TC 7건 / 체크 46건**이며, 2026-10-02 기준 **46/46 통과**입니다.

### 9.1 TC ↔ 레지스터 매핑

| TC | 체크 | 검증 레지스터 |
|---|:--:|---|
| `SAN-001` Register identity | 5 | `0x000`, `0x004`, `0x00C`, `0x010`, `0x014` |
| `SAN-002` Scratch R/W | 3 | `0x008` |
| `SAN-003` Reset defaults | 10 | `0x400`, `0x080`, `0x084`, `0x088`, `0x40C`, `0x428`, `0x404`, `0x410`, `0x414`, `0x47C` |
| `SAN-007` Parameter-masked bits | 11 | `0x400[3]`, `0x40C[0]`, `0x410/414/47C[2:0]`, `0x490/494/4BC`, `0x41C`, `0x458`, 미매핑 |
| `SAN-004` Single descriptor | 4 | `0x428` + 데이터 경로 |
| `SAN-005` 3-descriptor gather | 6 | `0x454` + 데이터 경로 |
| `SAN-006` IRQ & status | 7 | `0x080`, `0x084`, `0x088`, `0x454`, `irq` |

### 9.2 오판 방지 체크 (`SAN-007`)

파라미터로 **의도적으로 죽인 비트**를 버그로 오인하지 않도록, 기대값을 문서와 TB 양쪽에 고정했습니다.

| 동작 | 기대값 | 근거 |
|---|---|---|
| `W(0x400, 0xFFFFFFFF)` → `R` | `0x0000_0007` | `FRAMELOCK=0` |
| `W(0x40C, 0xFFFFFFFF)` → `R` | `0x0000_0006` | `CYCLIC=0` |
| `W(0x410, 0xFFFFFFFF)` → `R` | `0xFFFF_FFF8` | 8B 정렬 |
| `R(0x490/494/4BC)` | `0x0000_0000` | `ADDR_WIDTH=32` |
| `R(0x0F0)`, `R(0x600)` | `0x0000_0000` | 미매핑 |

### 9.3 Sanity 미커버 영역

아래는 **아직 실측되지 않은 레지스터**입니다. Feature Test 대상이거나 Sanity 보강 후보입니다.

| 레지스터 | 미커버 사유 | 권고 |
|---|---|---|
| `0x418` `X_LENGTH` | 리셋값 체크 누락 | **`SAN-003`에 추가 권장** (1줄) |
| `0x42C` `ACTIVE_TRANSFER_ID` | 체크 없음 | `SAN-003`에 리셋값 추가 권장 |
| `0x430` `STATUS` | 체크 없음 | 상시 0 — `SAN-007`에 추가 가능 |
| `0x420` / `0x424` `*_STRIDE` | 체크 없음 | `SAN-007`에 추가 가능 |
| `0x448` `TRANSFER_PROGRESS` | 전송 중 관측 필요 | FT |
| `0x434`~`0x444` 디버그군 | 기대값 정의 곤란 | FT (관측용) |
| `0x44C` / `0x450` partial | 본 구성 Unreachable | FT (도달 불가 확인) |
| `CONTROL` ENABLE 토글 효과 | 시퀀스 필요 | **FT — [§8](#8-리셋--enable--pause-영향-매트릭스) 매트릭스 검증** |
| `TRANSFER_SUBMIT` self-clear | 타이밍 관측 필요 | FT |

> **`X_LENGTH`와 `ACTIVE_TRANSFER_ID`는 리셋값 읽기 한 줄이면 되므로 Sanity에 넣는 것을 권합니다.** 나머지는 시퀀스나 전송 중 관측이 필요해 Sanity의 "30초 이내 / 자동 판정" 조건에 맞지 않습니다.

---

## 10. ADDR_WIDTH = 64 전환 시 영향

본 문서는 **as-built인 `DMA_AXI_ADDR_WIDTH = 32`** 기준입니다. 64로 전환하면 아래가 바뀝니다.

| 항목 | `= 32` (현재) | `= 64` |
|---|---|---|
| `HAS_ADDR_HIGH` | 0 | 1 |
| `0x490` `DEST_ADDRESS_HIGH` | **Inactive**, 읽기 0 | **RW**, 목적지 주소 `[63:32]` |
| `0x494` `SRC_ADDRESS_HIGH` | **Inactive**, 읽기 0 | **RW**, 소스 주소 `[63:32]` |
| `0x4BC` `SG_ADDRESS_HIGH` | **Inactive**, 읽기 0 | **RW**, descriptor 주소 `[63:32]` |
| `0x498` / `0x49C` 디버그 HIGH | 읽기 0 | 현재 주소 `[63:32]` |
| descriptor `dest/src/next` 상위 32비트 | 무시 | 유효 |
| 래퍼 포트 폭 | 32 | 64 |

**개정 대상 문서**: 본 문서 §3·§4.8·§9.2, Sanity 항목 정의서 `SAN-007` 체크 6~8, TB `tb_sg_dma.sv`의 `AW` localparam 및 해당 체크.

**판단 기준**: SoC 통합 시 주소 공간이 **4 GB를 넘는지**. 넘지 않으면 32 유지가 맞습니다.

---

## 11. 미확정 항목

| # | 항목 | 내용 | 해소 방법 |
|:--:|---|---|---|
| 1 | **`AXI_AXCACHE`** | 실측 `4'b0000`(Device Non-bufferable). MM→MM DMA에서는 `4'b0011` 권장 | `sg_dma_top.v`에 명시할지 **설계 결정 필요** |
| 2 | `DMA_AXI_ADDR_WIDTH` | 32(현재) vs 64 | SoC 주소 공간 확정 후 |
| 3 | SG 모드 시 주소/길이 레지스터 무시 여부 | `0x410`/`0x414`/`0x418`에 값을 써도 descriptor가 이기는지 | **FT 시나리오로 실측** |
| 4 | `DBG_IDS0/1` src 측 필드 | 소스 타입에 따라 전진하지 않는 필드가 있을 수 있음 | FT에서 파형 확인 후 고정 |
| 5 | `0x430` `STATUS` 용도 | 상시 0 — 예약인지 폐기된 레지스터인지 | ADI 문서 대조 |

---

## 부록 A — 리셋 직후 readback 기대값

HW 리셋 해제 직후, `CONTROL` 쓰기 전 상태입니다. **M = Sanity 실측 확인.**

| Offset | 이름 | 기대값 | 근거 |
|---|---|---|:--:|
| `0x000` | `VERSION` | `0x0004_0565` | **M** |
| `0x004` | `PERIPHERAL_ID` | `0x0000_0000` | **M** |
| `0x008` | `SCRATCH` | `0x0000_0000` | **M** |
| `0x00C` | `IDENTIFICATION` | `0x444D_4143` | **M** |
| `0x010` | `INTERFACE_DESCRIPTION_1` | `0x3807_0303` | **M** |
| `0x014` | `INTERFACE_DESCRIPTION_2` | `0x0000_0000` | **M** |
| `0x080` | `IRQ_MASK` | `0x0000_0003` | **M** |
| `0x084` | `IRQ_PENDING` | `0x0000_0000` | **M** |
| `0x088` | `IRQ_SOURCE` | `0x0000_0000` | **M** |
| `0x400` | `CONTROL` | `0x0000_0000` | **M** |
| `0x404` | `TRANSFER_ID` | `0x0000_0000` | **M** |
| `0x408` | `TRANSFER_SUBMIT` | `0x0000_0000` | R |
| `0x40C` | `FLAGS` | **`0x0000_0002`** | **M** |
| `0x410` | `DEST_ADDRESS` | `0x0000_0000` | **M** |
| `0x414` | `SRC_ADDRESS` | `0x0000_0000` | **M** |
| `0x418` | `X_LENGTH` | `0x0000_0000` | R |
| `0x41C` | `Y_LENGTH` | `0x0000_0000` | **M** |
| `0x420` / `0x424` | `*_STRIDE` | `0x0000_0000` | R |
| `0x428` | `TRANSFER_DONE` | `0x0000_0000` | **M** |
| `0x42C` | `ACTIVE_TRANSFER_ID` | `0x0000_0000` | R |
| `0x430` | `STATUS` | `0x0000_0000` | R |
| `0x434`~`0x444` | 디버그군 | **비교 제외** | — |
| `0x448` | `TRANSFER_PROGRESS` | `0x0000_0000` | R |
| `0x44C` / `0x450` | partial | `0x0000_0000` | R |
| `0x454` | `DESCRIPTOR_ID` | `0x0000_0000` | R |
| `0x458` | `FRAMELOCK_CONFIG` | `0x0000_0000` | **M** |
| `0x45C` | `FRAMELOCK_STRIDE` | `0x0000_0000` | R |
| `0x47C` | `SG_ADDRESS` | `0x0000_0000` | **M** |
| `0x490`/`0x494`/`0x4BC` | 주소 `*_HIGH` | `0x0000_0000` | **M** |
| `0x498`/`0x49C` | 디버그 `*_HIGH` | `0x0000_0000` | R |
| 미매핑 | — | `0x0000_0000` | **M** |

> **`0x40C` = `0x2`와 `0x080` = `0x3`이 유일한 비영(非零) 리셋값입니다.** 나머지는 모두 0이므로, "전 레지스터 0" 가정 테스트는 이 둘에서만 FAIL합니다.

---

## 부록 B — Gray 코드 변환표 (ID_WIDTH = 4)

`DBG_IDS0/1` 해석용입니다. `b2g(n) = n ^ (n >> 1)`.

| binary | Gray | binary | Gray |
|:--:|:--:|:--:|:--:|
| 0 | `0x0` | 8 | `0xC` |
| 1 | `0x1` | 9 | `0xD` |
| 2 | `0x3` | 10 | `0xF` |
| 3 | `0x2` | 11 | `0xE` |
| 4 | `0x6` | 12 | `0xA` |
| 5 | `0x7` | 13 | `0xB` |
| 6 | `0x5` | 14 | `0x9` |
| 7 | `0x4` | 15 | `0x8` |

**사용 예**: `ENABLE=1` 이후 burst 5개가 처리되고 정지한 상태라면 dest 네 필드가 모두 `0x7` → `DBG_IDS0 = 0x0707_0707`.

**거리 계산**: 두 필드의 in-flight burst 수 = `(g2b(x) − g2b(y)) mod 16`. **Gray 값을 그대로 빼면 틀립니다.**

---

## 부록 C — 관련 문서

| 문서 | 내용 |
|---|---|
| `260930-claude-SFR_MAP-001-jsha.md` | 본 문서의 구조 원본 (rev.001) |
| `261001-claude-sgdma_sfr_map-hrcho.md` | 본 문서의 실측 원본 (v0.2) |
| `260930-claude-RTL_config_modification_guide-003-jsha.md` | RTL 구성 가이드 |
| `260930-claude-rtl_design_crosscheck-hrcho.md` | RTL 교차 검증 (0-replication 패치 근거) |
| `261001-claude-sgdma_sanity_test_items-hrcho.md` | Sanity 항목 정의서 |
| `tb/sg_dma/tb_sg_dma.sv` | Sanity TB 구현 |

**RTL 원본**: `rtl/third_party/adi_hdl/library/axi_dmac/` — `axi_dmac_regmap.v`, `axi_dmac_regmap_request.v`, `dmac_sg.v`, `axi_dmac.v`, `axi_dmac_transfer.v`, `axi_dmac_reset_manager.v`

---

## 부록 D — 통합 시 해소된 충돌

| # | 항목 | rev.001 (jsha) | v0.2 (hrcho) | 통합본 | 근거 |
|:--:|---|---|---|---|---|
| ① | `INTERFACE_DESCRIPTION_2` 리셋값 | `0x0000_0030` | `0x0000_0030` | **`0x0000_0000`** | **실측** — 양쪽 다 regmap 로컬 기본값을 본 오류 |
| ② | `DMA_AXI_ADDR_WIDTH` | 64 (기본값 가정) | 32 | **32** | **as-built** — wrapper가 명시, 46 checks가 이 전제로 통과 |
| ③ | `DESCRIPTOR_ID` 완료 후 값 | "stale 값이 보일 수 있음" | 기대값 명시 없음 | **마지막 완료 descriptor id 유지** (계약 아님) | **실측** — 3-descriptor 체인 `0xB2` |
| ④ | `TRANSFER_SUBMIT` 접근 유형 | `RW1S-SC` + polling 규칙 | `RW` | **`RW1S-SC`** | rev.001이 정확 |
| ⑤ | `0x448` 명칭 | `TRANSFER_PROGRESS` | `TRANSFER_LENGTH` | **`TRANSFER_PROGRESS`** | 완료 시 0으로 지워지는 동작에 부합 |
| ⑥ | `0x014` 명칭 | `INTERFACE_DESCRIPTION_2` | `AXI_CONFIG` | **`INTERFACE_DESCRIPTION_2`** | `0x010`과 짝, upstream 명칭 |
| ⑦ | `0x454` 명칭 | `DESCRIPTOR_ID` | `SG_DESCRIPTOR_ID` | **`DESCRIPTOR_ID`** | upstream 명칭 |
| ⑧ | `0x434`/`0x438` 명칭 | `CURRENT_*_ADDRESS` | `DBG_*_ADDR` | **`CURRENT_*_ADDRESS`** | upstream 명칭 |

> **⑤~⑧ 명칭 변경은 TB의 `localparam`에 반영이 필요합니다.** 변경 후 Sanity 46/46 재확인을 권장합니다.

---

## 개정 이력

| 버전 | 일자 | 내용 |
|---|---|---|
| rev.001 | 2026-09-30 | jsha — RTL 정적 분석 기반 전체 사양 |
| v0.2 | 2026-10-01 | hrcho — 실측 기반 요약본 |
| **rev.002** | **2026-10-02** | **통합** — rev.001 구조 + 실측값 반영, 근거 등급(M/R/D) 신설, Sanity 연계(§9)·ADDR_WIDTH 전환 영향(§10) 신설, 충돌 8건 해소 |
