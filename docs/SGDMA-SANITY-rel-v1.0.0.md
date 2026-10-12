# SG DMA — Sanity Test

| 항목 | 내용 |
|---|---|
| 문서 ID | SGDMA-SANITY-rel-v1.0.0 |
| 작성일 | 2026-10-06 |
| 작성자 | hrcho |
| 대상 DUT | `rtl/sg_dma/sgdma_top.v` |
| 구현 | `tb/sg_dma/tb_sg_dma.sv` |
| 구성 | **TC 7건 / 체크 46건** |
| 최종 실행 | **2026-10-06 — 46/46 PASS** (시뮬레이션 시간 6,305 ns) |
| 상태 | **검증팀 인계본** |
| 원본문서 | $repo/docs/ref_hrcho/261006-claude-sgdma_sanity_test-001-hrcho.md |

## 관련 문서

| 문서 | 역할 |
|---|---|
| [`SGDMA-SFR-rel-v1.0.0`](SGDMA-SFR-rel-v1.0.0.md) | **SFR 상세** — 본 문서의 모든 기대값 근거 |
| [`SGDMA-SOR-rel-v1.0.0`](SGDMA-SOR-rel-v1.0.0.md) | **SOR** — 요구사항 및 전체 시나리오 |
| `$repo/docs/ref_hrcho/260930-claude-rtl_design_crosscheck-hrcho.md` | RTL 구성 교차 검증 |

---

## 이 문서를 처음 읽는 분께

**가장 먼저 [§5 커버 범위와 한계](#5-커버-범위와-한계)를 읽으십시오.**

46/46 PASS는 **"이 46개가 통과했다"**는 뜻이지 **"레지스터가 전부 정상이다"**는 뜻이 아닙니다. 예를 들어 `SAN-003`은 리셋값을 확인하지만, SFR 부록 A에 있는 약 30개 중 **10개만** 봅니다. 나머지는 의도적으로 검증팀에 남긴 것이며, §5.2에 전부 열거했습니다.

이 구분을 놓치면 **"이미 확인된 항목"으로 읽고 건너뛰게 됩니다.** 그것이 본 문서가 막으려는 가장 큰 위험입니다.

---

## 목차

- [1. 목적과 범위](#1-목적과-범위)
- [2. 구성](#2-구성)
- [3. TC 상세](#3-tc-상세)
- [4. 실행 방법](#4-실행-방법)
- [5. 커버 범위와 한계](#5-커버-범위와-한계)
- [6. TB 구조](#6-tb-구조)
- [7. 유지보수](#7-유지보수)
- [부록 A — 실측 로그 전문](#부록-a--실측-로그-전문)
- [부록 B — 체크 ↔ SFR 근거 대조표](#부록-b--체크--sfr-근거-대조표)
- [부록 C — 설계 결정 반영 이력](#부록-c--설계-결정-반영-이력)

---

# 1. 목적과 범위

## 1.1 회귀 게이트

Sanity Test의 목적은 **"RTL이 완전히 깨졌는가"를 수 초 안에 판별**하는 것입니다. 기능을 폭넓게 검증하는 것이 아니라, **다음 단계로 넘어가도 되는지를 판정**하는 관문입니다.

RTL을 고칠 때마다 돌리는 것을 전제로 하므로, 아래 네 조건을 만족해야 합니다.

| 조건 | 본 구현 | 근거 |
|---|---|---|
| **빠를 것** | 시뮬레이션 시간 **6,305 ns**, 실행 수 초 | 느리면 아무도 안 돌립니다 |
| **자동 판정** | `[ ok ]` / `[FAIL]` 로 체크마다 판정, 요약 집계 | 사람이 로그를 읽고 판단하면 게이트가 아닙니다 |
| **비정상 종료 코드** | 실패 시 `$fatal(1)` | CI/스크립트가 결과를 알 수 있어야 합니다 |
| **watchdog** | 전역 `#2_000_000` 타임아웃 | 핸드셰이크가 멈추면 회귀가 **영원히 끝나지 않습니다** |

**watchdog이 특히 중요합니다.** 기능 TB는 멈추면 사람이 보고 끄면 되지만, 회귀는 무인으로 돌아갑니다. 타임아웃 없이 hang하면 그날 회귀 전체가 멎습니다.

```systemverilog
// global watchdog - a hung handshake must not hang the regression
initial begin
  #2_000_000;
  $display("\n[FAIL] GLOBAL TIMEOUT - simulation did not finish");
  $fatal(1, "global watchdog");
end
```

개별 전송 대기에도 별도 타임아웃이 있습니다(`wait_irq`, 기본 50,000 사이클). 이쪽은 **그 TC의 FAIL 체크로 기록**되므로, 어느 TC에서 멈췄는지 로그에 남습니다.

## 1.2 Sanity가 아닌 것

**아래는 Sanity의 역할이 아니며, 본 문서가 그것을 주장하지 않습니다.**

| | |
|---|---|
| 커버리지 도구 | 코드/기능 커버리지는 측정하지 않습니다 |
| 전수 검사 | 레지스터 전체를 읽지 않습니다 ([§5.2](#52-커버하지-않는-것)) |
| 기능 검증 | 경계 조건·에러 주입·랜덤 조합은 범위 밖입니다 |
| 성능 측정 | 대역폭·레이턴시를 보지 않습니다 |

이것들은 SOR의 Feature / Corner / Error 시나리오가 담당합니다.

**이 구분은 팀 합의 사항입니다**(2026-10-06). 리셋값 미커버 항목을 Sanity에 추가하는 방안이 논의되었으나, **Sanity를 회귀 게이트 역할에 한정**하기로 했습니다. 리셋 관련은 SOR에서도 다루지 않기로 정리되었습니다 ([부록 C](#부록-c--설계-결정-반영-이력)).

---

# 2. 구성

## 2.1 TC 목록

| TC | 이름 | 체크 | 계층 | 목적 |
|---|---|:--:|:--:|---|
| `SAN-001` | Register identity | 5 | 레지스터 | 버스·디코딩 생존, 빌드 구성 확인 |
| `SAN-002` | Scratch R/W | 3 | 레지스터 | 쓰기 경로 생존 |
| `SAN-003` | Reset defaults | 10 | 레지스터 | 리셋 기본값 |
| `SAN-007` | Parameter-masked bits | 11 | 레지스터 | **오판 방지** — 의도적 비활성 비트 |
| `SAN-004` | Single descriptor copy | 4 | 전송 | SG 기본 동작 |
| `SAN-005` | 3-descriptor chain, gather | 6 | 전송 | **체인 추적** (SG 고유) |
| `SAN-006` | IRQ & status | 7 | 전송 | 인터럽트 경로 |
| | **합계** | **46** | | |

## 2.2 실행 순서

```text
SAN-001 -> SAN-002 -> SAN-003 -> SAN-007 -> SAN-004 -> SAN-005 -> SAN-006
|------------- 레지스터 계층 -------------|  |-------- 전송 계층 --------|
```

**순서에 의미가 있습니다. 임의로 바꾸면 안 됩니다.**

| 규칙 | 이유 |
|---|---|
| 레지스터 계층을 먼저 | 버스가 죽은 상태에서 전송 시나리오를 돌리면 **원인 분리가 안 됩니다.** "전송이 안 된다"와 "레지스터를 못 쓴다"가 구분되지 않습니다 |
| **`SAN-003`은 `SAN-007`보다 앞** | `SAN-007`이 `0xFFFF_FFFF`를 기입하므로, 뒤에 두면 리셋값을 볼 수 없습니다 |
| `SAN-002`는 `SAN-003`보다 앞이어도 무방 | `SCRATCH`(0x008)는 `SAN-003`의 확인 대상이 아닙니다 |
| `SAN-007`은 **원복 후 반환** | `CONTROL`을 0으로 되돌리지 않으면 `SAN-004`가 `ENABLE`이 선 상태로 시작합니다 |

전송 계층 진입 전에 공통 설정을 합니다.

```systemverilog
axil_write(REG_IRQ_MASK, 32'h1);   // SOT 마스크, EOT 허용
axil_write(REG_CONTROL,  32'h5);   // ENABLE | HWDESC
```

## 2.3 판정 규칙

| 상황 | 동작 |
|---|---|
| 체크 1건 통과 | `[ ok ]` 출력, TC pass 카운터 +1 |
| 체크 1건 실패 | `[FAIL]` + 기대값·실측값 출력, TC fail 카운터 +1 |
| TC 내 fail ≥ 1 | 해당 TC **FAIL**. 단, **이후 TC는 계속 실행** |
| `VERSION` 또는 `IDENTIFICATION` 불일치 | **나머지 6개 TC 전부 SKIP** 후 즉시 종료 |
| FAIL 또는 SKIP 1건이라도 있음 | `*** SANITY FAILED ***` + `$fatal(1)` |
| 전부 통과 | `*** SANITY PASSED ***` + `$finish` |

**중단 조건을 `VERSION`/`IDENTIFICATION` 둘로 좁힌 것이 설계 판단입니다.**

초기 구현은 `SAN-001`의 체크가 하나라도 틀리면 나머지를 전부 SKIP했습니다. 그런데 실제로 `INTERFACE_DESCRIPTION_2` 기대값이 틀려서 **정상 동작하는 RTL에 대해 6개 TC가 전부 SKIP**되는 일이 있었습니다 ([부록 C](#부록-c--설계-결정-반영-이력)).

`INTERFACE_DESCRIPTION_1/2`와 `PERIPHERAL_ID`는 **빌드 구성 레지스터**입니다. 값이 틀리면 **기대값이 틀린 것이지 버스가 죽은 것이 아닙니다.** 그래서 `bus_ok` 플래그를 따로 두고, 이 둘만 게이트로 씁니다.

```systemverilog
bit bus_ok = 1'b1;   // cleared only when the bus itself looks dead
...
axil_read(REG_VERSION, rd);
check_eq("VERSION", rd, EXP_VERSION);
if (rd !== EXP_VERSION) bus_ok = 1'b0;
```

구성 레지스터가 틀리면 안내 문구를 출력합니다.

```text
note : build-configuration register mismatch - confirm the
       expected value before treating it as an RTL defect.
```

---

# 3. TC 상세

각 TC는 **목적 → 절차 → 체크 → 기대값 근거 → 주의**입니다. 모든 기대값의 상세 근거는 SFR 문서에 있습니다.

## 3.1 `SAN-001` — Register identity (5 checks)

**목적**: AXI4-Lite 버스와 레지스터 디코딩이 살아 있는지, 그리고 **의도한 파라미터로 합성되었는지** 확인합니다.

| # | 체크 | 기대값 | SFR |
|:--:|---|---|:--:|
| 1 | `VERSION` (0x000) | `0x0004_0565` | [4.1.1] |
| 2 | `IDENTIFICATION` (0x00C) | `0x444D_4143` ("DMAC") | [4.1.4] |
| 3 | `PERIPHERAL_ID` (0x004) | `0x0000_0000` | [4.1.2] |
| 4 | `INTERFACE_DESCRIPTION_1` (0x010) | `0x3807_0303` | [4.1.5] |
| 5 | `INTERFACE_DESCRIPTION_2` (0x014) | `0x0000_0000` | [4.1.6] |

**체크 4가 가장 많은 정보를 담고 있습니다.** `INTERFACE_DESCRIPTION_1`은 빌드 파라미터를 패킹한 상수 레지스터라, 이 한 값이 맞으면 `DMA_TYPE_SRC/DEST`(둘 다 AXI-MM), `BYTES_PER_BEAT`(8), `MAX_BYTES_PER_BURST`(128), `MAX_NUM_FRAMES`가 전부 의도대로임이 증명됩니다.

```text
 31    27 26 25 24 23  20 19  16 15 14 13 12 11   8 7  6 5  4 3    0
+--------+--+--+--+------+------+-----+-----+------+----+-----+------+
|MAX_NUM_|2D|EX|AR| rsvd |BPBRST|rsvd |TYPE | BPB  |rsvd|TYPE | BPB  |
|FRAMES-1|TL|SY|UN|      |_WIDTH|     | SRC | SRC  |    |DEST | DEST |
+--------+--+--+--+------+------+-----+-----+------+----+-----+------+
    7     0  0  0    0      7      0     0     3     0     0     3    -> 0x3807_0303
```

**주의 — 체크 5의 기대값은 과거에 틀렸던 값입니다.** `0x30`이라고 적은 문서가 두 건 있었고, 둘 다 `axi_dmac_regmap.v`의 **로컬 기본값** `AXI_AXCACHE = 4'b0011`을 보고 계산한 것이었습니다. 실제로는 상위 모듈 `axi_dmac`이 넘기는 값이 적용됩니다. 2026-10-06부터 `sgdma_top`이 `4'b0000`을 **명시**하므로 이 혼동은 더 생기지 않습니다. TB 주석에도 경고를 남겼습니다.

## 3.2 `SAN-002` — Scratch R/W (3 checks)

**목적**: 쓰기 경로가 살아 있는지 확인합니다. `SCRATCH`(0x008)는 기능이 없는 레지스터라 부작용 없이 쓸 수 있습니다.

| # | 기입값 | 읽기 기대 |
|:--:|---|---|
| 1 | `0xA5A5_5A5A` | 동일 |
| 2 | `0x5A5A_A5A5` | 동일 |
| 3 | `0x0000_0000` | 동일 |

**패턴을 반전해 두 번 쓰는 것이 핵심입니다.** 한 패턴만 쓰면 일부 비트가 1로 고착(stuck-at-1)되어 있어도 통과합니다. `0xA5A5_5A5A`와 그 반전을 모두 확인해야 32비트 전체가 양방향으로 동작함이 보장됩니다.

세 번째로 0을 쓰는 것은 **다음 TC를 위한 원복**입니다.

## 3.3 `SAN-003` — Reset defaults (10 checks)

**목적**: HW 리셋 해제 직후의 레지스터 기본값을 확인합니다.

| # | 레지스터 | 기대값 | 비고 |
|:--:|---|---|---|
| 1 | `CONTROL` (0x400) | `0x0000_0000` | **`HWDESC`도 0** |
| 2 | `IRQ_MASK` (0x080) | **`0x0000_0003`** | **비영** — 둘 다 마스크됨 |
| 3 | `IRQ_PENDING` (0x084) | `0x0000_0000` | |
| 4 | `IRQ_SOURCE` (0x088) | `0x0000_0000` | |
| 5 | `FLAGS` (0x40C) | **`0x0000_0002`** | **비영** — `TLAST` 기본 1 |
| 6 | `TRANSFER_DONE` (0x428) | `0x0000_0000` | |
| 7 | `TRANSFER_ID` (0x404) | `0x0000_0000` | |
| 8 | `DEST_ADDRESS` (0x410) | `0x0000_0000` | |
| 9 | `SRC_ADDRESS` (0x414) | `0x0000_0000` | |
| 10 | `SG_ADDRESS` (0x47C) | `0x0000_0000` | |

> **비영(非零) 리셋값이 둘 있습니다 — `IRQ_MASK` = `0x3`, `FLAGS` = `0x2`.**
> "리셋 후 전 레지스터 0"을 가정한 테스트는 **이 둘에서만** FAIL합니다. 이 IP를 처음
> 다루는 사람이 가장 많이 걸리는 지점입니다.

**`CONTROL.HWDESC` 리셋값이 0인 점을 특히 유의하십시오.** "SG 모드를 상시 사용한다"는 것은 **소프트웨어 운용 전제**이지 하드웨어 기본값이 아닙니다. 드라이버가 `CONTROL`에 `0x5`(ENABLE | HWDESC)를 명시적으로 써야 SG가 동작합니다.

**이 TC는 10개만 봅니다.** SFR 부록 A에는 약 30개가 있습니다. 미커버 목록은 [§5.2](#52-커버하지-않는-것)에 있습니다.

## 3.4 `SAN-007` — Parameter-masked bits (11 checks)

**목적은 버그 검출이 아니라 오판 방지입니다.**

파라미터로 **의도적으로 죽인 비트**들이 있습니다. 이 동작을 모르는 사람이 나중에 "RW 레지스터 write / read-back" 테스트를 작성하면 **정상 동작을 버그로 보고**합니다. 기대값을 문서와 TB 양쪽에 고정해 그것을 막습니다.

| # | 동작 | 기대값 | 비활성 원인 |
|:--:|---|---|---|
| 1 | `W(0x400, 0xFFFF_FFFF)` → `R` | `0x0000_0007` | `FRAMELOCK = 0` → `[3]` 마스크 |
| 2 | `W(0x40C, 0xFFFF_FFFF)` → `R` | `0x0000_0006` | `CYCLIC = 0` → `[0]` 마스크 |
| 3 | `W(0x410, 0xFFFF_FFFF)` → `R` | `0xFFFF_FFF8` | 64b 버스 → 8B 정렬 |
| 4 | `W(0x414, 0xFFFF_FFFF)` → `R` | `0xFFFF_FFF8` | 동일 |
| 5 | `W(0x47C, 0xFFFF_FFFF)` → `R` | `0xFFFF_FFF8` | 동일 |
| 6 | `W(0x490, 0xFFFF_FFFF)` → `R` | `0x0000_0000` | `ADDR_WIDTH = 32` → `HAS_ADDR_HIGH = 0` |
| 7 | `W(0x494, 0xFFFF_FFFF)` → `R` | `0x0000_0000` | 동일 |
| 8 | `W(0x4BC, 0xFFFF_FFFF)` → `R` | `0x0000_0000` | 동일 |
| 9 | `R(0x41C)` `Y_LENGTH` | `0x0000_0000` | `DMA_2D_TRANSFER = 0` |
| 10 | `R(0x458)` `FRAMELOCK_CONFIG` | `0x0000_0000` | `FRAMELOCK = 0` |
| 11 | `R(0x0F0)`, `R(0x600)` 미매핑 | 둘 다 `0x0000_0000` | 미정의 주소 |

**체크 6~8이 뜻하는 것**: `*_ADDRESS_HIGH` 레지스터는 "0을 반환"하는 것이 아니라 `if (HAS_ADDR_HIGH)` 가드로 **쓰기 로직 자체가 합성되지 않습니다.** 레지스터가 존재하지 않습니다.

**체크 11이 중요한 이유**: 본 IP는 **미정의 주소에 대해 에러 응답을 내지 않습니다.** `BRESP`/`RRESP`가 항상 `OKAY`입니다. 따라서 주소 디코드 오류를 잡으려면 **readback 값 비교가 유일한 수단**입니다.

> **`0x450`(`PARTIAL_TRANSFER_ID`)은 의도적으로 읽지 않습니다.**
> 이 주소는 **읽기가 내부 FIFO를 pop**합니다(`up_tlf_rd = up_rreq && up_raddr == 'h114'`).
> 본 구성에서는 FIFO가 항상 비어 있어 실제 피해가 없지만, **"전 레지스터 덤프" 방식의
> 테스트를 만들면 안 되는 이유**이므로 원칙으로 고정했습니다. SFR 4.5.5 참조.

**이 TC는 건드린 레지스터를 전부 원복하고 반환합니다.**

```systemverilog
axil_write(REG_CONTROL,      32'h0000_0000);   // 안 하면 SAN-004가 ENABLE=1로 시작
axil_write(REG_FLAGS,        EXP_FLAGS_RESET);
axil_write(REG_DEST_ADDRESS, 32'h0000_0000);
axil_write(REG_SRC_ADDRESS,  32'h0000_0000);
axil_write(REG_SG_ADDRESS,   32'h0000_0000);
```

## 3.5 `SAN-004` — Single descriptor copy (4 checks)

**목적**: SG 기본 동작 — descriptor 1개를 읽고 메모리→메모리 전송을 완료하는지.

**구성**

| | |
|---|---|
| descriptor | `0x0000_1000` · `id = 0xA0` · `flags = 0b11` (LAST \| EOT_IRQ) |
| 전송 | `0x0001_0000` → `0x0002_0000`, **256 byte** |

| # | 체크 | 내용 |
|:--:|---|---|
| 1 | `irq asserted` | EOT 인터럽트 발생 (타임아웃 50,000 사이클) |
| 2 | `data` | 256 byte 전부 바이트 단위 일치 |
| 3 | `tail` | 목적지 끝 이후 16 byte가 **쓰이지 않음** |
| 4 | `TRANSFER_DONE bit set` | `[3:0]` 중 하나 이상 1 |

**체크 3(tail)이 필요한 이유**: 데이터가 맞는 것만으로는 부족합니다. **범위를 넘어 쓰는 버그**는 데이터 비교로 안 잡힙니다. 메모리 모델이 "쓰였는지"를 바이트 단위로 추적하므로(`mem_written()`), 목적지 뒤 16 byte가 한 번도 쓰이지 않았음을 확인합니다.

**관측된 버스 동작** (실측)

```text
[3195000]   SG AR  addr=0x00001000 beats=6  size=8B   <- descriptor fetch, 48 B
[3315000]  SRC AR  addr=0x00010000 beats=16 size=8B   <- 128 B
[3495000]  DST AW  addr=0x00020000 beats=16 size=8B
[3495000]  SRC AR  addr=0x00010080 beats=16 size=8B   <- 128 B (분할)
[3705000]  DST AW  addr=0x00020080 beats=16 size=8B
```

- descriptor fetch가 **6 beat × 64bit = 48 byte 단일 INCR burst**로 나갑니다 (`ARLEN=5`, `ARSIZE=3`)
- 256 byte 전송이 `MAX_BYTES_PER_BURST = 128`에 따라 **2개 burst로 분할**됩니다

## 3.6 `SAN-005` — 3-descriptor chain, gather (6 checks)

**SG의 핵심 기능을 보는 TC입니다.** 체인 추적(`next_sg_addr` 따라가기)이 동작하지 않으면 SG가 아닙니다.

**구성** — 흩어진 소스 3곳을 연속된 목적지로 모읍니다(gather).

| descriptor | 주소 | `id` | `flags` | 소스 | 목적지 | 길이 |
|---|---|:--:|:--:|---|---|:--:|
| 0 | `0x0000_1100` | `0xB0` | `0b00` | `0x0001_1000` | `0x0002_1000` | 128 |
| 1 | `0x0000_1140` | `0xB1` | `0b00` | `0x0001_3000` | `0x0002_1080` | 256 |
| 2 | `0x0000_1180` | `0xB2` | **`0b11`** | `0x0001_5000` | `0x0002_1180` | 64 |

**마지막 descriptor에만 `flags = 0b11`(LAST | EOT_IRQ)을 둡니다.** 이렇게 하면 `TRANSFER_ID`와 `TRANSFER_DONE`이 1:1로 대응하고 인터럽트도 체인당 1회입니다. 모든 descriptor에 `flags[1]`을 세우면 두 카운터가 어긋납니다(SFR 6.2).

| # | 체크 | 내용 |
|:--:|---|---|
| 1 | `irq asserted` | 체인 전체 완료 후 1회 |
| 2~4 | `seg0` / `seg1` / `seg2` | 각 세그먼트 바이트 단위 일치 |
| 5 | `tail` | 448 byte 뒤 16 byte 미기입 |
| 6 | `DESCRIPTOR_ID = last of chain` | `0x0000_00B2` |

**관측된 prefetch 동작** (실측)

```text
[4215000]   SG AR  addr=0x00001100    <- desc 0
[4295000]   SG AR  addr=0x00001140    <- desc 1
[4335000]  SRC AR  addr=0x00011000    <- 첫 데이터 전송 시작
[4375000]   SG AR  addr=0x00001180    <- desc 2
```

**descriptor 3개가 첫 데이터 전송이 끝나기 전에 모두 fetch됩니다.** descriptor fetch와 데이터 전송이 파이프라인으로 중첩된다는 직접 증거입니다.

### 체크 6에 대한 주의 — 계약이 아닙니다

**`DESCRIPTOR_ID`가 체인 완료 후 마지막 descriptor의 id를 유지하는 것은 `util_axis_fifo`의 구현 특성이지 ADI가 문서화한 계약이 아닙니다.**

`dmac_sg`는 목적지 응답마다 완료 추적 FIFO를 pop하고, FIFO가 비면 출력이 갱신되지 않아 마지막 값이 남습니다. 선행 문서에는 "이전 전송의 stale 값이 보일 수 있다"는 경고가 있었는데, **이 TC가 그것을 반증했습니다** — 앞선 `SAN-004`가 남긴 `0xA0`이 아니라 자기 체인의 `0xB2`가 나왔습니다.

> **드라이버는 이 값을 완료 판정 근거로 쓰면 안 됩니다.** 완료 확인은 EOT 인터럽트나
> `TRANSFER_DONE`으로 합니다. 이 체크가 FAIL하면 **IP 버그가 아니라 구현이 바뀐 신호**로
> 해석하고, 먼저 `dmac_sg.v`와 `util_axis_fifo`를 확인하십시오.

## 3.7 `SAN-006` — IRQ & status (7 checks)

**목적**: 인터럽트 경로 전체 — 이벤트 래치 → 마스크 게이트 → `irq` 출력 → W1C 클리어.

**구성**: descriptor 1개 (`id = 0xC5`, 64 byte), `IRQ_MASK = 0x1` (SOT 마스크, EOT 허용)

| # | 체크 | 기대 | 확인 내용 |
|:--:|---|---|---|
| 1 | `IRQ_MASK = 0x1` | `0x0000_0001` | 앞서 쓴 마스크가 유지됨 |
| 2 | `irq asserted` | — | 전송 완료 시 `irq` 상승 |
| 3 | `IRQ_PENDING[1] set` | `[1] = 1` | EOT가 pending으로 전파 |
| 4 | `IRQ_PENDING cleared` | `0x0000_0000` | W1C 후 |
| 5 | **`IRQ_SOURCE[0] survives W1C`** | **`0x0000_0001`** | **마스크된 SOT가 SOURCE에는 남음** |
| 6 | `irq de-asserted after W1C` | `irq = 0` | 레벨 신호 하강 |
| 7 | `DESCRIPTOR_ID` | `0x0000_00C5` | |

**체크 5가 이 TC에서 가장 가치 있는 체크입니다.**

`IRQ_MASK`는 **이벤트 래치를 막지 않습니다.** 마스크된 SOT 이벤트도 `IRQ_SOURCE[0]`에 기록되며, `IRQ_PENDING`에만 안 보일 뿐입니다. 그래서 W1C로 `[1]`만 지운 뒤 `IRQ_SOURCE`를 읽으면 `0x1`이 남아 있습니다.

이 동작의 실무적 함의는 이렇습니다.

> **마스크를 푸는 순간 과거 이벤트가 튀어나옵니다.** unmask 전에 `IRQ_PENDING`에 `0x3`을
> 써서 비우지 않으면, unmask 직후 의도치 않은 인터럽트가 올라옵니다. 드라이버와 테스트
> 모두 이 순서를 지켜야 합니다.

**`IRQ_PENDING`에 쓰면 지워지는 것은 `IRQ_SOURCE`입니다.** 이름과 실제가 어긋나는 지점이라 시나리오 작성 시 반드시 구분해야 합니다(SFR 4.2.2).

---

# 4. 실행 방법

## 4.1 기본 실행

```bash
cd xsim
source sourceme          # Vivado 환경 (설정되어 있으면 생략 가능)
make clean && make sim
```

| 타깃 | 동작 |
|---|---|
| `make sim` | 컴파일 + elaborate + 배치 실행. **회귀 게이트** |
| `make wave` | 전 신호를 `.wdb`로 덤프하며 실행 |
| `make view` | `make wave`가 만든 `.wdb`를 GUI로 열기 |
| `make gui` | 스냅샷을 GUI로 열기 (신호를 직접 추가 후 `run all`) |
| `make clean` | 시뮬레이션 산출물 삭제 |

> **`make clean`을 생략하지 마십시오.** `xelab`은 소스가 아니라 **컴파일된 라이브러리**
> (`xsim.dir/work/`)를 읽습니다. RTL을 고친 뒤 `make sim`만 돌리면 **이전 코드가 그대로
> 돌 수 있습니다.** 모듈명을 바꿨을 때 특히 혼란스럽습니다.

## 4.2 판정

```text
SANITY: 7 PASS / 0 FAIL / 0 SKIP     (46/46 checks)
*** SANITY PASSED ***
```

| 종료 | 의미 |
|---|---|
| `*** SANITY PASSED ***` + `$finish` | 통과. 종료 코드 0 |
| `*** SANITY FAILED ***` + `$fatal(1)` | **실패.** 종료 코드 비정상 |
| `GLOBAL TIMEOUT` | 핸드셰이크 정지. `$fatal(1)` |

스크립트에서는 종료 코드만 보면 됩니다. 로그 파싱이 필요 없습니다.

## 4.3 실패했을 때

| 증상 | 먼저 볼 것 |
|---|---|
| `SAN-001`의 `VERSION`/`IDENTIFICATION` FAIL | **버스 또는 디코딩이 깨짐.** 나머지는 SKIP되므로 이것부터 |
| 구성 레지스터(3·4·5) FAIL | **기대값이 틀렸을 가능성이 먼저**입니다. 파라미터를 바꿨다면 [§7.1](#71-파라미터를-바꿨을-때) |
| `SAN-003` FAIL | 리셋 시퀀스 또는 레지스터 초기값 |
| `SAN-007` FAIL | 파라미터 변경 여부 확인. 기능 변경이면 기대값을 같이 고쳐야 함 |
| `irq asserted` 타임아웃 | 전송이 완료되지 않음. `make wave`로 `m_sg_axi` / `m_src_axi` / `m_dest_axi` 확인 |
| `data` mismatch | 처음 4건의 주소·값이 출력됩니다. 주소 패턴을 보면 정렬 문제인지 길이 문제인지 구분됩니다 |
| `GLOBAL TIMEOUT` | 어느 TC에서 멈췄는지 직전 출력으로 확인 |

---

# 5. 커버 범위와 한계

> **본 문서에서 가장 중요한 절입니다.** SOR의 Reset / Clock 항목이 Sanity에 위임되므로,
> **이 TB가 리셋 검증의 근거물**이 됩니다. 무엇을 확인했는지만큼 **무엇을 확인하지
> 않았는지**가 중요합니다.

## 5.1 커버하는 것

| 영역 | 내용 | TC |
|---|---|---|
| 버스 생존 | AXI4-Lite 읽기·쓰기 | SAN-001, 002 |
| 빌드 구성 | 파라미터가 의도대로 합성됨 | SAN-001 |
| 리셋값 | **10개 레지스터** | SAN-003 |
| 비활성 비트 | 파라미터 마스킹 8종 + 미매핑 | SAN-007 |
| SG 기본 동작 | descriptor fetch → MM→MM 전송 | SAN-004 |
| **SG 체인 추적** | `next_sg_addr` 3단 + prefetch | **SAN-005** |
| descriptor 포맷 | `flags` · `id` · 주소 · `x_len` 해석 | SAN-004, 005 |
| 버스트 분할 | 128 B 단위 | SAN-004 (관측) |
| 인터럽트 경로 | 래치 → 마스크 → pending → W1C → 하강 | SAN-006 |
| 범위 침범 | 목적지 뒤 16 byte 미기입 | SAN-004, 005 |

## 5.2 커버하지 않는 것

### 레지스터 — 리셋값 미확인

| 레지스터 | 사유 |
|---|---|
| `0x408` `TRANSFER_SUBMIT` | 리셋값 체크 없음 |
| `0x418` `X_LENGTH` | **upstream 문서는 `7`, RTL 분석은 `0`으로 어긋남 — 미측정** |
| `0x420` / `0x424` `*_STRIDE` | 체크 없음 (비활성 레지스터) |
| `0x42C` `ACTIVE_TRANSFER_ID` | 체크 없음 |
| `0x430` `STATUS` | 체크 없음 (상시 0) |
| `0x448` `TRANSFER_PROGRESS` | 체크 없음 |
| `0x44C` `PARTIAL_TRANSFER_LENGTH` | 체크 없음 |
| `0x454` `DESCRIPTOR_ID` | **리셋 직후 값** 미확인 (전송 후 값은 SAN-005/006이 확인) |
| `0x45C` `FRAMELOCK_STRIDE` | 체크 없음 |
| `0x498` / `0x49C` `CURRENT_*_HIGH` | 체크 없음 |
| `0x450` `PARTIAL_TRANSFER_ID` | **의도적 제외** — 읽기가 FIFO를 pop |
| `0x434`~`0x444` 디버그군 | **의도적 제외** — 고정 리셋값이 없어 기대값 정의 불가 |

> **`0x418` `X_LENGTH`는 주의가 필요합니다.** upstream 문서는 리셋값을
> `2**clog2(버스폭/8)−1` = `7`로 적지만, 이는 길이 정렬 제약이 있는 구성의 값입니다.
> 본 구성은 `DMA_LENGTH_ALIGN = 0`이라 RTL 분석상 `0`입니다. **둘 중 어느 쪽인지
> 측정되지 않았습니다.**

### 기능 — 범위 밖

| 영역 | 내용 |
|---|---|
| `ENABLE` / `PAUSE` 시퀀스 | 토글 후 어떤 상태가 지워지고 어떤 설정이 남는지 |
| 전송 중 관측 | `TRANSFER_PROGRESS`, `CURRENT_*_ADDRESS`, `DBG_STATUS` |
| **Scatter** | 본 TB는 **gather(N→1)만** 확인. **1→N scatter는 미검증** |
| 체인 길이 | 3단만 확인. 1단·긴 체인·`TRANSFER_DONE` 4개 초과 미확인 |
| 전송 길이 | 64 / 128 / 256 byte만. **바이트 단위 비정렬 길이 미확인** |
| 주소 정렬 | 8 byte 정렬만. 비정렬 descriptor 미확인 |
| 4 KiB 경계 | burst가 경계를 넘는 경우 미확인 |
| 연속 전송 | 큐잉, `TRANSFER_SUBMIT` self-clear 타이밍 |
| descriptor별 IRQ | 중간 descriptor에 `flags[1]`을 세운 경우 |
| 에러 주입 | `RRESP`/`BRESP` 에러, 잘못된 descriptor 주소 |
| 랜덤 지연 | 메모리 모델이 지연 없이 응답 |
| AXI 프로토콜 준수 | assertion 없음. **`AxCACHE`가 실제로 `4'b0000`인지 미확인** |

> **"전송 길이"가 본 구성의 고유 가치가 집중된 지점입니다.** `DMA_LENGTH_ALIGN = 0`은
> SRC·DEST가 **둘 다 AXI-MM**일 때만 성립하며, **ADI 공식 testbench는 이 조합을 검증하지
> 않습니다**(두 config 모두 한쪽이 AXI-Stream). 바이트 단위 길이 지정은 **아무도 검증한
> 적이 없는 영역**입니다.

## 5.3 SOR 연계

미커버 항목 중 **리셋 관련은 본 개정 범위에서 제외되었습니다.** 나머지는 SOR 요구사항으로 넘어갑니다.

| 미커버 영역 | 인계 방향 |
|---|---|
| **리셋값 나머지 (§5.2)** | **진행하지 않음** — 아래 참조 |
| `ENABLE` / `PAUSE` 시퀀스 | SOR `REG-006` · `REG-008` / 시나리오 `FT-011` · `FT-012`. SFR §8 영향 매트릭스가 기대값 |
| Scatter · 체인 길이 · 길이/정렬 sweep | SOR `FUNC-003` ~ `FUNC-005` / Priority B |
| 4 KiB 경계 | SOR `AXI-004` / Priority C |
| 에러 주입 | SOR `ERR-001` ~ `ERR-004` / Priority D |
| AXI 프로토콜 | SOR `AXI-001` ~ `AXI-007` / assertion 기반 |

> **리셋 관련은 Sanity에도 SOR에도 추가하지 않기로 했습니다**(2026-10-06 팀 결정).
> SOR의 [3-1 Reset / Clock]은 "Sanity Test에서 커버됨 · 해당 사항 없음"으로 정리되었고,
> `RST` 요구사항 6건은 삭제되었습니다. 따라서 §5.2의 미측정 리셋값은 **현 시점에서
> 수행 계획이 없는 상태로 남습니다.**

**이것이 의미하는 바를 분명히 해 둡니다.** `X_LENGTH`(0x418)의 리셋값은 upstream 문서가 `7`,
RTL 분석이 `0`으로 **서로 어긋난 채 측정되지 않았습니다.** SFR 문서에서 근거 등급 **R**로
표기되어 있으며, 누구도 확인하지 않은 상태로 인계됩니다. 향후 드라이버가 이 값을 전제로
동작하거나 레지스터 사양에 의문이 생기면 **그때 측정 대상이 됩니다.**

---

# 6. TB 구조

## 6.1 전체 구성

![Fig.1 — Sanity Testbench 구성)](./figs/SAN-001.png)
<!-- <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1040 686" width="100%" role="img" aria-label="Sanity Testbench 구성"><rect width="1040" height="686" fill="#ffffff"/><defs><marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0,1 L9,5 L0,9 z" fill="#1f2328"/></marker><marker id="ahg" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0,1 L9,5 L0,9 z" fill="#8c959f"/></marker><marker id="ahgr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0,1 L9,5 L0,9 z" fill="#1a7f37"/></marker><marker id="ahs" viewBox="0 0 10 10" refX="1" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M9,1 L0,5 L9,9 z" fill="#1f2328"/></marker></defs><text x="16" y="26" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="15.5" font-weight="700" fill="#1f2328" text-anchor="start">Fig.1 — Sanity Testbench 구성</text><text x="16" y="45" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="400" fill="#6e7781" text-anchor="start">tb_sg_dma  ·  세 메모리 모델이 tb_mem_pkg 의 같은 연관 배열을 공유하므로, 별도 BFM 없이 MM→MM 전 경로를 자급자족으로 검증한다.</text><rect x="24" y="62" width="992" height="520" rx="8" fill="#ffffff" stroke="#24292f" stroke-width="2"/><text x="1004" y="572" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="700" fill="#24292f" text-anchor="end">tb_sg_dma   ·   tb/sg_dma/tb_sg_dma.sv</text><rect x="48" y="84" width="296" height="92" rx="6" fill="#ffffff" stroke="#afb8c1" stroke-width="1"/><text x="62" y="107" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#1f2328" text-anchor="start">initial : main</text><text x="62" y="123" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">san_001 → 002 → 003 → 007 → 004 → 005 → 006</text><text x="62" y="137" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">레지스터 계층 먼저 · SAN-003 은 쓰기 이전</text><text x="62" y="151" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">→ report() : 종료 코드 결정</text><rect x="300" y="93" width="34" height="19" rx="9.5" fill="#fff1e5" stroke="#e16f24" stroke-width="1"/><text x="317.0" y="106.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="700" fill="#9a4a00" text-anchor="middle">제어</text><rect x="48" y="196" width="296" height="66" rx="6" fill="#ffffff" stroke="#afb8c1" stroke-width="1"/><text x="62" y="219" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#1f2328" text-anchor="start">AXI4-Lite master</text><text x="62" y="235" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">axil_write / axil_read</text><text x="62" y="249" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">BRESP ≠ OKAY 이면 현재 TC 의 FAIL 로 기록</text><rect x="300" y="205" width="34" height="19" rx="9.5" fill="#fff1e5" stroke="#e16f24" stroke-width="1"/><text x="317.0" y="218.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="700" fill="#9a4a00" text-anchor="middle">자극</text><rect x="48" y="282" width="296" height="104" rx="6" fill="#ffffff" stroke="#afb8c1" stroke-width="1"/><text x="62" y="305" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#1f2328" text-anchor="start">Scoreboard</text><text x="62" y="321" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">tc_begin / tc_end / tc_skip</text><text x="62" y="335" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">check_eq / check_cond / check_reg</text><text x="62" y="349" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">bus_ok : VERSION · IDENTIFICATION 만 게이트</text><text x="62" y="363" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">pad() : xsim 의 string 좌측정렬 미지원 보정</text><rect x="300" y="291" width="34" height="19" rx="9.5" fill="#fff1e5" stroke="#e16f24" stroke-width="1"/><text x="317.0" y="304.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="700" fill="#9a4a00" text-anchor="middle">판정</text><rect x="48" y="406" width="296" height="56" rx="6" fill="#ffffff" stroke="#afb8c1" stroke-width="1"/><text x="62" y="429" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#1f2328" text-anchor="start">initial : global watchdog</text><text x="62" y="445" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">#2_000_000 → $fatal(1) · 회귀가 멎지 않도록</text><rect x="300" y="415" width="34" height="19" rx="9.5" fill="#f6f8fa" stroke="#afb8c1" stroke-width="1"/><text x="317.0" y="428.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="700" fill="#6e7781" text-anchor="middle">안전</text><rect x="396" y="140" width="248" height="320" rx="8" fill="#ffffff" stroke="#24292f" stroke-width="2"/><text x="520" y="172" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="15" font-weight="700" fill="#24292f" text-anchor="middle">sgdma_top</text><text x="520" y="190" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="middle">DUT · 46 checks 대상</text><rect x="592" y="150" width="40" height="19" rx="9.5" fill="#ddf4ff" stroke="#4493f8" stroke-width="1"/><text x="612.0" y="163.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="700" fill="#0a3069" text-anchor="middle">DUT</text><rect x="412" y="206" width="216" height="38" rx="6" fill="#f6f8fa" stroke="#d0d7de" stroke-width="1"/><text x="424" y="230" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="11.5" font-weight="700" fill="#0969da" text-anchor="start">s_axi</text><text x="616" y="230" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="end">레지스터 제어</text><rect x="412" y="252" width="216" height="38" rx="6" fill="#f6f8fa" stroke="#d0d7de" stroke-width="1"/><text x="424" y="276" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="11.5" font-weight="700" fill="#0969da" text-anchor="start">irq</text><text x="616" y="276" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="end">level</text><rect x="412" y="298" width="216" height="38" rx="6" fill="#f6f8fa" stroke="#d0d7de" stroke-width="1"/><text x="424" y="322" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="11.5" font-weight="700" fill="#0969da" text-anchor="start">m_sg_axi</text><text x="616" y="322" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="end">descriptor</text><rect x="412" y="344" width="216" height="38" rx="6" fill="#f6f8fa" stroke="#d0d7de" stroke-width="1"/><text x="424" y="368" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="11.5" font-weight="700" fill="#0969da" text-anchor="start">m_src_axi</text><text x="616" y="368" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="end">source read</text><rect x="412" y="390" width="216" height="38" rx="6" fill="#f6f8fa" stroke="#d0d7de" stroke-width="1"/><text x="424" y="414" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="11.5" font-weight="700" fill="#0969da" text-anchor="start">m_dest_axi</text><text x="616" y="414" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="end">dest write</text><rect x="700" y="298" width="296" height="38" rx="6" fill="#ffffff" stroke="#afb8c1" stroke-width="1"/><text x="712" y="322" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="10.5" font-weight="700" fill="#1f2328" text-anchor="start">axi_rd_slave   NAME="SG"</text><text x="984" y="322" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="end">descriptor 공급</text><rect x="700" y="344" width="296" height="38" rx="6" fill="#ffffff" stroke="#afb8c1" stroke-width="1"/><text x="712" y="368" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="10.5" font-weight="700" fill="#1f2328" text-anchor="start">axi_rd_slave   NAME="SRC"</text><text x="984" y="368" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="end">소스 데이터 공급</text><rect x="700" y="390" width="296" height="38" rx="6" fill="#ffffff" stroke="#afb8c1" stroke-width="1"/><text x="712" y="414" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="10.5" font-weight="700" fill="#1f2328" text-anchor="start">axi_wr_slave   NAME="DST"</text><text x="984" y="414" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="end">목적지 수신 · 기록 추적</text><rect x="700" y="470" width="296" height="84" rx="6" fill="#ffffff" stroke="#afb8c1" stroke-width="1"/><text x="714" y="493" font-family="ui-monospace,SFMono-Regular,'Cascadia Mono','Consolas',monospace" font-size="12.5" font-weight="700" fill="#1f2328" text-anchor="start">tb_mem_pkg</text><text x="714" y="509" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">mem_write8 / mem_write64 / mem_read8</text><text x="714" y="523" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">mem_written() — 바이트 단위 '쓰였는가' 추적</text><text x="714" y="537" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10" font-weight="400" fill="#6e7781" text-anchor="start">세 모델이 같은 연관 배열을 공유</text><rect x="922" y="479" width="64" height="19" rx="9.5" fill="#ddf4ff" stroke="#4493f8" stroke-width="1"/><text x="954.0" y="492.5" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="10.5" font-weight="700" fill="#0a3069" text-anchor="middle">공유 메모리</text><path d="M196,176 L196,196" fill="none" stroke="#8c959f" stroke-width="1.4" stroke-dasharray="5 4" marker-end="url(#ahg)"/><text x="204" y="190" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="start">TC 실행</text><path d="M196,262 L196,282" fill="none" stroke="#8c959f" stroke-width="1.4" stroke-dasharray="5 4" marker-end="url(#ahg)"/><text x="204" y="276" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="start">readback → check_*</text><path d="M344,225 L396,225" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><text x="370" y="218" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="8.5" font-weight="400" fill="#6e7781" text-anchor="middle">s_axi</text><path d="M396,271 L370,271 L370,130 L344,130" fill="none" stroke="#1a7f37" stroke-width="1.4" marker-end="url(#ahgr)"/><text x="362" y="124" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#1a7f37" text-anchor="end">irq</text><path d="M644,317 L700,317" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><text x="672" y="310" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="8.5" font-weight="400" fill="#6e7781" text-anchor="middle">AR / R</text><path d="M644,363 L700,363" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><text x="672" y="356" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="8.5" font-weight="400" fill="#6e7781" text-anchor="middle">AR / R</text><path d="M644,409 L700,409" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><text x="672" y="402" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="8.5" font-weight="400" fill="#6e7781" text-anchor="middle">AW / W / B</text><path d="M848,336 L848,462 M848,382 L848,462" fill="none" stroke="#8c959f" stroke-width="1.2" stroke-dasharray="4 3"/><path d="M848,428 L848,470" fill="none" stroke="#8c959f" stroke-width="1.4" stroke-dasharray="4 3" marker-end="url(#ahg)"/><text x="856" y="452" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9" font-weight="400" fill="#6e7781" text-anchor="start">공유 저장소</text><rect x="24" y="590" width="992" height="46" rx="6" fill="#f6f8fa" stroke="#d0d7de" stroke-width="1"/><path d="M60,610 L116,610" fill="none" stroke="#1f2328" stroke-width="1.4" marker-end="url(#ah)"/><text x="124" y="613" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">AXI 트랜잭션</text><path d="M290,610 L346,610" fill="none" stroke="#8c959f" stroke-width="1.4" stroke-dasharray="5 4" marker-end="url(#ahg)"/><text x="354" y="613" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">호출 · 판정 보고</text><path d="M560,610 L616,610" fill="none" stroke="#1a7f37" stroke-width="1.4" marker-end="url(#ahgr)"/><text x="624" y="613" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">인터럽트</text><text x="800" y="613" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">실패 시 $fatal(1) — 종료 코드로 판정</text><text x="16" y="668" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI','Malgun Gothic','Apple SD Gothic Neo',sans-serif" font-size="9.5" font-weight="400" fill="#6e7781" text-anchor="start">mem_written() 이 바이트 단위로 '쓰였는지'를 추적하므로, 미초기화 영역을 읽어 우연히 값이 맞는 경우와 실제로 쓰인 경우를 구분할 수 있다 — tail 체크가 여기에 의존한다.</text></svg> -->

**세 메모리 모델이 `tb_mem_pkg`의 같은 연관 배열을 공유합니다.** 그래서 소스에 쓴 패턴을 SG·DST 모델이 그대로 보며, descriptor를 `mem_write64()`로 심으면 SG 포트로 읽힙니다. 별도 BFM 없이 MM→MM 전체 경로를 자급자족으로 검증할 수 있는 이유입니다.

**`mem_written()`이 바이트 단위 "쓰였는지"를 추적**하므로, 미초기화 영역을 읽어 우연히 값이 맞는 경우와 실제로 쓰인 경우를 구분할 수 있습니다. `tail` 체크가 이것에 의존합니다.

## 6.2 스코어보드

| 함수 | 역할 |
|---|---|
| `tc_begin(name, desc)` | TC 시작. 카운터 초기화 |
| `tc_end()` | TC 종료. 결과를 큐에 push |
| `tc_skip(name, desc, why)` | TC 건너뜀 기록 |
| `check_eq(name, got, exp)` | 32비트 값 비교 |
| `check_cond(name, cond, detail)` | 불리언 조건 |
| `check_reg(name, addr, exp)` | 읽기 + 비교 1단계 |
| `report()` | 요약 출력 및 종료 코드 결정 |

**`pad()` 함수가 있는 이유**: xsim은 `string` 타입에 `%-Ns` 좌측 정렬을 적용하지 않습니다. 그대로 쓰면 출력이 우측 정렬되어 읽기 어렵습니다.

```systemverilog
function automatic string pad(input string s, input int n);
  string r = s;
  while (r.len() < n) r = {r, " "};
  return r;
endfunction
```

## 6.3 AXI4-Lite 마스터

`axil_write`는 AW/W 채널을 **동시에 구동**하고 양쪽 핸드셰이크가 끝날 때까지 기다립니다. `BRESP`가 `OKAY`가 아니면 현재 TC의 FAIL로 기록합니다.

```systemverilog
if (s_axi_bresp !== 2'b00) begin
  cur_fail++;
  $display("    [FAIL] AXI-Lite write resp : addr=0x%03h bresp=%0d", addr, s_axi_bresp);
end
```

**본 IP는 에러 응답을 내지 않으므로 이 체크는 평소 침묵합니다.** 레지스터 접근이 모종의 이유로 에러를 내기 시작하면 바로 드러나는 안전망입니다.

---

# 7. 유지보수

## 7.1 파라미터를 바꿨을 때

| 바꾼 파라미터 | 고쳐야 할 기대값 |
|---|---|
| `DMA_AXI_ADDR_WIDTH` 32 → 64 | `SAN-007` 체크 6~8 (HIGH 레지스터가 **RW가 됨**), TB의 `AW` localparam |
| `AXI_AXCACHE` / `AXI_AXPROT` | `EXP_INTERFACE_DESCRIPTION_2` |
| `DMA_DATA_WIDTH_*` | `EXP_INTERFACE_DESCRIPTION_1`, `SAN-007` 정렬 체크, burst beat 수 |
| `MAX_BYTES_PER_BURST` | `EXP_INTERFACE_DESCRIPTION_1`, 분할 동작 |
| `DMA_2D_TRANSFER` 0 → 1 | `SAN-007` 체크 9 (`Y_LENGTH`가 활성), `EXP_INTERFACE_DESCRIPTION_1` |
| `FRAMELOCK` 0 → 1 | `SAN-007` 체크 1·10 |
| `CYCLIC` 0 → 1 | `SAN-007` 체크 2 |
| `ID` | `EXP_PERIPHERAL_ID` |
| `FIFO_SIZE` | `ID_WIDTH` 변화 → 디버그 레지스터 (현재 미체크) |

**`INTERFACE_DESCRIPTION_1`은 거의 모든 파라미터 변경에 영향을 받습니다.** 반대로 말하면, 파라미터를 바꾸고 이 값이 그대로면 **빌드가 반영되지 않은 것**입니다.

## 7.2 체크를 추가할 때

| 규칙 | 이유 |
|---|---|
| 리셋값 체크는 **`SAN-003`에만** | 쓰기가 일어나기 전에 실행되도록 순서가 고정되어 있음 |
| `0x450`을 읽는 체크는 **금지** | 읽기가 FIFO를 pop |
| 디버그군(`0x434`~`0x444`) 기대값 비교 **금지** | 고정값 없음. Gray 인코딩 |
| 시퀀스가 필요하면 **Sanity가 아님** | 30초 / 자동 판정 조건에 안 맞음 → Feature Test |
| 헤더 주석의 체크 개수를 **같이 수정** | 안 고치면 문서와 어긋남 (실제로 어긋난 적 있음) |

**TB 헤더에 TC별 체크 수와 합계를 적어두었습니다.** 로그의 `(46/46 checks)`와 대조하면 누락을 바로 알 수 있습니다.

```text
//   SAN-005 : 3-descriptor gather        (6 checks)
//   SAN-006 : IRQ & status               (7 checks)
//   ----------------------------------------------
//   Total                               (46 checks)
```

## 7.3 문서 동기화

TB와 아래 문서는 같이 움직여야 합니다.

| 변경 | 같이 고칠 것 |
|---|---|
| 기대값 | SFR 문서 §3 · §4 · 부록 A |
| 체크 추가/삭제 | 본 문서 §2.1 · §3 · 부록 B, TB 헤더 |
| 커버 범위 변화 | 본 문서 §5, SOR 추적성 매트릭스 |
| 레지스터 명칭 | SFR 문서, TB localparam, 체크 문자열 |

---

# 부록 A — 실측 로그 전문

**2026-10-06 실행. `sgdma_top` 리네임 · `AXI_AXCACHE`/`AXI_AXPROT` 명시 · 레지스터 명칭 통일이 모두 반영된 상태입니다.**

```text
==========================================================
  SG DMA sanity test   (SGDMA-SANITY-v1.0)
==========================================================

[SAN-001] Register identity
    [ ok ] VERSION                              0x00040565
    [ ok ] IDENTIFICATION                       0x444d4143
    [ ok ] PERIPHERAL_ID                        0x00000000
    [ ok ] INTERFACE_DESCRIPTION_1              0x38070303
    [ ok ] INTERFACE_DESCRIPTION_2              0x00000000

[SAN-002] Scratch R/W
    [ ok ] SCRATCH = 0xA5A55A5A                 0xa5a55a5a
    [ ok ] SCRATCH = 0x5A5AA5A5                 0x5a5aa5a5
    [ ok ] SCRATCH = 0x00000000                 0x00000000

[SAN-003] Reset defaults
    [ ok ] CONTROL                              0x00000000
    [ ok ] IRQ_MASK                             0x00000003
    [ ok ] IRQ_PENDING                          0x00000000
    [ ok ] IRQ_SOURCE                           0x00000000
    [ ok ] FLAGS                                0x00000002
    [ ok ] TRANSFER_DONE                        0x00000000
    [ ok ] TRANSFER_ID                          0x00000000
    [ ok ] DEST_ADDRESS                         0x00000000
    [ ok ] SRC_ADDRESS                          0x00000000
    [ ok ] SG_ADDRESS                           0x00000000

[SAN-007] Parameter-masked bits
    [ ok ] CONTROL[3] masked (FRAMELOCK=0)      0x00000007
    [ ok ] FLAGS[0] masked (DMA_CYCLIC=0)       0x00000006
    [ ok ] DEST_ADDRESS 8B aligned              0xfffffff8
    [ ok ] SRC_ADDRESS 8B aligned               0xfffffff8
    [ ok ] SG_ADDRESS 8B aligned                0xfffffff8
    [ ok ] DEST_ADDRESS_HIGH tied 0             0x00000000
    [ ok ] SRC_ADDRESS_HIGH tied 0              0x00000000
    [ ok ] SG_ADDRESS_HIGH tied 0               0x00000000
    [ ok ] Y_LENGTH tied 0 (2D=0)               0x00000000
    [ ok ] FRAMELOCK_CONFIG tied 0              0x00000000
    [ ok ] unmapped reads return 0
    restored CONTROL / FLAGS / address registers

[SAN-004] Single descriptor copy (256 B)
    desc @0x00001000 : id=0xa0 flags=11 src=0x00010000 dst=0x00020000 len=256 next=0x00000000
[3195000]   SG AR  addr=0x00001000 beats=6 size=8B
[3315000]  SRC AR  addr=0x00010000 beats=16 size=8B
[3495000]  DST AW  addr=0x00020000 beats=16 size=8B
[3495000]  SRC AR  addr=0x00010080 beats=16 size=8B
[3705000]  DST AW  addr=0x00020080 beats=16 size=8B
    [ ok ] SAN-004 : irq asserted
    [ ok ] data : 256 bytes 0x00010000 -> 0x00020000
    [ ok ] tail : no overrun past 0x00020100
    [ ok ] TRANSFER_DONE bit set

[SAN-005] 3-descriptor chain, gather
    desc @0x00001100 : id=0xb0 flags=00 src=0x00011000 dst=0x00021000 len=128 next=0x00001140
    desc @0x00001140 : id=0xb1 flags=00 src=0x00013000 dst=0x00021080 len=256 next=0x00001180
    desc @0x00001180 : id=0xb2 flags=11 src=0x00015000 dst=0x00021180 len=64 next=0x00000000
[4215000]   SG AR  addr=0x00001100 beats=6 size=8B
[4295000]   SG AR  addr=0x00001140 beats=6 size=8B
[4335000]  SRC AR  addr=0x00011000 beats=16 size=8B
[4375000]   SG AR  addr=0x00001180 beats=6 size=8B
[4515000]  DST AW  addr=0x00021000 beats=16 size=8B
[4515000]  SRC AR  addr=0x00013000 beats=16 size=8B
[4695000]  SRC AR  addr=0x00013080 beats=16 size=8B
[4725000]  DST AW  addr=0x00021080 beats=16 size=8B
[4875000]  SRC AR  addr=0x00015000 beats=8 size=8B
[4915000]  DST AW  addr=0x00021100 beats=16 size=8B
[5105000]  DST AW  addr=0x00021180 beats=8 size=8B
    [ ok ] SAN-005 : irq asserted
    [ ok ] seg0 : 128 bytes 0x00011000 -> 0x00021000
    [ ok ] seg1 : 256 bytes 0x00013000 -> 0x00021080
    [ ok ] seg2 : 64 bytes 0x00015000 -> 0x00021180
    [ ok ] tail : no overrun past 0x000211c0
    [ ok ] DESCRIPTOR_ID = last of chain        0x000000b2

[SAN-006] IRQ & status
    desc @0x00001200 : id=0xc5 flags=11 src=0x00018000 dst=0x00028000 len=64 next=0x00000000
    [ ok ] IRQ_MASK = 0x1 (EOT unmasked)        0x00000001
[5595000]   SG AR  addr=0x00001200 beats=6 size=8B
[5715000]  SRC AR  addr=0x00018000 beats=8 size=8B
[5815000]  DST AW  addr=0x00028000 beats=8 size=8B
    [ ok ] SAN-006 : irq asserted
    [ ok ] IRQ_PENDING[1] set
    [ ok ] IRQ_PENDING cleared                  0x00000000
    [ ok ] IRQ_SOURCE[0] survives W1C           0x00000001
    [ ok ] irq de-asserted after W1C
    [ ok ] DESCRIPTOR_ID                        0x000000c5

==========================================================
  SANITY SUMMARY
==========================================================
  SAN-001  Register identity                PASS  (5/5)
  SAN-002  Scratch R/W                      PASS  (3/3)
  SAN-003  Reset defaults                   PASS  (10/10)
  SAN-007  Parameter-masked bits            PASS  (11/11)
  SAN-004  Single descriptor copy (256 B)   PASS  (4/4)
  SAN-005  3-descriptor chain, gather       PASS  (6/6)
  SAN-006  IRQ & status                     PASS  (7/7)
----------------------------------------------------------
  SANITY: 7 PASS / 0 FAIL / 0 SKIP     (46/46 checks)
==========================================================
*** SANITY PASSED ***
$finish called at time : 6305 ns
```

---

# 부록 B — 체크 ↔ SFR 근거 대조표

**46개 체크 전부가 SFR 문서의 어느 절에서 기대값을 가져왔는지입니다.** 기대값을 고칠 때는 양쪽을 같이 고쳐야 합니다.

| TC | # | 체크 | 기대값 | SFR 절 |
|---|:--:|---|---|---|
| SAN-001 | 1 | `VERSION` | `0x0004_0565` | 4.1.1 |
| | 2 | `IDENTIFICATION` | `0x444D_4143` | 4.1.4 |
| | 3 | `PERIPHERAL_ID` | `0x0000_0000` | 4.1.2 |
| | 4 | `INTERFACE_DESCRIPTION_1` | `0x3807_0303` | 4.1.5 |
| | 5 | `INTERFACE_DESCRIPTION_2` | `0x0000_0000` | 4.1.6 |
| SAN-002 | 6~8 | `SCRATCH` 3회 | 기입값 | 4.1.3 |
| SAN-003 | 9 | `CONTROL` | `0x0000_0000` | 4.3.1 |
| | 10 | `IRQ_MASK` | **`0x0000_0003`** | 4.2.1 |
| | 11 | `IRQ_PENDING` | `0x0000_0000` | 4.2.2 |
| | 12 | `IRQ_SOURCE` | `0x0000_0000` | 4.2.3 |
| | 13 | `FLAGS` | **`0x0000_0002`** | 4.4.3 |
| | 14 | `TRANSFER_DONE` | `0x0000_0000` | 4.5.1 |
| | 15 | `TRANSFER_ID` | `0x0000_0000` | 4.4.1 |
| | 16 | `DEST_ADDRESS` | `0x0000_0000` | 4.4.4 |
| | 17 | `SRC_ADDRESS` | `0x0000_0000` | 4.4.5 |
| | 18 | `SG_ADDRESS` | `0x0000_0000` | 4.6.1 |
| SAN-007 | 19 | `CONTROL[3]` 마스크 | `0x0000_0007` | 4.3.1 / 4.8 |
| | 20 | `FLAGS[0]` 마스크 | `0x0000_0006` | 4.4.3 / 4.8 |
| | 21~23 | 주소 3종 8B 정렬 | `0xFFFF_FFF8` | 4.4.4 / 4.6.1 |
| | 24~26 | `*_ADDRESS_HIGH` 3종 | `0x0000_0000` | 4.8 / §10 |
| | 27 | `Y_LENGTH` | `0x0000_0000` | 4.8 |
| | 28 | `FRAMELOCK_CONFIG` | `0x0000_0000` | 4.8 |
| | 29 | 미매핑 2주소 | `0x0000_0000` | 2.1 |
| SAN-004 | 30 | irq asserted | — | §6 |
| | 31 | data 256 B | 바이트 일치 | §5 |
| | 32 | tail 미기입 | — | — |
| | 33 | `TRANSFER_DONE` 비트 | `[3:0] != 0` | 4.5.1 |
| SAN-005 | 34 | irq asserted | — | 6.2 |
| | 35~37 | seg0 / seg1 / seg2 | 바이트 일치 | §5 |
| | 38 | tail 미기입 | — | — |
| | 39 | `DESCRIPTOR_ID` | `0x0000_00B2` | **4.6.2** |
| SAN-006 | 40 | `IRQ_MASK` | `0x0000_0001` | 4.2.1 |
| | 41 | irq asserted | — | 6.1 |
| | 42 | `IRQ_PENDING[1]` | `[1] = 1` | 4.2.2 |
| | 43 | `IRQ_PENDING` clear | `0x0000_0000` | 4.2.2 |
| | 44 | **`IRQ_SOURCE[0]` 잔존** | **`0x0000_0001`** | **4.2.3** |
| | 45 | irq 하강 | `irq = 0` | 6.1 |
| | 46 | `DESCRIPTOR_ID` | `0x0000_00C5` | 4.6.2 |

**근거 등급이 M(실측)인 값은 이 46개로 확정된 것들입니다.** SFR 문서에서 R(RTL 분석)로 남은 값은 이 표에 없습니다.

---

# 부록 C — 설계 결정 반영 이력

## C.1 코드에 반영된 결정 (2026-10-06)

| # | 결정 | TB 영향 | 검증 |
|:--:|---|---|---|
| 1 | `AXI_AXCACHE` = `4'b0000` 명시 | 기대값 불변 | 명시 전후 **46/46 + 타임스탬프 19개 전부 동일** |
| 2 | `DMA_AXI_ADDR_WIDTH` = 32 확정 | `AW` localparam, `SAN-007` 체크 6~8 유지 | — |
| 3 | 모듈명 `sgdma_top` | DUT 인스턴스화 1줄 | 46/46 |
| 4 | 래퍼 파라미터 38개 명시 | 기대값 불변 | 46/46 |
| 5 | AXI ID / LOCK 포트 노출 | 신호 선언 추가, 입력은 tie-off | **46/46 + 타임스탬프 동일** |
| 6 | 레지스터 명칭 upstream 통일 | localparam · 체크 문자열 | 46/46 |
| 7 | Sanity 보강 2건 | **재조정 — 아래 C.2** | — |

**결정 1과 5는 "동작을 바꾸지 않는 변경"이었음을 사이클 단위로 확인했습니다.** 통과 개수만 보면 "다른 타이밍으로 우연히 통과"를 배제할 수 없으므로, AXI 트랜잭션 발생 시각 19개를 전부 대조했습니다.

## C.2 결정 7 — 재조정

**원안**: `X_LENGTH`(0x418)와 `ACTIVE_TRANSFER_ID`(0x42C)의 리셋값 체크를 `SAN-003`에 추가 (46 → 48).

**재조정 (2026-10-06 후속 논의)**: **Sanity는 현행 46 checks 범위를 유지**한다. 이어서 SOR에서도 **`RST` 요구사항 6건을 삭제**하고 3-1 Reset / Clock을 "Sanity Test에서 커버됨 · 해당 사항 없음"으로 정리하기로 했으므로, **미측정 리셋값은 현 시점에서 수행 계획이 없다.**

**판단 근거**: Sanity의 역할은 회귀 게이트이지 커버리지 도구가 아니다. 리셋값 검증은 현 단계에서 **투자 대비 우선순위가 낮다**고 판단해 Sanity와 SOR 양쪽에서 범위 밖으로 둔다.

**해소되지 않은 상태**: `X_LENGTH` 리셋값은 **upstream 문서(`7`)와 RTL 분석(`0`)이 어긋난 채 미측정**입니다. SFR 문서에서 근거 등급 **R**로 표기되어 있으며, **수행 계획 없이 그대로 인계됩니다.** 측정 전까지 확정된 값이 아니라는 점을 문서가 계속 드러내는 것이 이 등급 체계의 역할입니다.

## C.3 TB 자체의 수정 이력

| 시점 | 내용 |
|---|---|
| 2026-10-01 | 초기 45 checks. `INTERFACE_DESCRIPTION_2` 기대값 `0x30`으로 FAIL → **실측 `0x00`으로 정정** |
| 2026-10-01 | SKIP 로직 수정 — 구성 레지스터 불일치가 전체 TC를 SKIP시키던 문제. `bus_ok` 플래그 도입 |
| 2026-10-01 | `pad()` 함수 추가 — xsim이 `string`에 `%-Ns` 좌측 정렬을 적용하지 않음 |
| 2026-10-02 | `SAN-005`에 `DESCRIPTOR_ID` 체크 추가 (45 → **46**) |
| 2026-10-02 | AXI ID / LOCK 포트 신호 추가 |
| 2026-10-06 | 모듈명 · 레지스터 명칭 · 주석 정리 |

> **2026-10-01의 두 사건이 본 TB의 설계 판단 둘을 만들었습니다.** 기대값 오류가 전체
> SKIP을 유발한 경험에서 `bus_ok` 게이트가 나왔고, 정적 분석만으로 두 문서가 같은 틀린
> 값에 도달한 경험에서 SFR 문서의 **근거 등급(M/R/D)** 체계가 나왔습니다.

---

## 개정 이력

| 버전 | 일자 | 내용 |
|---|---|---|
| v0.2 | 2026-10-01 | 항목 정의서 — TC 7건 / 45 checks |
| **rel-v1.0.0** | **2026-10-06** | **검증팀 인계본** — 46 checks 확정, 실측 로그 수록, **커버 범위와 한계(§5) 신설**, 결정 7 재조정 기록, TB 구조·유지보수 지침 추가 |